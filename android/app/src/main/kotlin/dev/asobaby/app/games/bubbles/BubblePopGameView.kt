package dev.asobaby.app.games.bubbles

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.MotionEvent
import dev.asobaby.app.games.GameView
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 泡タップゲーム。
 * 画面下から泡が浮かび上がり、タップすると弾けて消える。
 */
class BubblePopGameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : GameView(context, attrs, defStyleAttr) {

    // ─── データクラス ──────────────────────────────

    private data class Bubble(
        var x: Float,
        var y: Float,
        val radius: Float,
        val color: Int,
        val highlightColor: Int,
        val speed: Float,       // px/秒
        val wobbleSpeed: Float, // 横揺れ速度
        val wobbleAmount: Float,// 横揺れ幅
        var wobblePhase: Float, // 横揺れ位相
        var popping: Boolean = false,
        var popProgress: Float = 0f  // 0..1
    )

    private data class PopParticle(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        var radius: Float,
        val color: Int,
        var alpha: Float = 1f
    )

    // ─── ゲーム状態 ────────────────────────────────

    private val bubbles = mutableListOf<Bubble>()
    private val particles = mutableListOf<PopParticle>()
    private var spawnTimer = 0f
    private val spawnInterval = 0.4f  // 秒ごとに泡を生成

    // ─── ペイント ──────────────────────────────────

    private val bubblePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val particlePaint = Paint(Paint.ANTI_ALIAS_FLAG)

    // ─── 色パレット (子供向けの鮮やかな色) ─────────

    private val bubbleColors = intArrayOf(
        0xFFFF6B6B.toInt(),  // 赤
        0xFFFFD93D.toInt(),  // 黄
        0xFF6BCB77.toInt(),  // 緑
        0xFF4D96FF.toInt(),  // 青
        0xFFC084FC.toInt(),  // 紫
        0xFFFF922B.toInt(),  // オレンジ
        0xFFFF85A1.toInt(),  // ピンク
        0xFF20C997.toInt(),  // ティール
    )

    init {
        gameBgColor = 0xFFE8F4FD.toInt()  // 薄い水色の背景
    }

    // ─── ライフサイクル ────────────────────────────

    override fun startGame() {
        bubbles.clear()
        particles.clear()
        spawnTimer = 0f
        startGameLoop()
    }

    override fun stopGame() {
        stopGameLoop()
        bubbles.clear()
        particles.clear()
    }

    override fun pauseGame() {
        stopGameLoop()
    }

    override fun resumeGame() {
        startGameLoop()
    }

    // ─── 更新 ──────────────────────────────────────

    override fun updateGame(deltaTime: Float) {
        if (screenWidth == 0 || screenHeight == 0) return

        // 泡の生成
        spawnTimer += deltaTime
        while (spawnTimer >= spawnInterval) {
            spawnTimer -= spawnInterval
            spawnBubble()
        }

        // 泡の更新
        val iterator = bubbles.iterator()
        while (iterator.hasNext()) {
            val bubble = iterator.next()

            if (bubble.popping) {
                bubble.popProgress += deltaTime * 4f  // 0.25秒で消える
                if (bubble.popProgress >= 1f) {
                    iterator.remove()
                }
            } else {
                // 上昇
                bubble.y -= bubble.speed * deltaTime
                // 横揺れ
                bubble.wobblePhase += bubble.wobbleSpeed * deltaTime
                bubble.x += kotlin.math.sin(bubble.wobblePhase.toDouble()).toFloat() * bubble.wobbleAmount * deltaTime

                // 画面外に出たら削除
                if (bubble.y + bubble.radius < 0) {
                    iterator.remove()
                }
            }
        }

        // パーティクルの更新
        val pIterator = particles.iterator()
        while (pIterator.hasNext()) {
            val p = pIterator.next()
            p.x += p.vx * deltaTime
            p.y += p.vy * deltaTime
            p.vy += 300f * deltaTime  // 重力
            p.alpha -= deltaTime * 2f
            p.radius -= deltaTime * 10f
            if (p.alpha <= 0f || p.radius <= 0f) {
                pIterator.remove()
            }
        }
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 泡を描画
        for (bubble in bubbles) {
            drawBubble(canvas, bubble)
        }

        // パーティクルを描画
        for (p in particles) {
            particlePaint.color = p.color
            particlePaint.alpha = (p.alpha * 255).toInt().coerceIn(0, 255)
            canvas.drawCircle(p.x, p.y, p.radius.coerceAtLeast(0f), particlePaint)
        }
    }

    private fun drawBubble(canvas: Canvas, bubble: Bubble) {
        val scale = if (bubble.popping) {
            1f + bubble.popProgress * 0.5f  // 弾ける時に膨らむ
        } else {
            1f
        }
        val alpha = if (bubble.popping) {
            ((1f - bubble.popProgress) * 255).toInt().coerceIn(0, 255)
        } else {
            255
        }

        val r = bubble.radius * scale

        // グラデーションで立体感を出す
        bubblePaint.shader = RadialGradient(
            bubble.x - r * 0.3f,
            bubble.y - r * 0.3f,
            r * 1.5f,
            bubble.highlightColor,
            bubble.color,
            Shader.TileMode.CLAMP
        )
        bubblePaint.alpha = alpha

        canvas.drawCircle(bubble.x, bubble.y, r, bubblePaint)

        // ハイライト (光の反射)
        bubblePaint.shader = null
        bubblePaint.color = Color.WHITE
        bubblePaint.alpha = (alpha * 0.6f).toInt().coerceIn(0, 255)
        canvas.drawCircle(
            bubble.x - r * 0.25f,
            bubble.y - r * 0.25f,
            r * 0.2f,
            bubblePaint
        )
    }

    // ─── タッチ ────────────────────────────────────

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
        // 最前面 (最後に追加された) の泡から確認
        for (i in bubbles.indices.reversed()) {
            val bubble = bubbles[i]
            if (bubble.popping) continue

            val dist = hypot(x - bubble.x, y - bubble.y)
            if (dist <= bubble.radius * 1.2f) {  // 少し大きめの当たり判定
                popBubble(bubble)
                break
            }
        }
    }

    private fun popBubble(bubble: Bubble) {
        bubble.popping = true
        bubble.popProgress = 0f

        // パーティクル生成
        val particleCount = Random.nextInt(5, 10)
        for (i in 0 until particleCount) {
            val angle = Random.nextFloat() * Math.PI.toFloat() * 2f
            val speed = Random.nextFloat() * 300f + 100f
            particles.add(
                PopParticle(
                    x = bubble.x,
                    y = bubble.y,
                    vx = kotlin.math.cos(angle) * speed,
                    vy = kotlin.math.sin(angle) * speed - 100f,
                    radius = Random.nextFloat() * 6f + 3f,
                    color = bubble.color
                )
            )
        }
    }

    // ─── 泡の生成 ──────────────────────────────────

    private fun spawnBubble() {
        val radius = dpToPx(Random.nextFloat() * 25f + 20f) // 20〜45dp
        val colorIndex = Random.nextInt(bubbleColors.size)
        val color = bubbleColors[colorIndex]
        // ハイライト色 (少し明るくする)
        val highlightColor = lightenColor(color, 0.5f)

        bubbles.add(
            Bubble(
                x = Random.nextFloat() * (screenWidth - radius * 2) + radius,
                y = screenHeight.toFloat() + radius,
                radius = radius,
                color = color,
                highlightColor = highlightColor,
                speed = dpToPx(Random.nextFloat() * 40f + 30f), // 30〜70dp/秒
                wobbleSpeed = Random.nextFloat() * 3f + 1f,
                wobbleAmount = dpToPx(Random.nextFloat() * 15f + 5f),
                wobblePhase = Random.nextFloat() * Math.PI.toFloat() * 2f
            )
        )
    }

    private fun lightenColor(color: Int, factor: Float): Int {
        val r = ((Color.red(color) * (1 - factor) + 255 * factor)).toInt().coerceIn(0, 255)
        val g = ((Color.green(color) * (1 - factor) + 255 * factor)).toInt().coerceIn(0, 255)
        val b = ((Color.blue(color) * (1 - factor) + 255 * factor)).toInt().coerceIn(0, 255)
        return Color.argb(Color.alpha(color), r, g, b)
    }
}
