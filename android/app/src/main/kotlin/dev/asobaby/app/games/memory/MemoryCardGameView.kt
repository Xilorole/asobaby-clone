package dev.asobaby.app.games.memory

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import dev.asobaby.app.games.GameView
import kotlin.math.*
import kotlin.random.Random

/**
 * 10-card memory matching game (神経衰弱).
 *
 * 5 pairs of cute emoji cards are scattered across the screen.
 * Tap two cards to flip them — if they match, they stay face-up
 * and become untappable. When all pairs are found, cards gather
 * to the centre, then re-deal with fresh emoji.
 */
class MemoryCardGameView(context: Context) : GameView(context) {

    // ── Card model ───────────────────────────────────────────

    private class Card(
        var x: Float = 0f,
        var y: Float = 0f,
        var targetX: Float = 0f,
        var targetY: Float = 0f,
        var emoji: String = "",
        var state: Int = STATE_FACE_DOWN,
        var flipProgress: Float = 0f,   // 0 = face-down, 1 = face-up
        var matchPulse: Float = 0f,     // 1→0 scale pulse on match
    ) {
        companion object {
            const val STATE_FACE_DOWN = 0
            const val STATE_FACE_UP = 1
            const val STATE_MATCHED = 2
        }
    }

    // ── Constants ────────────────────────────────────────────

    private companion object {
        const val NUM_CARDS = 10
        const val NUM_PAIRS = NUM_CARDS / 2

        const val FLIP_SPEED = 4.0f      // full flip ≈ 0.25 s
        const val CHECK_DELAY = 0.8f     // show mismatch for 0.8 s
        const val MOVE_LERP = 0.12f      // position interpolation / frame
        const val WAIT_DURATION = 0.6f   // pause after gathering
        const val PULSE_DECAY = 5.0f     // match-pulse fade speed
        const val SNAP_DIST = 4f         // snap to target below this
        const val TARGET_FPS = 60f       // assumed frame-rate for lerp

        const val PHASE_DEALING = 0
        const val PHASE_PLAYING = 1
        const val PHASE_CHECKING = 2
        const val PHASE_GATHERING = 3
        const val PHASE_WAITING = 4
    }

    // ── Emoji pool ───────────────────────────────────────────

    private val emojiPool = listOf(
        "🐶", "🐱", "🐻", "🐼", "🐸", "🐵", "🦁", "🐯", "🐨", "🐰",
        "🦊", "🐷", "🌸", "🌈", "⭐", "🍎", "🍰", "🎀", "🧸", "🍭",
        "🐧", "🐢", "🦋", "🐝", "🐬", "🍓", "🌻", "🎈", "🍩", "🌺"
    )

    // ── State ────────────────────────────────────────────────

    private val cards = mutableListOf<Card>()
    private var phase = PHASE_DEALING
    private var checkTimer = 0f
    private var waitTimer = 0f
    private var firstIndex = -1
    private var secondIndex = -1
    private var needsInit = true

    // ── Card dimensions (recalculated on size change) ────────

    private var cardW = 0f
    private var cardH = 0f
    private var cornerR = 0f
    private var emojiSize = 0f

    // ── Pre-allocated paints ─────────────────────────────────

    private val backPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(100, 149, 237)       // cornflower blue
    }
    private val frontPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2.5f
    }
    private val matchTintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(35, 255, 215, 0)    // subtle gold overlay
    }
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(40, 0, 0, 0)
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }

    private val rect = RectF()

    init {
        gameBgColor = Color.rgb(245, 240, 230)  // warm cream
    }

    // ── Lifecycle ────────────────────────────────────────────

    override fun startGame() {
        textPaint.typeface = zenFont
        cards.clear()
        needsInit = true
        startGameLoop()
    }

    override fun stopGame() {
        stopGameLoop()
        cards.clear()
        firstIndex = -1
        secondIndex = -1
        phase = PHASE_DEALING
        needsInit = true
    }
    override fun pauseGame() = stopGameLoop()
    override fun resumeGame() = startGameLoop()

    // ── Initialisation / layout ──────────────────────────────

    private fun setupCards() {
        calcDimensions()

        val emojis = emojiPool.shuffled().take(NUM_PAIRS)
        val paired = (emojis + emojis).shuffled()
        val positions = makePositions()
        val cx = screenWidth / 2f
        val cy = screenHeight / 2f

        cards.clear()
        for (i in 0 until NUM_CARDS) {
            cards.add(Card(
                x = cx, y = cy,
                targetX = positions[i].first,
                targetY = positions[i].second,
                emoji = paired[i],
            ))
        }

        phase = PHASE_DEALING
        firstIndex = -1
        secondIndex = -1
        needsInit = false
    }

    private fun calcDimensions() {
        val portrait = screenHeight > screenWidth
        val cols = if (portrait) 2 else 5
        val rows = if (portrait) 5 else 2
        val mx = dpToPx(10f)
        val my = dpToPx(10f)

        cardW = (screenWidth - mx * (cols + 1)) / cols
        cardH = (screenHeight - my * (rows + 1)) / rows

        // keep aspect ratio reasonable
        if (cardW / cardH > 1.4f) cardW = cardH * 1.4f
        else if (cardH / cardW > 1.6f) cardH = cardW * 1.6f

        cornerR = dpToPx(10f)
        emojiSize = min(cardW, cardH) * 0.45f
        textPaint.textSize = emojiSize
    }

    /** Place one card per grid cell with a small random jitter. */
    private fun makePositions(): List<Pair<Float, Float>> {
        val portrait = screenHeight > screenWidth
        val cols = if (portrait) 2 else 5
        val rows = if (portrait) 5 else 2
        val mx = dpToPx(10f)
        val my = dpToPx(10f)
        val cellW = (screenWidth - mx * 2) / cols
        val cellH = (screenHeight - my * 2) / rows

        val out = mutableListOf<Pair<Float, Float>>()
        for (r in 0 until rows) {
            for (c in 0 until cols) {
                val jx = (Random.nextFloat() - 0.5f) * cellW * 0.12f
                val jy = (Random.nextFloat() - 0.5f) * cellH * 0.12f
                val px = (mx + cellW * (c + 0.5f) + jx)
                    .coerceIn(cardW / 2 + mx, screenWidth - cardW / 2 - mx)
                val py = (my + cellH * (r + 0.5f) + jy)
                    .coerceIn(cardH / 2 + my, screenHeight - cardH / 2 - my)
                out.add(px to py)
            }
        }
        return out.shuffled()
    }

    // ── Per-frame update ─────────────────────────────────────

    override fun updateGame(deltaTime: Float) {
        if (needsInit) {
            if (screenWidth > 0 && screenHeight > 0) setupCards() else return
        }
        if (cards.isEmpty()) return

        // --- animate positions toward targets ---
        for (card in cards) {
            val dx = card.targetX - card.x
            val dy = card.targetY - card.y
            if (abs(dx) < SNAP_DIST && abs(dy) < SNAP_DIST) {
                card.x = card.targetX
                card.y = card.targetY
            } else {
                val f = MOVE_LERP * deltaTime * TARGET_FPS
                card.x += dx * f.coerceAtMost(1f)
                card.y += dy * f.coerceAtMost(1f)
            }

            // --- flip animation ---
            when (card.state) {
                Card.STATE_FACE_DOWN -> if (card.flipProgress > 0f)
                    card.flipProgress = (card.flipProgress - FLIP_SPEED * deltaTime).coerceAtLeast(0f)
                Card.STATE_FACE_UP, Card.STATE_MATCHED -> if (card.flipProgress < 1f)
                    card.flipProgress = (card.flipProgress + FLIP_SPEED * deltaTime).coerceAtMost(1f)
            }

            // --- match-pulse decay ---
            if (card.matchPulse > 0f)
                card.matchPulse = (card.matchPulse - PULSE_DECAY * deltaTime).coerceAtLeast(0f)
        }

        // --- phase-specific logic ---
        when (phase) {
            PHASE_DEALING -> {
                if (cards.all { it.x == it.targetX && it.y == it.targetY })
                    phase = PHASE_PLAYING
            }
            PHASE_CHECKING -> {
                checkTimer -= deltaTime
                if (checkTimer <= 0f) resolveCheck()
            }
            PHASE_GATHERING -> {
                val cx = screenWidth / 2f
                val cy = screenHeight / 2f
                if (cards.all { abs(it.x - cx) < SNAP_DIST && abs(it.y - cy) < SNAP_DIST }) {
                    phase = PHASE_WAITING
                    waitTimer = WAIT_DURATION
                }
            }
            PHASE_WAITING -> {
                waitTimer -= deltaTime
                if (waitTimer <= 0f) newRound()
            }
        }
    }

    private fun resolveCheck() {
        val a = cards.getOrNull(firstIndex)
        val b = cards.getOrNull(secondIndex)

        if (a != null && b != null) {
            if (a.emoji == b.emoji) {
                a.state = Card.STATE_MATCHED
                b.state = Card.STATE_MATCHED
                a.matchPulse = 1f
                b.matchPulse = 1f
            } else {
                a.state = Card.STATE_FACE_DOWN
                b.state = Card.STATE_FACE_DOWN
            }
        }

        firstIndex = -1
        secondIndex = -1

        if (cards.all { it.state == Card.STATE_MATCHED }) {
            phase = PHASE_GATHERING
            val cx = screenWidth / 2f
            val cy = screenHeight / 2f
            cards.forEach { it.targetX = cx; it.targetY = cy }
        } else {
            phase = PHASE_PLAYING
        }
    }

    private fun newRound() {
        calcDimensions()
        val emojis = emojiPool.shuffled().take(NUM_PAIRS)
        val paired = (emojis + emojis).shuffled()
        val positions = makePositions()

        for (i in cards.indices) {
            cards[i].apply {
                emoji = paired[i]
                state = Card.STATE_FACE_DOWN
                flipProgress = 0f
                matchPulse = 0f
                targetX = positions[i].first
                targetY = positions[i].second
            }
        }

        firstIndex = -1
        secondIndex = -1
        phase = PHASE_DEALING
    }

    // ── Touch handling ───────────────────────────────────────

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action != MotionEvent.ACTION_DOWN) return true
        if (phase != PHASE_PLAYING) return true

        val tx = event.x
        val ty = event.y
        val hw = cardW / 2
        val hh = cardH / 2

        var best = -1
        var bestDist = Float.MAX_VALUE
        for (i in cards.indices) {
            val c = cards[i]
            if (c.state != Card.STATE_FACE_DOWN) continue
            if (tx in (c.x - hw)..(c.x + hw) && ty in (c.y - hh)..(c.y + hh)) {
                val d = hypot(tx - c.x, ty - c.y)
                if (d < bestDist) { bestDist = d; best = i }
            }
        }
        if (best < 0) return true

        if (firstIndex < 0) {
            firstIndex = best
            cards[best].state = Card.STATE_FACE_UP
        } else if (secondIndex < 0 && best != firstIndex) {
            secondIndex = best
            cards[best].state = Card.STATE_FACE_UP
            phase = PHASE_CHECKING
            checkTimer = CHECK_DELAY
        } else {
            return true
        }

        performClick()
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    // ── Drawing ──────────────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        for (card in cards) drawCard(canvas, card)
    }

    private fun drawCard(canvas: Canvas, card: Card) {
        val hw = cardW / 2
        val hh = cardH / 2

        val angle = card.flipProgress * PI.toFloat()
        val sx = abs(cos(angle))
        if (sx < 0.02f) return               // edge-on → skip

        val pulse = 1f + card.matchPulse * 0.12f
        val showFront = card.flipProgress >= 0.5f

        // shadow
        val so = dpToPx(3f)
        rect.set(
            card.x - hw * sx * pulse + so,
            card.y - hh * pulse + so,
            card.x + hw * sx * pulse + so,
            card.y + hh * pulse + so
        )
        canvas.drawRoundRect(rect, cornerR, cornerR, shadowPaint)

        // card body (scaled by flip + pulse)
        canvas.save()
        canvas.translate(card.x, card.y)
        canvas.scale(sx * pulse, pulse)
        rect.set(-hw, -hh, hw, hh)

        if (showFront) {
            // ---- front face ----
            canvas.drawRoundRect(rect, cornerR, cornerR, frontPaint)
            borderPaint.color =
                if (card.state == Card.STATE_MATCHED) Color.rgb(255, 200, 50)
                else Color.rgb(200, 200, 200)
            canvas.drawRoundRect(rect, cornerR, cornerR, borderPaint)
            if (card.state == Card.STATE_MATCHED) {
                canvas.drawRoundRect(rect, cornerR, cornerR, matchTintPaint)
            }
            val ty = -(textPaint.ascent() + textPaint.descent()) / 2
            canvas.drawText(card.emoji, 0f, ty, textPaint)
        } else {
            // ---- back face ----
            canvas.drawRoundRect(rect, cornerR, cornerR, backPaint)
            borderPaint.color = Color.rgb(70, 119, 210)
            canvas.drawRoundRect(rect, cornerR, cornerR, borderPaint)
            // decorative inner border
            val inset = dpToPx(5f)
            rect.set(-hw + inset, -hh + inset, hw - inset, hh - inset)
            borderPaint.color = Color.rgb(130, 175, 255)
            canvas.drawRoundRect(rect, cornerR - 2, cornerR - 2, borderPaint)
            // question mark
            val ty = -(textPaint.ascent() + textPaint.descent()) / 2
            canvas.drawText("❓", 0f, ty, textPaint)
        }

        canvas.restore()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w > 0 && h > 0 && cards.isNotEmpty()) {
            calcDimensions()
            // Preserve gathering behaviour across rotations: during PHASE_GATHERING
            // and PHASE_WAITING, retarget cards to the new centre instead of
            // assigning new random positions that would prevent completion.
            if (phase == PHASE_GATHERING || phase == PHASE_WAITING) {
                val cx = w / 2f
                val cy = h / 2f
                for (card in cards) {
                    card.targetX = cx
                    card.targetY = cy
                }
            } else {
                val positions = makePositions()
                for (i in cards.indices) {
                    cards[i].targetX = positions[i].first
                    cards[i].targetY = positions[i].second
                }
            }
        }
    }
}
