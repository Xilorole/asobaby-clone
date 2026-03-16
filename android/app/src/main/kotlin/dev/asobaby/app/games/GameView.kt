package dev.asobaby.app.games

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.Choreographer
import android.view.View
import androidx.core.content.res.ResourcesCompat
import dev.asobaby.app.R

/**
 * すべてのゲームの基底クラス。
 * ゲームループ、ライフサイクル管理、ユーティリティを提供する。
 */
abstract class GameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    /** 背景色 (onDraw で自動描画) */
    var gameBgColor: Int = Color.WHITE

    /** 画面幅 (px) — onSizeChanged 後に有効 */
    var screenWidth: Int = 0
        private set

    /** 画面高さ (px) — onSizeChanged 後に有効 */
    var screenHeight: Int = 0
        private set

    private var lastFrameTime: Long = 0L
    private var gameLoopRunning = false

    private val choreographer = Choreographer.getInstance()
    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!gameLoopRunning) return
            val now = SystemClock.elapsedRealtime()
            val deltaTime = if (lastFrameTime == 0L) 0f else (now - lastFrameTime) / 1000f
            lastFrameTime = now
            // Cap delta to avoid huge jumps (e.g., after pause)
            val clampedDelta = deltaTime.coerceAtMost(0.1f)
            updateGame(clampedDelta)
            invalidate()
            choreographer.postFrameCallback(this)
        }
    }

    // ─── 抽象メソッド ──────────────────────────────

    /** ゲーム開始 (初期化含む) */
    abstract fun startGame()

    /** ゲーム停止 (リソース解放) */
    abstract fun stopGame()

    /** 一時停止 */
    abstract fun pauseGame()

    /** 再開 */
    abstract fun resumeGame()

    /** 毎フレーム更新。[deltaTime] は前フレームからの経過秒数。 */
    open fun updateGame(deltaTime: Float) {}

    // ─── サイズ管理 ────────────────────────────────

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        screenWidth = w
        screenHeight = h
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(gameBgColor)
    }

    // ─── ゲームループ ─────────────────────────────

    /** 60fps ゲームループを開始する */
    protected fun startGameLoop() {
        if (gameLoopRunning) return
        gameLoopRunning = true
        lastFrameTime = SystemClock.elapsedRealtime()
        choreographer.postFrameCallback(frameCallback)
    }

    /** ゲームループを停止する */
    protected fun stopGameLoop() {
        gameLoopRunning = false
        choreographer.removeFrameCallback(frameCallback)
    }

    // ─── ユーティリティ ───────────────────────────

    /** dp を px に変換する */
    fun dpToPx(dp: Float): Float {
        return dp * resources.displayMetrics.density
    }

    /**
     * ゼン丸ゴシック Bold (weight 700) フォントを返す。
     * バンドル済み TTF から読み込む。
     */
    val zenFont: Typeface? by lazy {
        try { ResourcesCompat.getFont(context, R.font.zen_maru_gothic_bold) }
        catch (e: android.content.res.Resources.NotFoundException) { null }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopGameLoop()
    }
}
