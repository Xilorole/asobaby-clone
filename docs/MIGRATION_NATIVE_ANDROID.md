# Flutter → Android Native (Kotlin) 移行ガイド

## 目的

現在のFlutter製アップデートチェッカーアプリを **Android Native (Kotlin)** に書き換え、APKサイズを大幅削減する。

| | Flutter (現状) | Android Native (目標) |
|---|---|---|
| APKサイズ (arm64) | ~15 MB | ~1-2 MB |
| 最大の原因 | Flutter Engine (`libflutter.so`) 10.6 MB | 不要 |

## 現在のアプリ仕様

画面1枚、機能3つだけの極めてシンプルなアプリ：

1. **バージョン表示** — 自身のバージョンとビルド番号を画面に表示
2. **アップデートチェック** — GitHub Releases API (`GET /repos/Xilorole/asobaby-clone/releases/latest`) を叩いて最新バージョンを取得・比較
3. **APKダウンロード＆インストール** — 新バージョンがあればAPKをダウンロードし、OSのインストーラーを起動

## 現在の実装 (参考)

### ファイル構成
```
lib/
  main.dart              # UI (MaterialApp, 1画面)
  app_update_service.dart # ロジック (API fetch, download, version比較)
```

### APIリクエスト
```
GET https://api.github.com/repos/Xilorole/asobaby-clone/releases/latest
Header: Accept: application/vnd.github+json
Timeout: 10秒
```

### レスポンスの使用フィールド
```json
{
  "tag_name": "v1.1.0",
  "body": "リリースノート",
  "assets": [
    {
      "name": "app-arm64-v8a-release.apk",
      "browser_download_url": "https://github.com/.../app-arm64-v8a-release.apk",
      "size": 15000000
    }
  ]
}
```

### APK選択ロジック (重要)
split APKビルドにより複数のAPKがリリースに添付される。以下の優先順で選択：
1. `arm64-v8a` を含むAPK → `armeabi-v7a` → `x86_64`
2. 上記がなければ任意の `.apk`（fat APK fallback）

### バージョン比較
semver形式 (`major.minor.patch`) を数値比較。`tag_name` の先頭 `v` を除去して使用。

### UI構成
- **AppBar**: "Asobaby"
- **Card**: 現在バージョン (大文字)、ビルド番号、最新バージョン情報、更新ステータス
- **Button**: "Check for Update" (チェック中はスピナー表示)
- **ProgressBar**: ダウンロード中に表示 (パーセント付き)
- **Error表示**: 赤文字でスクロール可能
- **Dialog**: 更新発見時に「Install / Later」ダイアログ表示

## 移行で作成するもの

### 1. Android プロジェクト構成

Flutter関連をすべて削除し、純粋なAndroid Kotlinプロジェクトにする。

```
android/
  app/
    src/main/
      java/com/example/asobaby/
        MainActivity.kt          # メインActivity (すべてのロジックを含む)
      res/
        layout/
          activity_main.xml      # メインレイアウト
        values/
          strings.xml
          themes.xml
      AndroidManifest.xml
    build.gradle.kts
  build.gradle.kts
  settings.gradle.kts
  gradle.properties
```

### 2. AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
    
    <application
        android:label="Asobaby"
        android:icon="@mipmap/ic_launcher"
        android:theme="@style/Theme.Asobaby">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
        <!-- FileProvider for APK install on API 24+ -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
```

### 3. MainActivity.kt の実装要件

#### 使用ライブラリ (標準Android SDKのみ)
- `java.net.HttpURLConnection` — API fetch & ファイルダウンロード (外部ライブラリ不要)
- `android.content.pm.PackageManager` — 自身のバージョン取得
- `android.content.Intent` + `FileProvider` — APKインストール起動
- `kotlinx.coroutines` — 非同期処理

#### 実装する関数
```kotlin
// 1. 自身のバージョンを取得
fun getCurrentVersion(): Pair<String, String>  // (versionName, versionCode)

// 2. GitHub Releases APIをfetch
suspend fun checkForUpdate(): Release?
// data class Release(val version: String, val notes: String, val apkUrl: String?, val apkSize: Long?)

// 3. APKをダウンロード (進捗コールバック付き)
suspend fun downloadApk(url: String, onProgress: (Float) -> Unit): File

// 4. APKインストーラーを起動
fun installApk(file: File)
```

#### APKインストールの注意点
- API 24+ では `FileProvider` 経由で `content://` URI を使う必要がある
- `res/xml/file_paths.xml` を作成:
  ```xml
  <paths>
      <cache-path name="apks" path="/" />
  </paths>
  ```
- Intent:
  ```kotlin
  val intent = Intent(Intent.ACTION_VIEW).apply {
      setDataAndType(uri, "application/vnd.android.package-archive")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  }
  ```

### 4. build.gradle.kts (app level)

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
}

android {
    namespace = "com.example.asobaby"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.asobaby"
        minSdk = 24
        targetSdk = 35
        versionCode = 3        // 前回のビルド番号+1以上にすること
        versionName = "2.0.0"  // Nativeリライトの初回バージョン
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
```

### 5. CI ワークフロー (`.github/workflows/build.yml`)

FlutterステップをGradle直接ビルドに置き換える：

```yaml
name: Build & Release

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build APK
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Build Release APK
        run: cd android && ./gradlew assembleRelease

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: asobaby-apk
          path: android/app/build/outputs/apk/release/*.apk

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: android/app/build/outputs/apk/release/*.apk
          generate_release_notes: true
```

## 移行手順

1. **新ブランチ作成**: `git checkout -b feat/native-android`
2. **Flutter関連を削除**: `lib/`, `pubspec.yaml`, `pubspec.lock`, `.dart_tool/`, `macos/`, `web/`, `ios/` (存在すれば) など
3. **android/ を純粋なAndroid Kotlinプロジェクトへ書き換え**:
   - `settings.gradle.kts`: Flutter plugin参照を削除
   - `build.gradle.kts` (root): Flutter関連を削除
   - `app/build.gradle.kts`: Flutter pluginを削除、上記の通り書き換え
   - `MainActivity.kt`: FlutterActivityからAppCompatActivityへ
4. **レイアウトXML作成**: `activity_main.xml`
5. **FileProvider設定**: `file_paths.xml`
6. **CIワークフロー更新**: Flutter → Gradle
7. **ビルド確認**: `cd android && ./gradlew assembleRelease`
8. **動作確認後マージ & タグv2.0.0**

## 重要な注意事項

- **applicationId**: `com.example.asobaby` を維持すること（変えると別アプリ扱いになりアップデートできなくなる）
- **versionCode**: 現在 `2` なので、`3` 以上にすること（下がるとインストールに失敗する）
- **署名**: 現在はデバッグ署名。リリース署名を設定する場合はキーストアの管理が必要
- **GitHub API rate limit**: 未認証だと60回/時。普段使いなら問題ないが、ヘッダーに表示してもよい
- **Material 3**: `com.google.android.material:material` を使えばFlutter版と同等のUI

## 現在のリポジトリ情報

- **リポジトリ**: `Xilorole/asobaby-clone`
- **デフォルトブランチ**: `main`
- **現在のバージョン**: `1.1.0+2`
- **applicationId**: `com.example.asobaby`
- **minSdk**: Flutter管理 (実効値21程度) → Native化で24推奨
- **Kotlin**: `2.2.20`
- **Gradle AGP**: `8.11.1`
- **Java**: `17`
