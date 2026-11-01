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

  /// Get the list of pinned (置顶) service names.
  Future<List<String>> getPinnedServices() async {
    return _prefs?.getStringList('pinned_services') ?? [];
  }

  /// Set the list of pinned (置顶) service names.
  Future<void> setPinnedServices(List<String> services) async {
    await _prefs?.setStringList('pinned_services', services);
  }

  /// 读取全部历史周点击数据：{weekKey: {serviceName: count}}。
  /// 历史周键随时间自然累积，与 [getAllClickCounts]（仅本周）互补。
  Future<Map<String, Map<String, int>>> getWeeklyHistory() async {
    final result = <String, Map<String, int>>{};
    if (_prefs == null) return result;
    for (final key in _prefs!.getKeys()) {
      final parts = WeekUtils.splitClickStorageKey(key);
      if (parts == null) continue;
      final (weekKey, serviceName) = parts;
      (result[weekKey] ??= {})[serviceName] = _prefs!.getInt(key) ?? 0;
    }
    return result;
  }

  /// 删除 [keepWeeks] 周之前的历史点击记录，返回删除的记录条数。
  Future<int> pruneHistory({int keepWeeks = 12}) async {
    if (_prefs == null) return 0;
    final cutoff = WeekUtils.currentWeekMonday()
        .subtract(Duration(days: (keepWeeks - 1) * 7));
    var removed = 0;
    for (final key in _prefs!.getKeys().toList()) {
      final parts = WeekUtils.splitClickStorageKey(key);
      if (parts == null) continue;
      final (weekKey, _) = parts;
      final parsed = WeekUtils.parseWeekKey(weekKey);
      if (parsed == null) continue;
      final (year, week) = parsed;
      if (WeekUtils.weekMonday(year, week).isBefore(cutoff)) {
        await _prefs!.remove(key);
        removed++;
      }
    }
    return removed;
  }

  /// 记录服务最近一次打开时间（毫秒时间戳），键为 last_opened_{name}。
  Future<void> setLastOpened(String serviceName, {int? timestampMs}) async {
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt('last_opened_$serviceName', ts);
  }

  /// 读取全部最近打开时间：{serviceName: epochMs}，从未打开的服务不出现。
  Future<Map<String, int>> getAllLastOpened() async {
    const prefix = 'last_opened_';
    final result = <String, int>{};
    if (_prefs == null) return result;
    for (final key in _prefs!.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final ts = _prefs!.getInt(key);
      if (ts != null) result[key.substring(prefix.length)] = ts;
    }
    return result;
  }

  /// 用户选择忽略的更新版本号，null 表示未忽略任何版本。
  Future<String?> getIgnoredUpdateVersion() async {
    return _prefs?.getString('ignored_update_version');
  }

  /// 设置忽略的更新版本号，传 null 清除忽略。
  Future<void> setIgnoredUpdateVersion(String? version) async {
    if (version == null) {
      await _prefs?.remove('ignored_update_version');
    } else {
      await _prefs?.setString('ignored_update_version', version);
    }
  }
}
