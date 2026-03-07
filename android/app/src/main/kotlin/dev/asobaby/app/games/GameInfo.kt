package dev.asobaby.app.games

import android.content.Context

/**
 * ゲームのメタデータ。
 *
 * @param id       一意な識別子 (スネークケース)
 * @param name     表示名 (絵文字付き推奨)
 * @param description 短い説明文
 * @param factory  GameView を生成するファクトリ関数
 */
data class GameInfo(
    val id: String,
    val name: String,
    val description: String,
    val factory: (Context) -> GameView
)
