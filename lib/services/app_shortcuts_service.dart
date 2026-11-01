import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ai_service.dart';

/// 应用图标长按快捷方式：把置顶与最近使用的服务同步为动态 shortcuts，
/// 从桌面长按图标即可直达对应服务（显式意图经 MainActivity 转交内置 WebView）。
class AppShortcutsService {
  static const _channel = MethodChannel('com.aihub.webview');

  /// 主流启动器可展示的快捷方式数量上限差异较大，取保守值。
  static const int maxShortcuts = 4;

  /// 用 [services]（已按优先级排序）整体替换动态快捷方式。
  /// 空列表即清空；通道不可用（非 Android 平台/旧版本）时静默跳过。
  static Future<void> update(List<AiService> services) async {
    final items = services.take(maxShortcuts).map((s) => {
          'id': 'service_${s.name}',
          'name': s.name,
          'url': s.url,
        }).toList();
    try {
      await _channel.invokeMethod('updateShortcuts', {'shortcuts': items});
    } on PlatformException catch (e) {
      debugPrint('[AiHub] updateShortcuts failed: ${e.message}');
    } on MissingPluginException {
      // 非 Android 平台无原生实现
    }
  }
}
