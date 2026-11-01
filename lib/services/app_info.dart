import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本信息。
/// pubspec.yaml 的 version 字段是唯一来源，运行时通过 PackageInfo 读取，
/// 避免在代码里再维护一份硬编码版本号。
class AppInfo {
  AppInfo._();

  static String version = '0.0.0';

  /// 在 main() 中 runApp 之前调用一次。
  /// 读取失败（如测试环境无插件通道）时保持默认值。
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {
      // 保持默认值
    }
  }
}
