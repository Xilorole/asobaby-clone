package dev.asobaby.app.games.hiragana

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.speech.tts.TextToSpeech
import android.util.AttributeSet
import android.view.MotionEvent
import dev.asobaby.app.games.GameView
import java.util.Locale

private const val TTS_UTTERANCE_ID = "hiragana_tts"
private const val HINT_TEXT_COLOR = 0x66000000

/**
 * ひらがな学習ゲーム。
 * 画面上半分にひらがな文字、下半分に対応する絵文字と単語を表示する。
 * 上半分をタップすると文字を読み上げ、下半分をタップすると単語を読み上げる。
 * 「つぎへ」ボタンでランダムに次のカードに切り替える。
 */
class HiraganaGameView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : GameView(context, attrs, defStyleAttr) {

    // ─── データクラス ──────────────────────────────

    private data class HiraganaCard(
        val character: String,
        val word: String,
        val emoji: String
    )

    // ─── カードデータ ──────────────────────────────

    private val cards = listOf(
        HiraganaCard("あ", "あり", "🐜"),
        HiraganaCard("い", "いぬ", "🐶"),
        HiraganaCard("う", "うし", "🐄"),
        HiraganaCard("え", "えんぴつ", "✏️"),
        HiraganaCard("お", "おに", "👹"),
        HiraganaCard("か", "かに", "🦀"),
        HiraganaCard("き", "きつね", "🦊"),
        HiraganaCard("く", "くま", "🐻"),
        HiraganaCard("け", "けいさつ", "🚔"),
        HiraganaCard("こ", "こうもり", "🦇"),
        HiraganaCard("さ", "さかな", "🐟"),
        HiraganaCard("し", "しか", "🦌"),
        HiraganaCard("す", "すいか", "🍉"),
        HiraganaCard("た", "たこ", "🐙"),
        HiraganaCard("ち", "ちょうちょ", "🦋"),
        HiraganaCard("つ", "つき", "🌙"),
        HiraganaCard("て", "てんとうむし", "🐞"),
        HiraganaCard("と", "とり", "🐦"),
        HiraganaCard("な", "なす", "🍆"),
        HiraganaCard("に", "にじ", "🌈"),
        HiraganaCard("ね", "ねこ", "🐱"),
        HiraganaCard("は", "はな", "🌸"),
        HiraganaCard("ひ", "ひつじ", "🐑"),
        HiraganaCard("ふ", "ふね", "⛵"),
        HiraganaCard("へ", "へび", "🐍"),
        HiraganaCard("ほ", "ほし", "⭐"),
        HiraganaCard("み", "みかん", "🍊"),
        HiraganaCard("も", "もも", "🍑"),
        HiraganaCard("や", "やぎ", "🐐"),
        HiraganaCard("ゆ", "ゆき", "❄️"),
        HiraganaCard("ら", "らいおん", "🦁"),
        HiraganaCard("り", "りんご", "🍎"),
        HiraganaCard("れ", "れもん", "🍋"),
        HiraganaCard("わ", "わに", "🐊"),
        HiraganaCard("ろ", "ろけっと", "🚀")
    )

    // ─── ゲーム状態 ────────────────────────────────

    private var currentCard: HiraganaCard = cards[0]
    private var previousIndex: Int = -1
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    // ─── レイアウト ────────────────────────────────

    private var topHalfY = 0f       // 上半分と下半分の境界 Y 座標
    private val btnRect = RectF()   // 「つぎへ」ボタンの領域

    // ─── ペイント ──────────────────────────────────

    private val bgTopPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFFFF9C4.toInt()  // 淡い黄色
    }
    private val bgBottomPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFE3F2FD.toInt()  // 淡い水色
    }
    private val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFBDBDBD.toInt()
        strokeWidth = 4f
        style = Paint.Style.STROKE
    }
    private val charPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF1A237E.toInt()  // 濃い紺色
        textAlign = Paint.Align.CENTER
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }
    private val wordPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF1B5E20.toInt()  // 濃い緑
        textAlign = Paint.Align.CENTER
    }
    private val btnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFFF7043.toInt()  // 明るいオレンジ
    }
    private val btnTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
    }
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = HINT_TEXT_COLOR
        textAlign = Paint.Align.CENTER
    }

    init {
        gameBgColor = 0xFFFFF9C4.toInt()
    }

    // ─── ライフサイクル ────────────────────────────

    override fun startGame() {
        val font = zenFont
        charPaint.typeface = font
        wordPaint.typeface = font
        btnTextPaint.typeface = font
        hintPaint.typeface = font
        emojiPaint.typeface = font
        showRandomCard()
        initTts()
    }

    override fun stopGame() {
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    override fun pauseGame() {}

    override fun resumeGame() {}

    // ─── サイズ変更 ────────────────────────────────

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        updateLayout()
    }

    private fun updateLayout() {
        if (screenWidth == 0 || screenHeight == 0) return
        topHalfY = screenHeight * 0.5f
        val btnHeight = dpToPx(48f)
        val btnMarginH = dpToPx(40f)
        val btnMarginB = dpToPx(90f)
        btnRect.set(
            btnMarginH,
            screenHeight - btnMarginB - btnHeight,
            screenWidth - btnMarginH,
            screenHeight - btnMarginB
        )
    }

    // ─── カード切り替え ────────────────────────────

    private fun showRandomCard() {
        val candidates = cards.indices.filter { it != previousIndex }
        val nextIndex = candidates.random()
        previousIndex = nextIndex
        currentCard = cards[nextIndex]
        invalidate()
    }

    // ─── TTS 初期化・読み上げ ──────────────────────

    private fun initTts() {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.JAPAN
                tts?.setSpeechRate(0.8f)
                tts?.setPitch(1.05f)
                ttsReady = true
            }
        }
    }

    private fun speak(text: String) {
        if (ttsReady) {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, TTS_UTTERANCE_ID)
        }
    }

    // ─── 描画 ──────────────────────────────────────

    override fun onDraw(canvas: Canvas) {
        if (screenWidth == 0 || screenHeight == 0) return

        // 背景
        canvas.drawRect(0f, 0f, screenWidth.toFloat(), topHalfY, bgTopPaint)
        canvas.drawRect(0f, topHalfY, screenWidth.toFloat(), screenHeight.toFloat(), bgBottomPaint)

        // 区切り線
        canvas.drawLine(0f, topHalfY, screenWidth.toFloat(), topHalfY, dividerPaint)

        drawCharacter(canvas)
        drawEmojiAndWord(canvas)
        drawNextButton(canvas)
    }

    private fun drawCharacter(canvas: Canvas) {
        // ひらがな文字を上半分中央に大きく表示
        val charSize = topHalfY * 0.58f
        charPaint.textSize = charSize
        val fm = charPaint.fontMetrics
        val textCenterY = topHalfY / 2f - (fm.ascent + fm.descent) / 2f
        canvas.drawText(currentCard.character, screenWidth / 2f, textCenterY, charPaint)

        // タップヒント
        hintPaint.textSize = dpToPx(14f)
        canvas.drawText("👆 タップして よもう", screenWidth / 2f, topHalfY - dpToPx(14f), hintPaint)
    }

    private fun drawEmojiAndWord(canvas: Canvas) {
        val areaTop = topHalfY
        val areaBottom = btnRect.top - dpToPx(8f)
        val areaHeight = areaBottom - areaTop

        // 絵文字を中央上寄りに配置
        val emojiSize = (areaHeight * 0.38f).coerceAtMost(dpToPx(100f))
        emojiPaint.textSize = emojiSize
        val emojiFm = emojiPaint.fontMetrics
        val emojiCenterY = areaTop + areaHeight * 0.32f
        val emojiY = emojiCenterY - (emojiFm.ascent + emojiFm.descent) / 2f
        canvas.drawText(currentCard.emoji, screenWidth / 2f, emojiY, emojiPaint)

        // 単語テキストを絵文字の下に表示
        val wordSize = (areaHeight * 0.16f).coerceIn(dpToPx(24f), dpToPx(44f))
        wordPaint.textSize = wordSize
        val wordFm = wordPaint.fontMetrics
        val wordY = emojiCenterY + emojiSize * 0.65f - (wordFm.ascent + wordFm.descent) / 2f
        canvas.drawText(currentCard.word, screenWidth / 2f, wordY, wordPaint)

        // タップヒント
        hintPaint.textSize = dpToPx(14f)
        canvas.drawText("👆 タップして きこう", screenWidth / 2f, btnRect.top - dpToPx(10f), hintPaint)
    }

    private fun drawNextButton(canvas: Canvas) {
        canvas.drawRoundRect(btnRect, dpToPx(24f), dpToPx(24f), btnPaint)
        btnTextPaint.textSize = dpToPx(18f)
        val fm = btnTextPaint.fontMetrics
        val textY = btnRect.centerY() - (fm.ascent + fm.descent) / 2f
        canvas.drawText("つぎへ  ▶", screenWidth / 2f, textY, btnTextPaint)
    }

    // ─── タッチ ────────────────────────────────────

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) {
            val x = event.x
            val y = event.y
            when {
                y < topHalfY -> speak(currentCard.character)
                btnRect.contains(x, y) -> showRandomCard()
                else -> speak(currentCard.word)
            }
            performClick()
            return true
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean = super.performClick()
}
