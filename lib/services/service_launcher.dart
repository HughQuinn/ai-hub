import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ai_service.dart';
import 'storage_service.dart';

/// 打开服务的统一入口：点击计数、最近打开记录、
/// 客户端唤起（仅打开主页时）、通道打开与系统浏览器兜底。
/// 首页与统计页共用；调用方负责打开后的自身状态刷新（快捷方式同步等）。
class ServiceLauncher {
  static const _channel = MethodChannel('com.aihub.webview');

  static Future<void> open(
    BuildContext context, {
    required StorageService storage,
    required AiService service,
    String? urlOverride,
  }) async {
    // 在任何 await 之前捕获，避免跨异步间隙使用 context
    final messenger = ScaffoldMessenger.of(context);
    final targetUrl = urlOverride ?? service.url;

    await storage.incrementClick(service.name);
    await storage.setLastOpened(service.name);

    try {
      if (service.packageName != null && urlOverride == null) {
        // 直达提问链接只对网页端有意义，客户端唤起仅在打开主页时生效
        final installed = await _channel.invokeMethod('checkAppInstalled',
            {'packageName': service.packageName});
        if (installed == true) {
          try {
            await _channel.invokeMethod(
                'launchApp', {'packageName': service.packageName});
            return;
          } on PlatformException catch (e) {
            debugPrint('[AiHub] launchApp failed: ${e.message}');
          }
        }
      }
      await _channel.invokeMethod('openUrl', {'url': targetUrl});
    } on PlatformException catch (e) {
      debugPrint('[AiHub] MethodChannel failed: ${e.message}');
      await _openInExternalBrowser(messenger, targetUrl);
    } on MissingPluginException catch (e) {
      // 非 Android 环境（桌面端/无原生实现）没有通道，直接走系统浏览器
      debugPrint('[AiHub] MethodChannel unavailable: ${e.message}');
      await _openInExternalBrowser(messenger, targetUrl);
    }
  }

  static Future<void> _openInExternalBrowser(
    ScaffoldMessengerState messenger,
    String targetUrl,
  ) async {
    final uri = Uri.tryParse(targetUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('打开失败，请检查网络后重试')),
    );
  }
}
