package dev.asobaby.app.games.animal

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import dev.asobaby.app.games.GameView
import kotlin.math.hypot
import kotlin.random.Random

/**
 * はてな→動物絵文字ゲーム。
 * ❓ をタップすると動物の絵文字が現れ、時間経過でフェードアウトして消える。
 */
class AnimalEmojiGameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : GameView(context, attrs, defStyleAttr) {

    // ─── データクラス ──────────────────────────────

    private data class QuestionMark(
        var x: Float,
        var y: Float,
        val size: Float,           // テキストサイズ (px)
        var wobblePhase: Float,    // 揺れの位相
        val wobbleSpeed: Float,    // 揺れの速度
        var scaleIn: Float = 0f   // 出現アニメーション (0..1)
    )

    private data class AnimalEmoji(
        val emoji: String,
        var x: Float,
        var y: Float,
        val size: Float,
        var alpha: Float = 1f,     // 1→0 でフェードアウト
        var scale: Float = 0f,     // 出現時のスケール (0→1→小さくなる)
        var lifetime: Float = 0f   // 経過時間 (秒)
    )

    // ─── ゲーム状態 ────────────────────────────────

    private val questionMarks = mutableListOf<QuestionMark>()
    private val animalEmojis = mutableListOf<AnimalEmoji>()
    private var spawnTimer = 0f
    private val spawnInterval = 1.5f  // 秒ごとに❓を生成
    private val maxQuestionMarks = 8  // 画面上の❓の最大数
    private val emojiLifetime = 3.0f  // 絵文字の表示時間 (秒)

    // ─── ペイント ──────────────────────────────────

    private val questionPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        alpha = 30
    }

    // ─── 動物リスト ───────────────────────────────

    private val animalEmojisPool = arrayOf(
        "🐶", "🐱", "🐻", "🐼", "🐸",
        "🐵", "🦁", "🐯", "🐨", "🐰",
        "🦊", "🐷", "🐮", "🐔", "🐧",
        "🐢", "🐙", "🦋", "🐝", "🐬"
    )

    // ─── 背景のドット模様 ─────────────────────────

    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x15000000
    }

    init {
        gameBgColor = 0xFFFFF8E1.toInt()  // 温かみのあるクリーム色
    }

    // ─── ライフサイクル ────────────────────────────

    override fun startGame() {
        questionMarks.clear()
        animalEmojis.clear()
        spawnTimer = spawnInterval * 0.8f  // すぐに最初の❓を出す
        startGameLoop()
    }

    override fun stopGame() {
        stopGameLoop()
        questionMarks.clear()
        animalEmojis.clear()
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

        // ❓ の生成
        spawnTimer += deltaTime
        while (spawnTimer >= spawnInterval && questionMarks.size < maxQuestionMarks) {
            spawnTimer -= spawnInterval
            spawnQuestionMark()
        }
        if (questionMarks.size >= maxQuestionMarks) {
            spawnTimer = 0f  // 上限なのでタイマーリセット
        }

        // ❓ の更新 (揺れ、出現アニメーション)
        for (qm in questionMarks) {
            qm.wobblePhase += qm.wobbleSpeed * deltaTime
            if (qm.scaleIn < 1f) {
                qm.scaleIn = (qm.scaleIn + deltaTime * 3f).coerceAtMost(1f)
            }
        }

        // 動物絵文字の更新
        val emojiIterator = animalEmojis.iterator()
        while (emojiIterator.hasNext()) {
            val emoji = emojiIterator.next()
            emoji.lifetime += deltaTime

            // 出現アニメーション (最初の0.3秒)
            if (emoji.lifetime < 0.3f) {
                emoji.scale = (emoji.lifetime / 0.3f).coerceAtMost(1f)
                // バウンスエフェクト
                val t = emoji.scale
                emoji.scale = if (t < 0.5f) {
                    4f * t * t * t
                } else {
                    1f - (-2f * t + 2f).let { it * it * it } / 2f
                }
            } else {
                emoji.scale = 1f
            }

            // フェードアウト (最後の1秒)
            val fadeStart = emojiLifetime - 1f
            if (emoji.lifetime > fadeStart) {
                emoji.alpha = ((emojiLifetime - emoji.lifetime) / 1f).coerceIn(0f, 1f)
                emoji.scale = 0.8f + 0.2f * emoji.alpha  // 少し縮小
            }

            if (emoji.lifetime >= emojiLifetime) {
                emojiIterator.remove()
            }
        }
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // 背景のドット模様
        drawBackgroundDots(canvas)

        // 動物絵文字を描画 (❓の下に)
        for (emoji in animalEmojis) {
            drawAnimalEmoji(canvas, emoji)
        }

        // ❓ を描画
        for (qm in questionMarks) {
            drawQuestionMark(canvas, qm)
        }
    }

    private fun drawBackgroundDots(canvas: Canvas) {
        val spacing = dpToPx(30f)
        var x = spacing / 2
        while (x < screenWidth) {
            var y = spacing / 2
            while (y < screenHeight) {
                canvas.drawCircle(x, y, dpToPx(2f), dotPaint)
                y += spacing
            }
            x += spacing
        }
    }

    private fun drawQuestionMark(canvas: Canvas, qm: QuestionMark) {
        val wobbleOffset = kotlin.math.sin(qm.wobblePhase.toDouble()).toFloat() * dpToPx(3f)
        val scale = qm.scaleIn
        val drawX = qm.x + wobbleOffset
        val drawY = qm.y

        // 影
        canvas.save()
        canvas.translate(drawX + dpToPx(2f), drawY + dpToPx(2f))
        canvas.scale(scale, scale)
        shadowPaint.textSize = qm.size
        shadowPaint.textAlign = Paint.Align.CENTER
        canvas.drawText("❓", 0f, qm.size * 0.35f, shadowPaint)
        canvas.restore()

        // 本体
        canvas.save()
        canvas.translate(drawX, drawY)
        canvas.scale(scale, scale)
        questionPaint.textSize = qm.size
        canvas.drawText("❓", 0f, qm.size * 0.35f, questionPaint)
        canvas.restore()
    }

    private fun drawAnimalEmoji(canvas: Canvas, emoji: AnimalEmoji) {
        emojiPaint.textSize = emoji.size * emoji.scale
        emojiPaint.alpha = (emoji.alpha * 255).toInt().coerceIn(0, 255)

        canvas.save()
        canvas.translate(emoji.x, emoji.y)
        canvas.drawText(emoji.emoji, 0f, emoji.size * 0.35f * emoji.scale, emojiPaint)
        canvas.restore()
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
        // タップ位置に最も近い❓を探す
        var closestIndex = -1
        var closestDist = Float.MAX_VALUE

        for (i in questionMarks.indices) {
            val qm = questionMarks[i]
            if (qm.scaleIn < 0.5f) continue  // まだ完全に出現していない

            val dist = hypot(x - qm.x, y - qm.y)
            val hitRadius = qm.size * 0.7f  // 当たり判定
            if (dist <= hitRadius && dist < closestDist) {
                closestDist = dist
                closestIndex = i
            }
        }

        if (closestIndex >= 0) {
            val qm = questionMarks.removeAt(closestIndex)
            revealAnimal(qm.x, qm.y, qm.size)
        }
    }

    private fun revealAnimal(x: Float, y: Float, size: Float) {
        val emoji = animalEmojisPool[Random.nextInt(animalEmojisPool.size)]
        animalEmojis.add(
            AnimalEmoji(
                emoji = emoji,
                x = x,
                y = y,
                size = size * 1.3f  // 少し大きめに表示
            )
        )
    }

    // ─── ❓ の生成 ─────────────────────────────────

    private fun spawnQuestionMark() {
        val size = dpToPx(Random.nextFloat() * 20f + 35f)  // 35〜55dp
        val margin = size
        val x = Random.nextFloat() * (screenWidth - margin * 2) + margin
        val y = Random.nextFloat() * (screenHeight - margin * 2) + margin

        // 既存の❓や動物と重ならないようにする (簡易チェック)
        val tooClose = questionMarks.any { hypot(x - it.x, y - it.y) < size * 1.5f }
            || animalEmojis.any { hypot(x - it.x, y - it.y) < size * 1.5f }

        if (!tooClose) {
            questionMarks.add(
                QuestionMark(
                    x = x,
                    y = y,
                    size = size,
                    wobblePhase = Random.nextFloat() * Math.PI.toFloat() * 2f,
                    wobbleSpeed = Random.nextFloat() * 2f + 1f
                )
            )
        }
    }
}
