package dev.asobaby.app.ui

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.card.MaterialCardView
import dev.asobaby.app.GameHostActivity
import dev.asobaby.app.R
import dev.asobaby.app.games.GameRegistry

/**
 * ゲーム選択画面。
 * 登録されているすべてのゲームをカードで表示し、タップで選択する。
 */
class GameSelectionActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val toolbar = MaterialToolbar(this).apply {
            title = getString(R.string.game_selection_title)
            setBackgroundColor(getColor(R.color.blue_500))
            setTitleTextColor(getColor(R.color.white))
            setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material)
            setNavigationIconTint(getColor(R.color.white))
            setNavigationOnClickListener { finish() }
        }

        val scrollView = ScrollView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        // ゲームカードを生成
        for (gameInfo in GameRegistry.games) {
            val card = createGameCard(gameInfo.id, gameInfo.name, gameInfo.description)
            container.addView(card)
        }

        scrollView.addView(container)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(toolbar, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ))
            addView(scrollView, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            ))
        }

        setContentView(root)
    }

    private fun createGameCard(gameId: String, name: String, description: String): MaterialCardView {
        val card = MaterialCardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(12)
            }
            radius = dp(16).toFloat()
            cardElevation = dp(4).toFloat()
            setCardBackgroundColor(getColor(R.color.white))
            isClickable = true
            isFocusable = true

            // タップでゲームを選択して戻る
            setOnClickListener {
                val resultIntent = Intent().apply {
                    putExtra(GameHostActivity.EXTRA_GAME_ID, gameId)
                }
                setResult(Activity.RESULT_OK, resultIntent)
                finish()
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
        }

        val nameView = TextView(this).apply {
            text = name
            textSize = 24f
            setTextColor(getColor(R.color.game_card_title))
            gravity = Gravity.START
        }

        val descView = TextView(this).apply {
            text = description
            textSize = 16f
            setTextColor(getColor(R.color.game_card_description))
            setPadding(0, dp(8), 0, 0)
        }

        content.addView(nameView)
        content.addView(descView)
        card.addView(content)

        return card
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
