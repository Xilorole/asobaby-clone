# ゲーム実装ガイド (AI向け)

このドキュメントは、Asobaby に新しいミニゲームを追加する際の手順をAIに指示するためのガイドです。

## 前提知識

- ゲームは Android の `View` を継承した `GameView` のサブクラスとして実装する
- 描画は `Canvas` API を使用 (宣言的UIは使わない)
- タッチは `onTouchEvent()` で処理
- アニメーションは `invalidate()` をフレームごとに呼び出すゲームループで実現
- 全画面表示 (ステータスバー・ナビバーは `GameHostActivity` が管理)

## 新しいゲームの追加手順

### Step 1: ゲームフォルダの作成

```
android/app/src/main/kotlin/dev/asobaby/app/games/<game_id>/
└── <GameName>GameView.kt
```

- `<game_id>` はスネークケースの一意な識別子 (例: `color_match`, `shape_puzzle`)
- Kotlin ファイル名はパスカルケース (例: `ColorMatchGameView.kt`)

### Step 2: GameView の実装

以下のテンプレートを基にゲームを実装してください:

```kotlin
package dev.asobaby.app.games.<game_id>

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import dev.asobaby.app.games.GameView

class <GameName>GameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : GameView(context, attrs, defStyleAttr) {

    // ─── ゲーム状態 ────────────────────────────────
    // ここにゲーム固有の状態変数を定義
    
    // ─── ペイント ──────────────────────────────────
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    // ─── ライフサイクル ────────────────────────────
    
    override fun startGame() {
        // ゲーム初期化処理
        // - 状態のリセット
        // - 初期オブジェクトの配置
        // - ゲームループの開始
        startGameLoop()
    }

    override fun stopGame() {
        // リソースの解放
        stopGameLoop()
    }

    override fun pauseGame() {
        stopGameLoop()
    }

    override fun resumeGame() {
        startGameLoop()
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // 背景描画
        canvas.drawColor(gameBgColor)
        // ゲームオブジェクト描画
        drawGameObjects(canvas)
    }

    private fun drawGameObjects(canvas: Canvas) {
        // ゲーム固有の描画処理
    }

    // ─── タッチイベント ────────────────────────────

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                handleTap(event.x, event.y)
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun handleTap(x: Float, y: Float) {
        // タップ処理
    }

    // ─── ゲームループ ─────────────────────────────

    // ※ GameView 基底クラスに startGameLoop() / stopGameLoop() /
    //   updateGame(deltaTime) が定義されているのでそれを使う

    override fun updateGame(deltaTime: Float) {
        // 毎フレーム呼ばれる更新処理
        // deltaTime は前フレームからの経過秒数 (Float)
        //
        // 例:
        // - オブジェクトの移動
        // - 衝突判定
        // - 新規オブジェクトのスポーン
        // - 画面外オブジェクトの削除
    }
}
```

### Step 3: GameRegistry への登録

`GameRegistry.kt` にゲームを追加します:

```kotlin
// GameRegistry.kt の games リストに追加
GameInfo(
    id = "<game_id>",
    name = "<絵文字> <表示名>",
    description = "<ゲームの説明文>",
    factory = { context -> <GameName>GameView(context) }
)
```

### Step 4: (任意) アセットの追加

画像や音声が必要な場合:

```
res/drawable/game_<game_id>_*.png      # drawable リソース
assets/games/<game_id>/*.png           # assets (大きいファイル)
res/raw/game_<game_id>_*.ogg           # 効果音
```

## 実装ルール

### 必須ルール

1. **`GameView` を継承すること** — 他のベースクラスは使わない
2. **`startGame()` / `stopGame()` を必ず実装** — ライフサイクル管理に必要
3. **`updateGame(deltaTime)` でゲームロジックを更新** — ゲームループは基底クラスが管理
4. **`GameRegistry` に登録すること** — 登録しないと画面に表示されない
5. **外部ライブラリを追加しないこと** — 標準 API + 既存の依存のみ使用

### 推奨ルール

1. **背景色は `gameBgColor` プロパティを使う** — 基底クラスで定義済み
2. **子供が触って楽しいインタラクションを入れる** — タップ、ドラッグ、長押しなど
3. **鮮やかな色を使う** — 子供向けなのでパステルカラーや明るい色が好ましい
4. **テキストは最小限に** — 文字が読めない年齢の子供も対象
5. **ゲームオーバーは作らない** — 終わりのない遊びが望ましい
6. **パフォーマンスに注意** — `onDraw()` 内でのオブジェクト生成を避ける (Paint等は事前生成)

## GameView 基底クラスの API

```kotlin
abstract class GameView : View {
    // ─── プロパティ ──────────────────
    var gameBgColor: Int = Color.WHITE         // 背景色 (onDraw で自動描画)

    // ─── 抽象メソッド (必ず実装) ─────
    abstract fun startGame()                  // ゲーム開始
    abstract fun stopGame()                   // ゲーム終了・リソース解放
    abstract fun pauseGame()                  // 一時停止
    abstract fun resumeGame()                 // 再開
    open fun updateGame(deltaTime: Float) {}  // フレーム更新 (オーバーライド推奨)

    // ─── ユーティリティ (使用可能) ───
    fun startGameLoop()                       // 60fps ゲームループ開始
    fun stopGameLoop()                        // ゲームループ停止
    val screenWidth: Int                      // 画面幅 (px)
    val screenHeight: Int                     // 画面高さ (px)
    fun dpToPx(dp: Float): Float              // dp → px 変換
}
```

## 既存ゲームの参考実装

### 泡タップゲーム (`BubblePopGameView`)
- **場所**: `games/bubbles/BubblePopGameView.kt`
- **概要**: 画面下部から泡が浮かび上がり、タップすると消える
- **特徴**:
  - `Bubble` データクラスでオブジェクト管理
  - ランダムな色・サイズの泡を生成
  - 当たり判定は円の中心からの距離で計算
  - `updateGame()` で Y 座標を更新、画面外の泡を削除

### はてな→動物ゲーム (`AnimalEmojiGameView`)
- **場所**: `games/animal/AnimalEmojiGameView.kt`
- **概要**: ❓をタップすると動物の絵文字が現れ、時間経過で消える
- **特徴**:
  - `QuestionMark` と `AnimalEmoji` の2種類のオブジェクト管理
  - 絵文字を `Canvas.drawText()` で描画
  - アルファ値の変化でフェードアウト実現
  - 一定間隔で新しい❓を自動生成

## チェックリスト

新ゲーム実装時に以下を確認してください:

- [ ] `GameView` を継承している
- [ ] `startGame()`, `stopGame()`, `pauseGame()`, `resumeGame()` を実装
- [ ] `updateGame(deltaTime)` をオーバーライドしている
- [ ] `GameRegistry.kt` にゲームを登録した
- [ ] `onDraw()` 内で `Paint` や `Path` のアロケーションをしていない
- [ ] 画面サイズに対して相対的な座標を使っている (固定ピクセルでない)
- [ ] ゲーム終了 (`stopGame()`) でアニメーション等を正しく停止している
- [ ] 暴力的・不快なコンテンツを含まない
