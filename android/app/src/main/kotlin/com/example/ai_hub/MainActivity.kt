package com.example.ai_hub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.WebView
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.aihub.webview"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrEmpty()) {
                            result.error("INVALID_URL", "URL is null or empty", null)
                        } else if (url.startsWith("http://") && Build.VERSION.SDK_INT >= 28) {
                            // Android 9+ 默认禁止 WebView 加载明文 HTTP，改用外部浏览器打开
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("OPEN_FAILED", e.message, null)
                            }
                        } else {
                            val intent = Intent(this, WebViewActivity::class.java)
                            intent.putExtra("url", url)
                            startActivity(intent)
                            result.success(null)
                        }
                    }
                    "checkAppInstalled" -> {
                        val packageName = call.argument<String>("packageName")
                        try {
                            packageManager.getPackageInfo(packageName!!, android.content.pm.PackageManager.MATCH_UNINSTALLED_PACKAGES)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(packageName!!)
                            if (intent != null) {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(null)
                            } else {
                                // shell am start 兜底
                                val process = Runtime.getRuntime().exec(
                                    arrayOf("sh", "-c",
                                        "am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $packageName")
                                )
                                val output = process.inputStream.bufferedReader().readText()
                                val error = process.errorStream.bufferedReader().readText()
                                process.waitFor()
                                if (output.contains("Error") || error.isNotEmpty()) {
                                    result.error("LAUNCH_FAILED", error.ifEmpty { output }, null)
                                } else {
                                    result.success(null)
                                }
                            }
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }
                    "clearWebCache" -> {
                        try {
                            // 借助临时 WebView 实例清空全局缓存（不动 Cookie，登录状态保留）
                            val temp = WebView(this)
                            temp.clearCache(true)
                            temp.destroy()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CLEAR_CACHE_FAILED", e.message, null)
                        }
                    }
                    "updateShortcuts" -> {
                        try {
                            // 整体替换动态快捷方式；低于 API 25 由 ShortcutManagerCompat 自动降级为 no-op
                            val items = call.argument<List<Map<String, Any>>>("shortcuts") ?: emptyList()
                            val shortcuts = items.mapIndexedNotNull { index, item ->
                                val name = item["name"] as? String ?: return@mapIndexedNotNull null
                                val url = item["url"] as? String ?: return@mapIndexedNotNull null
                                val id = (item["id"] as? String) ?: "service_$index"
                                val intent = Intent(this, MainActivity::class.java)
                                    .setAction(Intent.ACTION_VIEW)
                                    .putExtra(EXTRA_SHORTCUT_URL, url)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                ShortcutInfoCompat.Builder(this, id)
                                    .setShortLabel(name)
                                    .setIntent(intent)
                                    .build()
                            }
                            ShortcutManagerCompat.setDynamicShortcuts(this, shortcuts)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHORTCUTS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            handleShortcutIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShortcutIntent(intent)
    }

    /// 快捷方式以显式意图打开 MainActivity（singleTop），带 url 时转交内置 WebView
    private fun handleShortcutIntent(intent: Intent?) {
        val url = intent?.getStringExtra(EXTRA_SHORTCUT_URL) ?: return
        if (url.isEmpty()) return
        val webIntent = Intent(this, WebViewActivity::class.java)
        webIntent.putExtra("url", url)
        startActivity(webIntent)
    }

    companion object {
        const val EXTRA_SHORTCUT_URL = "shortcut_url"
    }
}
