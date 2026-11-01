package com.example.ai_hub

import android.net.Uri
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream

/// 内置 WebView 的广告/追踪请求拦截。
///
/// 设计取舍：只按主机后缀精确匹配经典广告与统计域名并返回空响应，
/// 不做 DOM/JS 注入隐藏页面元素——后者需要对每个站点单独维护选择器，
/// 极易误伤站点功能；黑名单保守收录，不包含 CDN 与第三方登录相关域名。
object AdBlocker {

    private val blockedHostSuffixes = setOf(
        // Google 广告与统计
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "google-analytics.com",
        "googletagmanager.com",
        "adservice.google.com",
        "adservice.google.cn",
        // 国内常用统计
        "hm.baidu.com",
        "pos.baidu.com",
        "cnzz.com",
        "umeng.com",
        "umeng.co",
        "growingio.com",
        "sensorsdata.cn",
        // 移动广告网络
        "appsflyer.com",
        "adcolony.com",
        "inmobi.com",
        "tapjoy.com",
        "mintegral.com",
        "vungle.com",
        "applovin.com",
        "mopub.com"
    )

    /// 判断 URL 是否命中黑名单：主机等于或以「.黑名单项」结尾才算命中，
    /// 避免相似前缀域名误伤（如 evil-doubleclick.net 不会命中 doubleclick.net）。
    fun shouldBlock(url: String): Boolean {
        val host = Uri.parse(url).host?.lowercase() ?: return false
        return blockedHostSuffixes.any { host == it || host.endsWith(".$it") }
    }

    /// 空响应：让 WebView 立即结束该请求而不是等待超时。
    fun emptyResponse(): WebResourceResponse =
        WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))
}
