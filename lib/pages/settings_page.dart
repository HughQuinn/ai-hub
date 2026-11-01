import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai_hub/config/services_config.dart';
import 'package:ai_hub/models/ai_service.dart';
import 'package:ai_hub/services/app_info.dart';
import 'package:ai_hub/services/reachability_service.dart';
import 'package:ai_hub/services/storage_service.dart';
import 'package:ai_hub/services/update_service.dart';
import 'package:ai_hub/config/theme_config.dart';
import 'package:ai_hub/pages/add_platform_page.dart';
import 'package:ai_hub/pages/sort_hide_page.dart';
import 'package:ai_hub/providers/theme_provider.dart';
import 'package:ai_hub/utils/backup_codec.dart';
import 'package:ai_hub/widgets/update_dialog.dart';

class SettingsPage extends StatefulWidget {
  static const _channel = MethodChannel('com.aihub.webview');
  final VoidCallback? onRefreshHome;

  const SettingsPage({super.key, this.onRefreshHome});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentLanguage = 'zh-CN';
  bool _initialized = false;

  static const _languageNames = <String, String>{
    'zh-CN': '简体中文',
    'zh-TW': '繁体中文',
    'en': 'English',
  };

  // 使用 main.dart 注入的同一实例，裸 new 的 StorageService 未 init，读写会静默失效
  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _storageService.getLanguage().then((code) {
        if (mounted) setState(() => _currentLanguage = code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          String themeModeText;
          switch (themeProvider.themeMode) {
            case ThemeMode.dark:
              themeModeText = '深色';
              break;
            case ThemeMode.light:
              themeModeText = '浅色';
              break;
            case ThemeMode.system:
              themeModeText = '跟随系统';
              break;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- 常规 ----
                _sectionHeader('常规', secondaryColor),
                _buildGroup(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.language,
                      iconColor: Colors.blue,
                      title: '语言',
                      subtitle: _languageNames[_currentLanguage],
                      secondaryColor: secondaryColor,
                      onTap: () => _showLanguageDialog(context),
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.dark_mode,
                      iconColor: Colors.orange,
                      title: '深色模式',
                      subtitle: themeModeText,
                      secondaryColor: secondaryColor,
                      onTap: () => _showThemeDialog(context, themeProvider),
                    ),
                  ],
                ),

                // ---- 平台管理 ----
                _sectionHeader('平台管理', secondaryColor),
                _buildGroup(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.add_circle_outline,
                      iconColor: Colors.green,
                      title: '添加自定义平台',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddPlatformPage()),
                        );
                        widget.onRefreshHome?.call();
                      },
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.sort,
                      iconColor: Colors.blue,
                      title: '排序/隐藏平台',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SortHidePage()),
                        );
                        widget.onRefreshHome?.call();
                      },
                    ),
                  ],
                ),

                // ---- 数据 ----
                _sectionHeader('数据', secondaryColor),
                _buildGroup(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.upload_outlined,
                      iconColor: Colors.blue,
                      title: '导出配置',
                      subtitle: '复制配置 JSON 到剪贴板',
                      secondaryColor: secondaryColor,
                      onTap: _exportBackup,
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.download_outlined,
                      iconColor: Colors.purple,
                      title: '从剪贴板导入',
                      subtitle: '粘贴备份 JSON，校验后恢复',
                      secondaryColor: secondaryColor,
                      onTap: _importBackup,
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.network_check,
                      iconColor: Colors.teal,
                      title: '服务可达性检测',
                      subtitle: '手动检测各服务当前是否可访问',
                      secondaryColor: secondaryColor,
                      onTap: () => _showReachabilityDialog(context),
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.delete_outline,
                      iconColor: Colors.red,
                      title: '清除 WebView 缓存',
                      subtitle: '保留登录状态',
                      secondaryColor: secondaryColor,
                      onTap: () => _handleClearCache(context),
                    ),
                  ],
                ),

                // ---- 其他 ----
                _sectionHeader('其他', secondaryColor),
                _buildGroup(
                  isDark: isDark,
                  children: [
                    _buildTile(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.grey,
                      title: '通知设置',
                      subtitle: '即将支持',
                      showTrailing: false,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('通知设置功能即将支持'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _groupDivider(isDark),
                    _buildTile(
                      icon: Icons.info_outline,
                      iconColor: Colors.grey,
                      title: '关于/版本',
                      subtitle: 'v${AppInfo.version}',
                      secondaryColor: secondaryColor,
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGroup({required List<Widget> children, required bool isDark}) {
    // ListTile 的背景与水波纹绘制在最近的 Material 上，
    // 因此背景/边框必须由 Material 自身提供，不能用带背景色的 Container 包裹
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.cardBackground(isDark: isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _groupDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? secondaryColor,
    bool showTrailing = true,
    required VoidCallback onTap,
  }) {
    final effectiveSecondaryColor =
        secondaryColor ?? AppColors.secondaryText(isDark: Theme.of(context).brightness == Brightness.dark);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: effectiveSecondaryColor),
            )
          : null,
      trailing: showTrailing ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('深色模式'),
        content: RadioGroup<ThemeMode>(
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) themeProvider.setThemeMode(value);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<ThemeMode>(
                title: Text('深色'),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text('浅色'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('跟随系统'),
                value: ThemeMode.system,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    const available = {'zh-CN'};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择语言'),
        content: RadioGroup<String>(
          groupValue: _currentLanguage,
          onChanged: (value) async {
            if (value != null && available.contains(value)) {
              await _storageService.setLanguage(value);
              if (!ctx.mounted) return;
              setState(() => _currentLanguage = value);
            }
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('简体中文'),
                value: 'zh-CN',
              ),
              RadioListTile<String>(
                title: const Text('繁体中文'),
                value: 'zh-TW',
                enabled: false,
                subtitle: const Text('即将支持', style: TextStyle(fontSize: 12)),
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                enabled: false,
                subtitle: const Text('即将支持', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final ignored = await _storageService.getIgnoredUpdateVersion();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于 AiHub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 聚合服务平台'),
            const SizedBox(height: 8),
            Text('版本: v${AppInfo.version}'),
            if (ignored != null)
              Text(
                '已忽略更新提醒: v$ignored',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (ignored != null)
            TextButton(
              onPressed: () async {
                await _storageService.setIgnoredUpdateVersion(null);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复更新提醒')),
                );
              },
              child: const Text('恢复提醒'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final update =
                  await UpdateService().checkForUpdate(AppInfo.version);
              if (!mounted || !context.mounted) return;
              if (update == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('当前已是最新版本')),
                );
              } else {
                showUpdateDialog(context, update);
              }
            },
            child: const Text('检查更新'),
          ),
        ],
      ),
    );
  }

  // ---- 配置备份与恢复 ----

  /// 导出当前配置为备份 JSON 并复制到剪贴板。
  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final themeProvider = context.read<ThemeProvider>();

    final platforms = await _storageService.getCustomPlatforms();
    final hidden = await _storageService.getHiddenServices();
    final order = await _storageService.getCustomOrder();
    final pins = await _storageService.getPinnedServices();
    final language = await _storageService.getLanguage();

    final json = BackupCodec.encode(
      customPlatforms: platforms,
      hiddenServices: hidden,
      customOrder: order ?? const [],
      pinnedServices: pins,
      language: language,
      themeMode: themeProvider.themeModeKey,
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('配置已复制到剪贴板，妥善保存即可迁移到新设备')),
    );
  }

  /// 从剪贴板读取备份 JSON，校验通过后展示预览并确认导入。
  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final themeProvider = context.read<ThemeProvider>();
    final onRefreshHome = widget.onRefreshHome;

    final clip = await Clipboard.getData('text/plain');
    final raw = clip?.text?.trim() ?? '';
    if (raw.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('剪贴板为空，请先在其他设备上导出配置')),
      );
      return;
    }

    final Map<String, dynamic> data;
    try {
      data = BackupCodec.decode(raw);
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('导入失败：${e.message}')),
      );
      return;
    }
    if (!mounted) return;

    final platforms = BackupCodec.platformList(data);
    final hidden = BackupCodec.stringList(data, 'hiddenServices');
    final order = BackupCodec.stringList(data, 'customOrder');
    final pins = BackupCodec.stringList(data, 'pinnedServices');
    final language = data['language'] as String?;
    final themeKey = data['themeMode'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将应用以下配置：'),
            const SizedBox(height: 8),
            Text('自定义平台：${platforms.length} 个', style: const TextStyle(fontSize: 13)),
            Text('隐藏平台：${hidden.length} 项', style: const TextStyle(fontSize: 13)),
            Text('自定义排序：${order.isEmpty ? '未设置' : '${order.length} 项'}',
                style: const TextStyle(fontSize: 13)),
            Text('置顶服务：${pins.length} 个', style: const TextStyle(fontSize: 13)),
            if (language != null)
              Text('语言：$language', style: const TextStyle(fontSize: 13)),
            if (themeKey != null)
              Text('深色模式：$themeKey', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _storageService.saveCustomPlatforms(platforms);
    await _storageService.setHiddenServices(hidden);
    await _storageService.setCustomOrder(order);
    await _storageService.setPinnedServices(pins);
    if (language != null) {
      await _storageService.setLanguage(language);
    }
    if (themeKey != null) {
      themeProvider.setThemeModeFromKey(themeKey);
    }
    if (language != null && mounted) {
      setState(() => _currentLanguage = language);
    }
    onRefreshHome?.call();
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('导入成功')));
  }

  void _showReachabilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ReachabilityCheckDialog(),
    );
  }

  void _handleClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('将清除 WebView 缓存，登录状态不受影响'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await SettingsPage._channel.invokeMethod('clearWebCache');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('缓存已清除')),
                  );
                }
              } on PlatformException catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('清除失败，请稍后重试')),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 服务可达性检测对话框：并发探测内置 + 自定义服务，展示三档结果。
class _ReachabilityCheckDialog extends StatefulWidget {
  const _ReachabilityCheckDialog();

  @override
  State<_ReachabilityCheckDialog> createState() =>
      _ReachabilityCheckDialogState();
}

class _ReachabilityCheckDialogState extends State<_ReachabilityCheckDialog> {
  final ReachabilityService _reachabilityService = ReachabilityService();
  List<ReachabilityResult>? _results;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _results = null);
    final storage =
        Provider.of<StorageService>(context, listen: false);
    final customPlatforms = await storage.getCustomPlatforms();
    final customServices = customPlatforms.map((p) {
      return AiService(
        name: p['name'] as String,
        url: p['url'] as String,
        description: (p['description'] as String?) ?? '',
        region: (p['region'] as String?) ?? 'domestic',
        isCustom: true,
      );
    }).toList();

    final results =
        await _reachabilityService.checkAll([...aiServices, ...customServices]);
    if (!mounted) return;
    setState(() => _results = results);
  }

  String _statusText(ReachabilityStatus status) {
    switch (status) {
      case ReachabilityStatus.ok:
        return '正常';
      case ReachabilityStatus.restricted:
        return '访问受限';
      case ReachabilityStatus.unreachable:
        return '无法访问';
    }
  }

  Color _statusColor(ReachabilityStatus status) {
    switch (status) {
      case ReachabilityStatus.ok:
        return const Color(0xFF4CAF50);
      case ReachabilityStatus.restricted:
        return const Color(0xFFFF6B35);
      case ReachabilityStatus.unreachable:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);

    return AlertDialog(
      title: const Text('服务可达性检测'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: _results == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('正在检测，最长约 5 秒...',
                        style: TextStyle(fontSize: 13, color: secondaryColor)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _results!.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final result = _results![index];
                  final color = _statusColor(result.status);
                  final subtitle = result.status == ReachabilityStatus.restricted
                      ? '站点在线，但拦截了探测请求'
                      : result.detail ?? 'HTTP ${result.statusCode ?? '-'}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.service.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: secondaryColor),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _statusText(result.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _runCheck,
          child: const Text('重新检测'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
