import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/week_utils.dart';

/// Service for managing click count storage using SharedPreferences.
class StorageService {
  SharedPreferences? _prefs;

  /// Initialize SharedPreferences. Must be called before using other methods.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the click count for a specific service in the current week.
  Future<int> getClickCount(String serviceName) async {
    final key = '${WeekUtils.getCurrentWeekKey()}_$serviceName';
    return _prefs?.getInt(key) ?? 0;
  }

  /// Increment the click count for a specific service.
  Future<void> incrementClick(String serviceName) async {
    final key = '${WeekUtils.getCurrentWeekKey()}_$serviceName';
    final currentCount = _prefs?.getInt(key) ?? 0;
    await _prefs?.setInt(key, currentCount + 1);
  }

  /// Get all click counts for the current week.
  Future<Map<String, int>> getAllClickCounts() async {
    final weekKey = WeekUtils.getCurrentWeekKey();
    final result = <String, int>{};

    if (_prefs != null) {
      for (final key in _prefs!.getKeys()) {
        if (key.startsWith('${weekKey}_')) {
          final serviceName = key.substring(weekKey.length + 1);
          result[serviceName] = _prefs!.getInt(key) ?? 0;
        }
      }
    }

    return result;
  }

  /// Clear all SharedPreferences data.
  Future<void> clearAllData() async {
    await _prefs?.clear();
  }

  /// Get the list of hidden service names.
  Future<List<String>> getHiddenServices() async {
    return _prefs?.getStringList('hidden_services') ?? [];
  }

  /// Set the list of hidden service names.
  Future<void> setHiddenServices(List<String> services) async {
    await _prefs?.setStringList('hidden_services', services);
  }

  /// Get custom order of service names (null if not set).
  Future<List<String>?> getCustomOrder() async {
    return _prefs?.getStringList('custom_order');
  }

  /// Set custom order of service names.
  Future<void> setCustomOrder(List<String> order) async {
    await _prefs?.setStringList('custom_order', order);
  }

  /// Get custom platforms list.
  Future<List<Map<String, dynamic>>> getCustomPlatforms() async {
    final jsonList = _prefs?.getStringList('custom_platforms') ?? [];
    return jsonList.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
  }

  /// Save custom platforms list.
  Future<void> saveCustomPlatforms(List<Map<String, dynamic>> platforms) async {
    final jsonList = platforms.map((p) => jsonEncode(p)).toList();
    await _prefs?.setStringList('custom_platforms', jsonList);
  }

  /// Get the selected language code. Default is "zh-CN".
  Future<String> getLanguage() async {
    return _prefs?.getString('language') ?? 'zh-CN';
  }

  /// Set the selected language code.
  Future<void> setLanguage(String languageCode) async {
    await _prefs?.setString('language', languageCode);
  }
}
