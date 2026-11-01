import 'dart:convert';

/// 配置备份编解码：导出为带版本号的 JSON 文本，导入时逐字段校验类型。
///
/// 备份只覆盖用户配置（自定义平台/隐藏/排序/置顶/语言/主题），
/// 不包含周点击统计等使用数据；编码格式通过 [schemaVersion] 演进。
class BackupCodec {
  BackupCodec._();

  /// 备份归属标识，导入时校验，防止粘贴其它应用的 JSON 误导入。
  static const String appId = 'ai_hub';

  /// 当前备份格式版本，不兼容的历史版本在导入时被拒绝。
  static const int schemaVersion = 1;

  /// 将存储层数据编码为备份 JSON。
  static String encode({
    required List<Map<String, dynamic>> customPlatforms,
    required List<String> hiddenServices,
    required List<String> customOrder,
    required List<String> pinnedServices,
    required List<String> askHistory,
    required String language,
    String? themeMode,
    DateTime? exportedAt,
  }) {
    return jsonEncode({
      'app': appId,
      'schemaVersion': schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'data': {
        'customPlatforms': customPlatforms,
        'hiddenServices': hiddenServices,
        'customOrder': customOrder,
        'pinnedServices': pinnedServices,
        'askHistory': askHistory,
        'language': language,
        'themeMode': ?themeMode,
      },
    });
  }

  /// 解析并校验备份 JSON，返回其中的 data 字段；不合法时抛出 FormatException。
  static Map<String, dynamic> decode(String raw) {
    Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException catch (_) {
      throw const FormatException('不是有效的 JSON 文本');
    }
    if (root is! Map<String, dynamic>) {
      throw const FormatException('备份格式不正确');
    }
    if (root['app'] != appId) {
      throw const FormatException('不是 AiHub 的备份文件');
    }
    if (root['schemaVersion'] != schemaVersion) {
      throw const FormatException('备份版本不受支持，请先升级应用');
    }
    final data = root['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('备份数据缺失');
    }
    _expectStringList(data, 'hiddenServices');
    _expectStringList(data, 'customOrder');
    _expectStringList(data, 'pinnedServices');
    _expectStringList(data, 'askHistory');
    _expectPlatformList(data);
    if (data.containsKey('language') && data['language'] is! String) {
      throw const FormatException('language 字段类型不正确');
    }
    if (data.containsKey('themeMode') && data['themeMode'] is! String) {
      throw const FormatException('themeMode 字段类型不正确');
    }
    return data;
  }

  /// 从已校验的 data 中取字符串列表，缺失字段按空列表处理。
  static List<String> stringList(Map<String, dynamic> data, String key) {
    return ((data[key] as List?) ?? const []).cast<String>();
  }

  /// 从已校验的 data 中取自定义平台列表，元素统一为 `Map<String, dynamic>`。
  static List<Map<String, dynamic>> platformList(Map<String, dynamic> data) {
    return ((data['customPlatforms'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  static void _expectStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return;
    // jsonDecode 产出的列表运行时类型是 List<dynamic>，需逐元素校验
    if (value is! List || value.any((e) => e is! String)) {
      throw FormatException('$key 字段应为字符串列表');
    }
  }

  static void _expectPlatformList(Map<String, dynamic> data) {
    final value = data['customPlatforms'];
    if (value == null) return;
    if (value is! List) {
      throw const FormatException('customPlatforms 字段应为列表');
    }
    for (final item in value) {
      if (item is! Map || item['name'] is! String || item['url'] is! String) {
        throw const FormatException('customPlatforms 元素缺少 name/url');
      }
    }
  }
}
