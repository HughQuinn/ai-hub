import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai_hub/app.dart';
import 'package:ai_hub/services/storage_service.dart';
import 'package:ai_hub/config/theme_config.dart';
import 'package:ai_hub/pages/add_platform_page.dart';
import 'package:ai_hub/pages/sort_hide_page.dart';
import 'package:ai_hub/providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  static const _channel = MethodChannel('com.aihub.webview');
  final VoidCallback? onRefreshHome;

  const SettingsPage({super.key, this.onRefreshHome});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentLanguage = 'zh-CN';

  static const _languageNames = <String, String>{
    'zh-CN': '简体中文',
    'zh-TW': '繁体中文',
    'en': 'English',
  };

  @override
  void initState() {
    super.initState();
    StorageService().getLanguage().then((code) {
      if (mounted) setState(() => _currentLanguage = code);
    });
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
                      subtitle: 'v$appVersion',
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark: isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
              await StorageService().setLanguage(value);
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

  void _showAboutDialog(BuildContext context) {
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
            Text('版本: v$appVersion'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // TODO: 检查更新
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('检查更新功能开发中')),
              );
            },
            child: const Text('检查更新'),
          ),
        ],
      ),
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
