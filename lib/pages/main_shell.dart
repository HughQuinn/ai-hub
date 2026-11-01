import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

class MainShell extends StatefulWidget {
  final Map<String, dynamic>? initialUpdate;
  final VoidCallback? onClearUpdate;

  const MainShell({
    super.key,
    this.initialUpdate,
    this.onClearUpdate,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _homePageKey = GlobalKey<HomePageState>();
  bool _updateDialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowUpdateDialog();
  }

  /// 启动时检测到新版本则弹出更新提示（每次进入应用最多弹一次，
  /// 用户已忽略的版本不再提示；设置页的手动检查不受忽略影响）
  void _maybeShowUpdateDialog() {
    final update = widget.initialUpdate;
    if (update == null || _updateDialogShown) return;
    _updateDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ignored =
          await context.read<StorageService>().getIgnoredUpdateVersion();
      final latestVersion = update['latestVersion'] as String? ?? '';
      if (!mounted) return;
      if (!UpdateService.shouldPrompt(latestVersion, ignored)) return;
      showUpdateDialog(context, update).then((_) => widget.onClearUpdate?.call());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final pages = [
      HomePage(key: _homePageKey),
      const StatsPage(),
      SettingsPage(onRefreshHome: () => _homePageKey.currentState?.refreshServices()),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: AppColors.primaryText(isDark: isDark),
        unselectedItemColor: AppColors.secondaryText(isDark: isDark),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
