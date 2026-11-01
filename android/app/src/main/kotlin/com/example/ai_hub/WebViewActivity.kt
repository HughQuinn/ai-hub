package com.example.ai_hub

import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.Button
import android.widget.TextView
import android.widget.ImageView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

class WebViewActivity : android.app.Activity() {

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var errorLayout: LinearLayout
    private var currentUrl: String = ""
    private var adBlockEnabled = true

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)

        // 广告拦截开关由 Flutter 写入 SharedPreferences（键带 flutter. 前缀），默认开启
        adBlockEnabled = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getBoolean("flutter.ad_block_enabled", true)

        val container = FrameLayout(this)

        // WebView
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.userAgentString = settings.userAgentString + " WebViewBrowser/1.0"

            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest?
                ): WebResourceResponse? {
                    val url = request?.url?.toString() ?: return null
                    if (adBlockEnabled && AdBlocker.shouldBlock(url)) {
                        Log.d("AdBlocker", "blocked: ${request.url.host}")
                        return AdBlocker.emptyResponse()
                    }
                    return null
                }

                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?
                ): Boolean {
                    val url = request?.url?.toString() ?: return false
                    val scheme = request.url?.scheme

                    if (scheme == "http" || scheme == "https") {
                        return false
                    }

                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        startActivity(intent)
                    } catch (_: Exception) {
                    }
                    return true
                }

                override fun onReceivedError(
                    view: WebView?,
                    errorCode: Int,
                    description: String?,
                    failingUrl: String?
                ) {
                    showErrorLayout()
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: WebResourceError?
                ) {
                    if (request?.isForMainFrame == true) {
                        showErrorLayout()
                    }
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    hideErrorLayout()
                }
            }

            webChromeClient = object : android.webkit.WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    if (newProgress < 100) {
                        progressBar.visibility = View.VISIBLE
                        progressBar.progress = newProgress
                    } else {
                        progressBar.visibility = View.GONE
                    }
                }
            }

            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.allowFileAccess = false
        }

        container.addView(webView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        // 加载进度条 - 状态栏下方，2dp 高度
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = false
            max = 100
            progress = 0
            visibility = View.GONE
            val params = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dpToPx(2)
            )
            params.gravity = Gravity.TOP
            layoutParams = params
            progressDrawable = ContextCompat.getDrawable(
                this@WebViewActivity,
                android.R.drawable.progress_horizontal
            )?.apply {
                setColorFilter(Color.parseColor("#2196F3"), android.graphics.PorterDuff.Mode.SRC_IN)
            }
        }
        container.addView(progressBar)

        // 错误提示布局 - 居中显示（背景跟随系统深浅色）
        val isNight = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val errorBgColor = if (isNight) Color.parseColor("#111318") else Color.WHITE
        val errorTextColor = if (isNight) Color.parseColor("#9CA3AF") else Color.parseColor("#757575")
        errorLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            visibility = View.GONE
            setBackgroundColor(errorBgColor)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )

            addView(ImageView(this@WebViewActivity).apply {
                setImageResource(android.R.drawable.ic_dialog_alert)
                val size = dpToPx(64)
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                }
                setColorFilter(Color.parseColor("#9E9E9E"))
            })

            addView(TextView(this@WebViewActivity).apply {
                text = "页面加载失败"
                textSize = 16f
                setTextColor(errorTextColor)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = dpToPx(16)
                    gravity = Gravity.CENTER_HORIZONTAL
                }
            })

            addView(Button(this@WebViewActivity).apply {
                text = "重试"
                setOnClickListener {
                    hideErrorLayout()
                    if (currentUrl.isNotEmpty()) {
                        webView.loadUrl(currentUrl)
                    }
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = dpToPx(16)
                    gravity = Gravity.CENTER_HORIZONTAL
                }
            })

            // 加载失败时的逃生出口：转交系统浏览器（仅 http/https 有意义）
            addView(Button(this@WebViewActivity).apply {
                text = "在浏览器打开"
                setOnClickListener {
                    val url = currentUrl
                    if (url.startsWith("http://") || url.startsWith("https://")) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        } catch (_: Exception) {
                        }
                    }
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = dpToPx(8)
                    gravity = Gravity.CENTER_HORIZONTAL
                }
            })
        }
        container.addView(errorLayout)

        setContentView(container)

        // 处理顶部和底部安全区域（状态栏 + 导航栏）
        val rootView = findViewById<ViewGroup>(android.R.id.content)
        ViewCompat.setOnApplyWindowInsetsListener(rootView) { view, windowInsets ->
            val insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(insets.left, insets.top, insets.right, insets.bottom)
            WindowInsetsCompat.CONSUMED
        }

        currentUrl = intent.getStringExtra("url") ?: ""
        if (currentUrl.isNotEmpty()) {
            webView.loadUrl(currentUrl)
        }
    }

    private fun showErrorLayout() {
        errorLayout.visibility = View.VISIBLE
        webView.visibility = View.INVISIBLE
    }

    private fun hideErrorLayout() {
        errorLayout.visibility = View.GONE
        webView.visibility = View.VISIBLE
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density + 0.5f).toInt()
    }

    override fun onPause() {
        // 强制将 Cookie 落盘，进程被杀时登录状态不丢失
        CookieManager.getInstance().flush()
        super.onPause()
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }
}
