package dev.asobaby.app.games

import dev.asobaby.app.games.bubbles.BubblePopGameView
import dev.asobaby.app.games.animal.AnimalEmojiGameView
import dev.asobaby.app.games.memory.MemoryCardGameView
import dev.asobaby.app.games.fireworks.FireworksGameView
import dev.asobaby.app.games.hiragana.HiraganaGameView

/**
 * 全ゲームの登録簿。
 * 新しいゲームを追加するにはこの [games] リストにエントリを追加する。
 */
object GameRegistry {

    val games: List<GameInfo> = listOf(
        GameInfo(
            id = "bubble_pop",
            name = "🫧 あわあわ",
            description = "泡をタップしてパチン！",
            factory = { context -> BubblePopGameView(context) }
        ),
        GameInfo(
            id = "animal_emoji",
            name = "❓ どうぶつ",
            description = "はてなをタップして動物を見つけよう！",
            factory = { context -> AnimalEmojiGameView(context) }
        ),
        GameInfo(
            id = "memory_card",
            name = "🃏 しんけいすいじゃく",
            description = "カードをめくってペアを見つけよう！",
            factory = { context -> MemoryCardGameView(context) }
        ),
        GameInfo(
            id = "fireworks",
            name = "🎆 はなび",
            description = "タップして花火をあげよう！",
            factory = { context -> FireworksGameView(context) }
        ),
        GameInfo(
            id = "hiragana",
            name = "🔤 ひらがな",
            description = "ひらがなをおぼえよう！タップすると読み上げてくれるよ！",
            factory = { context -> HiraganaGameView(context) }
        )
    )

    /** ランダムに1つのゲームを選ぶ */
    fun randomGame(): GameInfo = games.random()

    /** ID でゲームを取得する */
    fun findById(id: String): GameInfo? = games.find { it.id == id }
}
