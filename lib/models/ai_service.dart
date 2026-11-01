import 'package:flutter/material.dart';
import '../config/icons_config.dart';

class AiService {
  final String name;
  final String url;
  final String description;
  final IconData? icon;       // 保留，兼容旧的 Material Icon 方式
  final String? iconPath;     // SVG 图标路径
  final String? packageName;
  final String region;        // "domestic" 或 "overseas"
  final bool needVpn;         // 是否需要梯子
  final bool isCustom;        // 是否为用户自定义服务
  final String? iconName;     // 自定义图标的名称
  final String? askUrlTemplate; // 直达提问链接模板，{q} 为提问占位符

  const AiService({
    required this.name,
    required this.url,
    required this.description,
    this.icon,
    this.iconPath,
    this.packageName,
    required this.region,
    this.needVpn = false,
    this.isCustom = false,
    this.iconName,
    this.askUrlTemplate,
  });

  IconData? get resolvedIcon {
    if (icon != null) return icon;
    if (iconName != null) {
      return presetIconMap[iconName];
    }
    return null;
  }

  /// 构建带提问内容的直达链接；未配置模板或问题为空时返回 null，
  /// 调用方应回退为「复制问题 + 打开主页」。
  Uri? buildAskUrl(String query) {
    final template = askUrlTemplate;
    if (template == null) return null;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final encoded = Uri.encodeQueryComponent(trimmed);
    return Uri.tryParse(template.replaceFirst('{q}', encoded));
  }
}
