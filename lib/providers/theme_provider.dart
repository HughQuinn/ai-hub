import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider that persists theme mode to SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';
  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    _prefs = await SharedPreferences.getInstance();
    final value = _prefs?.getString(_key);
    if (value != null) {
      _themeMode = _themeModeFromString(value);
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs?.setString(_key, _themeModeToString(mode));
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setString(_key, _themeModeToString(_themeMode));
    notifyListeners();
  }

  /// 当前主题模式对应的持久化字符串（dark/light/system），供配置备份使用。
  String get themeModeKey => _themeModeToString(_themeMode);

  /// 从持久化字符串恢复主题模式，未知值回退为深色。
  void setThemeModeFromKey(String key) {
    setThemeMode(_themeModeFromString(key));
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}
