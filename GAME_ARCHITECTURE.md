# Asobaby ゲームアーキテクチャ設計書

## 概要

Asobaby は子供向けの Android ネイティブ (Kotlin) アプリケーションです。
複数のミニゲームを搭載し、ランダム選択・手動選択で切り替えて遊べます。
アプリ起動時にはランダムに1つのゲームが自動起動します。

## アプリの全体構成

```
起動 → GameHostActivity (ランダムにゲーム表示)
         ├─ ゲーム画面 (全画面表示)
         ├─ 🔀 ランダム切替ボタン (フローティング)
         ├─ 📋 ゲーム選択ボタン (フローティング)
         └─ ⚙ 設定/アップデートボタン (フローティング)

ゲーム選択ボタン → GameSelectionActivity (ゲーム一覧)
設定ボタン → UpdateActivity (アップデートチェック)
```

## フォルダ構成

```
android/app/src/main/
├── AndroidManifest.xml
├── kotlin/dev/asobaby/app/
│   ├── GameHostActivity.kt          # ランチャー兼ゲームホスト
│   ├── UpdateActivity.kt            # アップデートチェック画面
│   ├── games/
│   │   ├── GAME_IMPLEMENTATION_GUIDE.md  # ゲーム追加ガイド (AIに実装させる用)
│   │   ├── GameInfo.kt              # ゲームメタデータ (名前, 説明, アイコン)
│   │   ├── GameRegistry.kt          # ゲーム登録・管理
│   │   ├── GameView.kt              # ゲーム基底クラス (abstract)
│   │   ├── bubbles/
│   │   │   └── BubblePopGameView.kt # 泡タップゲーム
│   │   └── animal/
│   │       └── AnimalEmojiGameView.kt # はてな→動物絵文字ゲーム
│   └── ui/
│       └── GameSelectionActivity.kt # ゲーム選択画面
├── res/
│   ├── layout/
│   │   ├── activity_game_host.xml   # ゲームホスト画面
│   │   ├── activity_game_selection.xml  # ゲーム選択画面
│   │   └── activity_update.xml      # 旧 activity_main.xml (アップデート用)
│   ├── values/
│   │   ├── colors.xml
│   │   ├── strings.xml
│   │   └── themes.xml
│   └── xml/
│       └── file_paths.xml
```

## アーキテクチャ

### ゲーム基底クラス (`GameView`)

すべてのゲームは `GameView` を継承したカスタム `View` として実装されます。

```kotlin
abstract class GameView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    var gameBgColor: Int        // 背景色 (onDraw で自動描画)
    abstract fun startGame()    // ゲーム開始
    abstract fun stopGame()     // ゲーム停止 (リソース解放)
    abstract fun pauseGame()    // 一時停止
    abstract fun resumeGame()   // 再開
    open fun updateGame(deltaTime: Float) {}  // 毎フレーム更新
}
```

- ゲームは `Canvas` に直接描画します (宣言的UIではなく命令的描画)
- タッチイベントは `onTouchEvent()` でハンドリング
- アニメーションは `invalidate()` ループまたは `ValueAnimator` で実現
- 音声は任意 (将来対応)

### ゲーム登録 (`GameRegistry`)

新しいゲームを追加する際は `GameRegistry` にエントリを追加するだけで、
選択画面やランダム切り替えに自動的に反映されます。

```kotlin
object GameRegistry {
    val games: List<GameInfo> = listOf(
        GameInfo("bubble_pop", "🫧 あわあわ", "泡をタップしてパチン!") { context ->
            BubblePopGameView(context)
        },
        // ← 新ゲームをここに追加
    )
}
```

### ゲーム情報 (`GameInfo`)

```kotlin
data class GameInfo(
    val id: String,          // 一意なID
    val name: String,        // 表示名 (絵文字含む)
    val description: String, // 説明文
    val factory: (Context) -> GameView  // View生成ファクトリ
)
```

## 必要なアセット

### 現在のゲームが使うアセット

**泡タップゲーム (`BubblePopGameView`)**
- 画像アセット: **不要** (Canvas で円を描画、色はランダム生成)
- 音声: なし (将来追加可能)

**はてな→動物ゲーム (`AnimalEmojiGameView`)**
- 画像アセット: **不要** (絵文字テキストを Canvas に描画)
- 使用する絵文字: ❓, 🐶, 🐱, 🐻, 🐼, 🐸, 🐵, 🦁, 🐯, 🐨, 🐰, 🦊, 🐷, 🐮
- 音声: なし (将来追加可能)

### 将来のゲーム追加時に想定されるアセット

| 種別 | 形式 | 配置場所 |
|------|------|----------|
| 画像 | PNG/WebP | `res/drawable/` または `assets/games/<game_id>/` |
| 音声 (効果音) | OGG/WAV | `res/raw/` または `assets/games/<game_id>/` |
| BGM | OGG/MP3 | `assets/games/<game_id>/` |
| アニメーション | Lottie JSON | `assets/games/<game_id>/` |

### アセット命名規則

```
res/drawable/
  game_<game_id>_<asset_name>.png    例: game_bubble_pop_icon.png

assets/games/<game_id>/
  <自由な名前>                        例: assets/games/puzzle/bg.png
```

## 技術仕様

| 項目 | 値 |
|------|---|
| 言語 | Kotlin |
| minSdk | 24 (Android 7.0) |
| targetSdk | 35 |
| 描画方式 | Custom View + Canvas |
| アニメーション | invalidate() ループ / ValueAnimator |
| テーマ | Material Design 3 |
| 画面回転 | 縦固定 (portrait) |

## 依存関係 (現在)

```kotlin
dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
```

追加の依存関係は不要です。ゲームはすべて標準の Android Canvas API で実装します。

## 画面遷移フロー

```
[アプリ起動]
    ↓
[GameHostActivity] ←─── ランチャー
    │  ランダムにゲーム1つを起動
    │
    ├── [🔀 ボタン] → ランダムに別のゲームに切替
    ├── [📋 ボタン] → GameSelectionActivity
    │                    │  ゲーム選択
    │                    └──→ [GameHostActivity] 選択されたゲームを表示
    └── [⚙ ボタン] → UpdateActivity (アップデートチェック)
```

## 今後の拡張ポイント

- ゲーム追加: `GameRegistry` にエントリを追加 + `GameView` の実装
- 効果音: `SoundPool` を `GameView` の基底クラスに追加
- スコア管理: `SharedPreferences` または Room DB
- ペアレンタルコントロール: 設定画面にパスワード保護
- オフライン対応: ゲームはすべてローカル実行
