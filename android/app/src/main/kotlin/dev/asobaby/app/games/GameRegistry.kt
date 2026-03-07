package dev.asobaby.app.games

import dev.asobaby.app.games.bubbles.BubblePopGameView
import dev.asobaby.app.games.animal.AnimalEmojiGameView

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
        )
    )

    /** ランダムに1つのゲームを選ぶ */
    fun randomGame(): GameInfo = games.random()

    /** ID でゲームを取得する */
    fun findById(id: String): GameInfo? = games.find { it.id == id }
}
