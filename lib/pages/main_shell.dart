import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../widgets/update_dialog.dart';
import 'home_page.dart';
import 'settings_page.dart';

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

  /// 启动时检测到新版本则弹出更新提示（每次进入应用最多弹一次）
  void _maybeShowUpdateDialog() {
    final update = widget.initialUpdate;
    if (update == null || _updateDialogShown) return;
    _updateDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUpdateDialog(context, update)
          .then((_) => widget.onClearUpdate?.call());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final pages = [
      HomePage(key: _homePageKey),
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
