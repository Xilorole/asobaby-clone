package dev.asobaby.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.floatingactionbutton.FloatingActionButton
import dev.asobaby.app.games.GameRegistry
import dev.asobaby.app.games.GameView
import dev.asobaby.app.ui.GameSelectionActivity

/**
 * メインのランチャー Activity。
 * ゲームを全画面で表示し、フローティングボタンでランダム切替・ゲーム選択・設定を提供する。
 */
class GameHostActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_GAME_ID = "game_id"
        private const val REQUEST_SELECT_GAME = 1001
    }

    private lateinit var gameContainer: FrameLayout
    private lateinit var btnRandom: FloatingActionButton
    private lateinit var btnSelect: FloatingActionButton
    private lateinit var btnSettings: FloatingActionButton

    private var currentGameView: GameView? = null
    private var currentGameId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_game_host)

        hideSystemUI()

        gameContainer = findViewById(R.id.gameContainer)
        btnRandom = findViewById(R.id.btnRandom)
        btnSelect = findViewById(R.id.btnSelect)
        btnSettings = findViewById(R.id.btnSettings)

        btnRandom.setOnClickListener { switchToRandomGame() }
        btnSelect.setOnClickListener { openGameSelection() }
        btnSettings.setOnClickListener { openSettings() }

        // Intent からゲームIDが渡された場合はそれを起動
        val requestedGameId = intent.getStringExtra(EXTRA_GAME_ID)
        if (requestedGameId != null) {
            loadGame(requestedGameId)
        } else {
            // ランダムにゲームを起動
            switchToRandomGame()
        }
    }

    override fun onResume() {
        super.onResume()
        hideSystemUI()
        currentGameView?.resumeGame()
    }

    override fun onPause() {
        super.onPause()
        currentGameView?.pauseGame()
    }

    override fun onDestroy() {
        super.onDestroy()
        currentGameView?.stopGame()
    }

    // ─── ゲーム管理 ────────────────────────────────

    private fun loadGame(gameId: String) {
        val gameInfo = GameRegistry.findById(gameId) ?: return
        setGame(gameInfo.id, gameInfo.factory(this))
    }

    private fun switchToRandomGame() {
        val games = GameRegistry.games
        // 現在と違うゲームを選ぶ (2つ以上ある場合)
        val candidates = if (games.size > 1 && currentGameId != null) {
            games.filter { it.id != currentGameId }
        } else {
            games
        }
        val gameInfo = candidates.random()
        setGame(gameInfo.id, gameInfo.factory(this))
    }

    private fun setGame(gameId: String, gameView: GameView) {
        // 現在のゲームを停止・削除
        currentGameView?.stopGame()
        gameContainer.removeAllViews()

        // 新しいゲームを設定
        currentGameId = gameId
        currentGameView = gameView

        gameContainer.addView(
            gameView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        gameView.startGame()
    }

    // ─── 画面遷移 ─────────────────────────────────

    private fun openGameSelection() {
        val intent = Intent(this, GameSelectionActivity::class.java)
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_SELECT_GAME)
    }

    private fun openSettings() {
        val intent = Intent(this, UpdateActivity::class.java)
        startActivity(intent)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SELECT_GAME && resultCode == RESULT_OK) {
            val gameId = data?.getStringExtra(EXTRA_GAME_ID)
            if (gameId != null) {
                loadGame(gameId)
            }
        }
    }

    // ─── フルスクリーン ───────────────────────────

    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.systemBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
        }
    }
}
