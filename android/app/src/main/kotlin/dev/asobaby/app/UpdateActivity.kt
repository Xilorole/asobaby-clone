package dev.asobaby.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.LinearProgressIndicator
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

// ─── Model ─────────────────────────────────────────────────────────

data class Release(
    val version: String,
    val notes: String,
    val apkUrl: String?,
    val apkSize: Long?,
    val prNumber: Int? = null
) {
    val sizeMB: String
        get() = if (apkSize != null) "%.1f MB".format(apkSize / 1024.0 / 1024.0) else ""
}

// ─── Activity ──────────────────────────────────────────────────────

class UpdateActivity : AppCompatActivity() {

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // State
    private var currentVersion = ""
    private var buildNumber = ""
    private var release: Release? = null           // PRD single release
    private var stagingReleases: List<Release> = emptyList()  // STG multiple releases
    private var checking = false
    private var downloading = false
    private var downloadProgress = 0f
    private var errorMessage: String? = null

    // Views
    private lateinit var tvCurrentVersion: TextView
    private lateinit var tvBuildNumber: TextView
    private lateinit var divider: View
    private lateinit var tvLatestVersion: TextView
    private lateinit var tvUpdateStatus: TextView
    private lateinit var btnCheck: MaterialButton
    private lateinit var progressSection: View
    private lateinit var progressBar: LinearProgressIndicator
    private lateinit var tvProgress: TextView
    private lateinit var errorSection: View
    private lateinit var tvError: TextView
    private lateinit var stagingReleasesContainer: LinearLayout

    private val isDebugBuild: Boolean get() = BuildConfig.DEBUG

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Toolbar
        val toolbar = com.google.android.material.appbar.MaterialToolbar(this).apply {
            title = "Asobaby"
            setBackgroundColor(getColor(R.color.blue_500))
            setTitleTextColor(getColor(R.color.white))
        }
        (findViewById<View>(android.R.id.content) as android.view.ViewGroup).let { root ->
            val scrollView = root.getChildAt(0)
            root.removeView(scrollView)
            val wrapper = android.widget.LinearLayout(this).apply {
                orientation = android.widget.LinearLayout.VERTICAL
                addView(toolbar, android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                ))
                addView(scrollView, android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT
                ))
            }
            root.addView(wrapper)
        }

        bindViews()
        initVersion()
        updateUI()
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }

    private fun bindViews() {
        tvCurrentVersion = findViewById(R.id.tvCurrentVersion)
        tvBuildNumber = findViewById(R.id.tvBuildNumber)
        divider = findViewById(R.id.divider)
        tvLatestVersion = findViewById(R.id.tvLatestVersion)
        tvUpdateStatus = findViewById(R.id.tvUpdateStatus)
        btnCheck = findViewById(R.id.btnCheck)
        progressSection = findViewById(R.id.progressSection)
        progressBar = findViewById(R.id.progressBar)
        tvProgress = findViewById(R.id.tvProgress)
        errorSection = findViewById(R.id.errorSection)
        tvError = findViewById(R.id.tvError)
        stagingReleasesContainer = findViewById(R.id.stagingReleasesContainer)

        btnCheck.setOnClickListener { onCheckPressed() }
        findViewById<MaterialButton>(R.id.btnPlayProtect).setOnClickListener { openPlayProtectSettings() }
    }

    // ─── Version ───────────────────────────────────────────────────

    private fun initVersion() {
        val (ver, code) = getCurrentVersion()
        currentVersion = ver
        buildNumber = code
    }

    private fun getCurrentVersion(): Pair<String, String> {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            val versionName = info.versionName ?: "0.0.0"
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toString()
            }
            Pair(versionName, versionCode)
        } catch (e: Exception) {
            Pair("0.0.0", "0")
        }
    }

    // ─── Update Check ──────────────────────────────────────────────

    private fun onCheckPressed() {
        scope.launch {
            checkForUpdate()
            if (errorMessage != null) return@launch

            if (!isDebugBuild) {
                // PRD: show dialog for single release
                val rel = release ?: return@launch
                if (hasUpdate()) {
                    showUpdateDialog(rel)
                } else {
                    com.google.android.material.snackbar.Snackbar
                        .make(btnCheck, "Up to date (v${rel.version})", com.google.android.material.snackbar.Snackbar.LENGTH_SHORT)
                        .show()
                }
            }
            // STG: list is already rendered in updateUI(), no additional dialog needed
        }
    }

    private suspend fun checkForUpdate() {
        checking = true
        errorMessage = null
        release = null
        stagingReleases = emptyList()
        updateUI()

        try {
            if (isDebugBuild) {
                stagingReleases = withContext(Dispatchers.IO) { fetchStagingReleases() }
            } else {
                release = withContext(Dispatchers.IO) { fetchLatestProductionRelease() }
            }
        } catch (e: Exception) {
            errorMessage = "Failed to fetch release info.\n${e.message}"
        } finally {
            checking = false
            updateUI()
        }
    }

    // ─── Fetch: Production ─────────────────────────────────────────

    private fun fetchLatestProductionRelease(): Release {
        // /releases/latest always returns the latest published full (non-pre-release)
        val url = URL("https://api.github.com/repos/Xilorole/asobaby-clone/releases/latest")
        val conn = url.openConnection() as HttpURLConnection
        conn.setRequestProperty("Accept", "application/vnd.github+json")
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000

        try {
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)

            val tag = json.getString("tag_name")
            val version = tag.removePrefix("v")
            val notes = json.optString("body", "")

            var apkUrl: String? = null
            var apkSize: Long? = null

            val assets = json.optJSONArray("assets")
            val preferredAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")

            // Try architecture-specific APK first
            if (assets != null) {
                outer@ for (abi in preferredAbis) {
                    for (i in 0 until assets.length()) {
                        val asset = assets.getJSONObject(i)
                        val name = asset.optString("name", "")
                        if (name.contains(abi) && name.endsWith(".apk")) {
                            apkUrl = asset.getString("browser_download_url")
                            apkSize = asset.optLong("size", 0)
                            break@outer
                        }
                    }
                }
                // Fall back to any .apk
                if (apkUrl == null) {
                    for (i in 0 until assets.length()) {
                        val asset = assets.getJSONObject(i)
                        val name = asset.optString("name", "")
                        if (name.endsWith(".apk")) {
                            apkUrl = asset.getString("browser_download_url")
                            apkSize = asset.optLong("size", 0)
                            break
                        }
                    }
                }
            }

            return Release(version, notes, apkUrl, apkSize)
        } finally {
            conn.disconnect()
        }
    }

    // ─── Fetch: Staging ────────────────────────────────────────────

    private fun fetchStagingReleases(): List<Release> {
        val url = URL("https://api.github.com/repos/Xilorole/asobaby-clone/releases?per_page=100")
        val conn = url.openConnection() as HttpURLConnection
        conn.setRequestProperty("Accept", "application/vnd.github+json")
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000

        try {
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val array = JSONArray(body)
            val releases = mutableListOf<Release>()

            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)

                // Only include staging pre-releases tagged stg-pr-{number}
                if (!item.optBoolean("prerelease", false)) continue
                val tagName = item.optString("tag_name", "")
                if (!tagName.startsWith("stg-pr-")) continue

                val prNumber = tagName.removePrefix("stg-pr-").toIntOrNull() ?: continue
                val releaseName = item.optString("name", tagName)
                // Extract version like "26.3.3-dev" from name "Staging PR #5 (v26.3.3-dev)"
                val version = Regex("""v([\d.]+(?:-\w+)?)""").find(releaseName)
                    ?.groupValues?.get(1) ?: "unknown"
                val notes = item.optString("body", "")

                var apkUrl: String? = null
                var apkSize: Long? = null
                val assets = item.optJSONArray("assets")
                if (assets != null) {
                    for (j in 0 until assets.length()) {
                        val asset = assets.getJSONObject(j)
                        val name = asset.optString("name", "")
                        if (name.endsWith(".apk")) {
                            apkUrl = asset.optString("browser_download_url").takeIf { it.isNotEmpty() }
                            apkSize = asset.optLong("size", 0).takeIf { it > 0 }
                            break
                        }
                    }
                }

                releases.add(Release(version, notes, apkUrl, apkSize, prNumber))
            }

            // Show newest PRs first
            return releases.sortedByDescending { it.prNumber ?: 0 }
        } finally {
            conn.disconnect()
        }
    }

    // ─── Download & Install ────────────────────────────────────────

    private suspend fun downloadAndInstall(rel: Release) {
        val url = rel.apkUrl ?: return
        downloading = true
        downloadProgress = 0f
        errorMessage = null
        updateUI()

        try {
            val file = withContext(Dispatchers.IO) {
                downloadApk(url) { progress ->
                    scope.launch(Dispatchers.Main) {
                        downloadProgress = progress
                        updateUI()
                    }
                }
            }
            downloading = false
            updateUI()
            installApk(file)
        } catch (e: Exception) {
            downloading = false
            errorMessage = "Download failed.\n${e.message}"
            updateUI()
        }
    }

    private fun downloadApk(url: String, onProgress: (Float) -> Unit): File {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 30_000
        conn.readTimeout = 30_000
        // GitHub download URLs redirect — follow them
        conn.instanceFollowRedirects = true

        try {
            val totalBytes = conn.contentLength.toLong()
            val file = File(cacheDir, "asobaby-update.apk")
            var downloadedBytes = 0L

            BufferedInputStream(conn.inputStream).use { input ->
                FileOutputStream(file).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloadedBytes += bytesRead
                        if (totalBytes > 0) {
                            onProgress(downloadedBytes.toFloat() / totalBytes)
                        }
                    }
                }
            }
            return file
        } finally {
            conn.disconnect()
        }
    }

    private fun installApk(file: File) {
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    // ─── Update Dialog (PRD only) ──────────────────────────────────

    private fun showUpdateDialog(rel: Release) {
        val message = buildString {
            append("New version: ${rel.version}")
            if (rel.sizeMB.isNotEmpty()) append("\nSize: ${rel.sizeMB}")
            if (rel.notes.isNotEmpty()) {
                append("\n\nRelease notes:\n${rel.notes}")
            }
            append("\n\n⚠ Play Protect の警告が出た場合は")
            append("「詳細」→「インストールする」で続行できます。")
        }

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.update_dialog_title))
            .setMessage(message)
            .setPositiveButton(getString(R.string.install)) { _, _ ->
                scope.launch { downloadAndInstall(rel) }
            }
            .setNeutralButton(getString(R.string.open_play_protect_settings)) { _, _ ->
                openPlayProtectSettings()
            }
            .setNegativeButton(getString(R.string.later), null)
            .show()
    }

    // ─── Play Protect Settings ──────────────────────────────────────

    private fun openPlayProtectSettings() {
        try {
            startActivity(Intent("com.google.android.finsky.PLAY_PROTECT_SETTINGS").apply {
                setPackage("com.android.vending")
            })
        } catch (_: ActivityNotFoundException) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://support.google.com/googleplay/answer/2812853")))
            } catch (_: Exception) {
                com.google.android.material.snackbar.Snackbar
                    .make(btnCheck, "Play Store が見つかりません", com.google.android.material.snackbar.Snackbar.LENGTH_SHORT)
                    .show()
            }
        }
    }

    // ─── Version Comparison (PRD only) ────────────────────────────

    private fun hasUpdate(): Boolean {
        val rel = release ?: return false
        return compareVersions(rel.version, currentVersion) > 0
    }

    private fun compareVersions(a: String, b: String): Int {
        val pa = a.split(".").map { it.toIntOrNull() ?: 0 }
        val pb = b.split(".").map { it.toIntOrNull() ?: 0 }
        for (i in 0 until 3) {
            val va = pa.getOrElse(i) { 0 }
            val vb = pb.getOrElse(i) { 0 }
            if (va != vb) return va - vb
        }
        return 0
    }

    // ─── UI Update ─────────────────────────────────────────────────

    private fun updateUI() {
        tvCurrentVersion.text = "v$currentVersion"
        tvBuildNumber.text = "Build $buildNumber"

        // Button state
        val busy = checking || downloading
        btnCheck.isEnabled = !busy
        btnCheck.text = if (checking) getString(R.string.checking) else getString(R.string.check_for_update)

        if (isDebugBuild) {
            updateStagingUI()
        } else {
            updateProductionUI()
        }

        // Progress
        if (downloading) {
            progressSection.visibility = View.VISIBLE
            progressBar.progress = (downloadProgress * 100).toInt()
            tvProgress.text = "${(downloadProgress * 100).toInt()}%"
        } else {
            progressSection.visibility = View.GONE
        }

        // Error
        if (errorMessage != null) {
            errorSection.visibility = View.VISIBLE
            tvError.text = errorMessage
        } else {
            errorSection.visibility = View.GONE
        }
    }

    private fun updateProductionUI() {
        stagingReleasesContainer.visibility = View.GONE

        val rel = release
        if (rel != null) {
            divider.visibility = View.VISIBLE
            tvLatestVersion.visibility = View.VISIBLE
            tvLatestVersion.text = "Latest: v${rel.version}"

            tvUpdateStatus.visibility = View.VISIBLE
            if (hasUpdate()) {
                tvUpdateStatus.text = getString(R.string.update_available)
                tvUpdateStatus.setTextColor(getColor(R.color.orange))
            } else {
                tvUpdateStatus.text = getString(R.string.up_to_date)
                tvUpdateStatus.setTextColor(getColor(R.color.green))
            }
        } else {
            divider.visibility = View.GONE
            tvLatestVersion.visibility = View.GONE
            tvUpdateStatus.visibility = View.GONE
        }
    }

    private fun updateStagingUI() {
        tvLatestVersion.visibility = View.GONE
        tvUpdateStatus.visibility = View.GONE

        stagingReleasesContainer.removeAllViews()

        if (stagingReleases.isEmpty()) {
            if (!checking) {
                divider.visibility = View.GONE
                stagingReleasesContainer.visibility = View.GONE
            }
            return
        }

        divider.visibility = View.VISIBLE
        stagingReleasesContainer.visibility = View.VISIBLE

        for (rel in stagingReleases) {
            stagingReleasesContainer.addView(buildStagingReleaseItem(rel))
        }
    }

    private fun buildStagingReleaseItem(rel: Release): View {
        val dp8 = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt()

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp8 }
        }

        val label = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            val prLabel = if (rel.prNumber != null) "PR #${rel.prNumber}" else "Staging"
            val sizeText = if (rel.sizeMB.isNotEmpty()) " (${rel.sizeMB})" else ""
            text = "$prLabel – v${rel.version}$sizeText"
            textSize = 14f
        }

        val btn = MaterialButton(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            text = getString(R.string.install)
            isEnabled = rel.apkUrl != null
            setOnClickListener {
                showStagingInstallDialog(rel)
            }
        }

        row.addView(label)
        row.addView(btn)
        return row
    }

    private fun showStagingInstallDialog(rel: Release) {
        val prLabel = if (rel.prNumber != null) "PR #${rel.prNumber} " else ""
        val message = buildString {
            append("${prLabel}v${rel.version} をインストールします。")
            if (rel.sizeMB.isNotEmpty()) append("\nSize: ${rel.sizeMB}")
            append("\n\n⚠ Play Protect の警告が出た場合は")
            append("「詳細」→「インストールする」で続行できます。")
        }

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.install))
            .setMessage(message)
            .setPositiveButton(getString(R.string.install)) { _, _ ->
                scope.launch { downloadAndInstall(rel) }
            }
            .setNeutralButton(getString(R.string.open_play_protect_settings)) { _, _ ->
                openPlayProtectSettings()
            }
            .setNegativeButton(getString(R.string.later), null)
            .show()
    }
}
