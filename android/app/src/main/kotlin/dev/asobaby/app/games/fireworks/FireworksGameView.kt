package dev.asobaby.app.games.fireworks

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import dev.asobaby.app.games.GameView
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

/**
 * 花火ゲーム。
 * タップした場所に花火が打ち上がり、カラフルな光の花が咲く。
 * 一定時間タップがないと自動で花火を打ち上げる。
 */
class FireworksGameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : GameView(context, attrs, defStyleAttr) {

    // ─── データクラス ──────────────────────────────

    private data class Rocket(
        var x: Float,
        var y: Float,
        val targetX: Float,
        val targetY: Float,
        val color: Int,
        val speed: Float
    ) {
        fun distToTarget() = hypot(targetX - x, targetY - y)
    }

    private data class Spark(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        val color: Int,
        var alpha: Float = 1f,
        var radius: Float,
        val initialRadius: Float
    )

    private data class TrailParticle(
        var x: Float,
        var y: Float,
        val color: Int,
        var alpha: Float = 0.7f,
        var radius: Float
    )

    private data class Star(
        val x: Float,
        val y: Float,
        val radius: Float,
        var twinkle: Float  // 0..1 位相
    )

    // ─── ゲーム状態 ────────────────────────────────

    private val rockets = mutableListOf<Rocket>()
    private val sparks = mutableListOf<Spark>()
    private val trails = mutableListOf<TrailParticle>()
    private val stars = mutableListOf<Star>()

    private var autoLaunchTimer = 0f
    private val autoLaunchInterval = 2.0f

    // ─── ペイント ──────────────────────────────────

    private val rocketPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val sparkPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val trailPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }

    // ─── 色パレット (鮮やかな花火の色) ─────────────

    private val fireworkColors = intArrayOf(
        0xFFFF6B6B.toInt(),  // 赤
        0xFFFFD93D.toInt(),  // 黄
        0xFF6BCB77.toInt(),  // 緑
        0xFF4D96FF.toInt(),  // 青
        0xFFC084FC.toInt(),  // 紫
        0xFFFF922B.toInt(),  // オレンジ
        0xFFFF85A1.toInt(),  // ピンク
        0xFF20C997.toInt(),  // ティール
        0xFFFFFFFF.toInt(),  // 白
        0xFFFFC0CB.toInt(),  // ライトピンク
    )

    init {
        gameBgColor = 0xFF0D0D2B.toInt()  // 夜空の深い紺色
    }

    // ─── ライフサイクル ────────────────────────────

    override fun startGame() {
        rockets.clear()
        sparks.clear()
        trails.clear()
        stars.clear()
        autoLaunchTimer = autoLaunchInterval * 0.5f  // 少し早めに最初を打ち上げる
        startGameLoop()
    }

    override fun stopGame() {
        stopGameLoop()
        rockets.clear()
        sparks.clear()
        trails.clear()
        stars.clear()
    }

    override fun pauseGame() = stopGameLoop()
    override fun resumeGame() = startGameLoop()

    // ─── サイズ変更 ────────────────────────────────

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w > 0 && h > 0) setupStars()
    }

    private fun setupStars() {
        stars.clear()
        val count = run {
            val cellPx = dpToPx(30f)
            (screenWidth * screenHeight / (cellPx * cellPx)).toInt().coerceIn(30, 120)
        }
        repeat(count) {
            stars.add(Star(
                x = Random.nextFloat() * screenWidth,
                y = Random.nextFloat() * screenHeight,
                radius = dpToPx(Random.nextFloat() * 1.5f + 0.5f),
                twinkle = Random.nextFloat()
            ))
        }
    }

    // ─── 更新 ──────────────────────────────────────

    override fun updateGame(deltaTime: Float) {
        if (screenWidth == 0 || screenHeight == 0) return

        // 自動打ち上げ
        autoLaunchTimer += deltaTime
        if (autoLaunchTimer >= autoLaunchInterval) {
            autoLaunchTimer = 0f
            val tx = Random.nextFloat() * screenWidth * 0.8f + screenWidth * 0.1f
            val ty = Random.nextFloat() * screenHeight * 0.45f + screenHeight * 0.05f
            launchRocket(tx, ty)
        }

        // 星のきらめき更新
        for (star in stars) {
            star.twinkle = (star.twinkle + deltaTime * 1.5f) % 1f
        }

        // ロケット更新
        val rIterator = rockets.iterator()
        while (rIterator.hasNext()) {
            val rocket = rIterator.next()
            val dist = rocket.distToTarget()
            val step = rocket.speed * deltaTime
            if (dist <= step) {
                explode(rocket.targetX, rocket.targetY, rocket.color)
                rIterator.remove()
            } else {
                val angle = atan2(rocket.targetY - rocket.y, rocket.targetX - rocket.x)
                rocket.x += cos(angle) * step
                rocket.y += sin(angle) * step
                // 煙トレイル
                trails.add(TrailParticle(
                    x = rocket.x,
                    y = rocket.y,
                    color = rocket.color,
                    radius = dpToPx(2.5f)
                ))
            }
        }

        // スパーク更新
        val sIterator = sparks.iterator()
        while (sIterator.hasNext()) {
            val s = sIterator.next()
            s.x += s.vx * deltaTime
            s.y += s.vy * deltaTime
            s.vy += 180f * deltaTime   // 重力
            s.vx *= (1f - 0.6f * deltaTime)  // 空気抵抗
            s.vy *= (1f - 0.1f * deltaTime)
            s.alpha -= deltaTime * 1.0f
            s.radius = (s.initialRadius * s.alpha).coerceAtLeast(0f)
            if (s.alpha <= 0f) sIterator.remove()
        }

        // トレイル更新
        val tIterator = trails.iterator()
        while (tIterator.hasNext()) {
            val t = tIterator.next()
            t.alpha -= deltaTime * 4f
            t.radius -= deltaTime * 8f
            if (t.alpha <= 0f || t.radius <= 0f) tIterator.remove()
        }
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 星を描画
        for (star in stars) {
            val twinkleFactor = (sin(star.twinkle * Math.PI.toFloat() * 2f) * 0.4f + 0.6f)
            starPaint.alpha = (twinkleFactor * 200).toInt().coerceIn(0, 255)
            canvas.drawCircle(star.x, star.y, star.radius * twinkleFactor, starPaint)
        }

        // トレイル
        for (t in trails) {
            trailPaint.color = t.color
            trailPaint.alpha = (t.alpha * 160).toInt().coerceIn(0, 255)
            canvas.drawCircle(t.x, t.y, t.radius.coerceAtLeast(0f), trailPaint)
        }

        // ロケット
        for (r in rockets) {
            rocketPaint.color = r.color
            rocketPaint.alpha = 255
            canvas.drawCircle(r.x, r.y, dpToPx(3f), rocketPaint)
        }

        // スパーク
        for (s in sparks) {
            sparkPaint.color = s.color
            sparkPaint.alpha = (s.alpha * 255).toInt().coerceIn(0, 255)
            canvas.drawCircle(s.x, s.y, s.radius, sparkPaint)
        }
    }

    // ─── タッチ ────────────────────────────────────

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                launchRocket(event.x, event.y)
                autoLaunchTimer = 0f  // 手動タップで自動タイマーをリセット
                performClick()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean = super.performClick()

    // ─── ロジック ──────────────────────────────────

    private fun launchRocket(targetX: Float, targetY: Float) {
        val color = fireworkColors[Random.nextInt(fireworkColors.size)]
        val startX = screenWidth * (0.2f + Random.nextFloat() * 0.6f)
        rockets.add(Rocket(
            x = startX,
            y = screenHeight.toFloat(),
            targetX = targetX,
            targetY = targetY.coerceAtMost(screenHeight * 0.8f),
            color = color,
            speed = dpToPx(Random.nextFloat() * 150f + 350f)
        ))
    }

    private fun explode(x: Float, y: Float, color: Int) {
        val sparkCount = Random.nextInt(50, 90)
        val baseRadius = dpToPx(Random.nextFloat() * 3f + 3f)
        val color2 = fireworkColors[Random.nextInt(fireworkColors.size)]

        // リング状 + ランダムスパークの組み合わせ
        for (i in 0 until sparkCount) {
            val ring = i < sparkCount * 0.6f
            val angle = if (ring) {
                (i.toFloat() / (sparkCount * 0.6f)) * Math.PI.toFloat() * 2f
            } else {
                Random.nextFloat() * Math.PI.toFloat() * 2f
            }
            val speed = dpToPx(if (ring) {
                Random.nextFloat() * 80f + 180f
            } else {
                Random.nextFloat() * 150f + 50f
            })
            val sparkColor = if (Random.nextFloat() < 0.3f) color2 else color
            val r = baseRadius * (Random.nextFloat() * 0.5f + 0.75f)
            sparks.add(Spark(
                x = x,
                y = y,
                vx = cos(angle) * speed,
                vy = sin(angle) * speed,
                color = sparkColor,
                radius = r,
                initialRadius = r
            ))
        }
    }
}
