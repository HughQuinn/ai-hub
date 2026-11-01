/// Week utility class for ISO 8601 week number calculations.
class WeekUtils {
  /// 点击记录的存储键前缀，完整键格式为 `{weekKey}_{serviceName}`。
  static const String storageKeyPrefix = 'service_clicks_';

  /// 完整存储键匹配：`service_clicks_{year}_W{week}_{serviceName}`。
  /// 服务名允许包含下划线，因此年/周部分用正则锚定。
  static final RegExp _fullKeyPattern =
      RegExp(r'^service_clicks_(\d{4})_W(\d{1,2})_(.+)$');

  /// 周键匹配：`service_clicks_{year}_W{week}`。
  static final RegExp _weekKeyPattern =
      RegExp(r'^service_clicks_(\d{4})_W(\d{1,2})$');

  /// 拆分完整存储键为 (weekKey, serviceName)，不匹配时返回 null。
  static (String, String)? splitClickStorageKey(String key) {
    final match = _fullKeyPattern.firstMatch(key);
    if (match == null) return null;
    final weekKey = 'service_clicks_${match.group(1)}_W${match.group(2)}';
    return (weekKey, match.group(3)!);
  }

  /// 解析周键为 (year, week)，不匹配时返回 null。
  static (int, int)? parseWeekKey(String weekKey) {
    final match = _weekKeyPattern.firstMatch(weekKey);
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// 返回指定时刻所属的 ISO 周（周年份 + 周号）。
  ///
  /// 1 月初的日期可能属于上一 ISO 年的最后一周，例如 2027-01-01（周五）
  /// 属于 2026 年 W53；此前 getCurrentWeekKey 会把它错记为 2027_W53，
  /// 导致跨年边界处的计数键与历史清理推算错位。
  static (int, int) isoWeekYearWeek(DateTime now) {
    final year = now.year;
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    if (now.isBefore(week1Monday)) {
      final prevJan4 = DateTime(year - 1, 1, 4);
      final prevWeek1Monday =
          prevJan4.subtract(Duration(days: prevJan4.weekday - 1));
      return (year - 1, now.difference(prevWeek1Monday).inDays ~/ 7 + 1);
    }
    return (year, now.difference(week1Monday).inDays ~/ 7 + 1);
  }

  /// 返回指定 ISO 周所在年份中第 [week] 周的周一日期。
  static DateTime weekMonday(int year, int week) {
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    return week1Monday.add(Duration(days: (week - 1) * 7));
  }

  /// 返回当前 ISO 周的周一日期。
  static DateTime currentWeekMonday() {
    final (year, week) = isoWeekYearWeek(DateTime.now());
    return weekMonday(year, week);
  }

  /// 按时间先后比较两个周键（先比年份，再比周号）。
  static int compareWeekKeys(String a, String b) {
    final pa = parseWeekKey(a);
    final pb = parseWeekKey(b);
    if (pa == null || pb == null) return a.compareTo(b);
    final byYear = pa.$1.compareTo(pb.$1);
    if (byYear != 0) return byYear;
    return pa.$2.compareTo(pb.$2);
  }

  /// 返回包含指定周一那一周的周键，与 [weekMonday] 互逆。
  ///
  /// 同一个周一可能在相邻年份的周序列中都合法（如年末的第 53 周），
  /// 按「本周一所在年份优先、再向前一年」的顺序取首个合法结果，
  /// 与 [getCurrentWeekKey] 的记录口径保持一致。
  static String weekKeyForMonday(DateTime monday) {
    for (final year in [monday.year, monday.year - 1, monday.year + 1]) {
      final week = _weekNumberForMonday(monday, year);
      if (week != null) return 'service_clicks_${year}_W$week';
    }
    return 'service_clicks_${monday.year}_W1';
  }

  static int? _weekNumberForMonday(DateTime monday, int year) {
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final days = monday.difference(week1Monday).inDays;
    if (days < 0 || days % 7 != 0) return null;
    final week = days ~/ 7 + 1;
    return week <= 53 ? week : null;
  }

  /// Returns the current year.
  static int getCurrentYear() {
    return DateTime.now().year;
  }

  /// Returns the current ISO week number (1-53).
  static int getCurrentWeekNumber() {
    return isoWeekYearWeek(DateTime.now()).$2;
  }

  /// Returns the current week key in format "service_clicks_{year}_W{week}".
  /// 年份取 ISO 周年，1 月初的日期归入上一年的最后一周。
  static String getCurrentWeekKey() {
    final (year, week) = isoWeekYearWeek(DateTime.now());
    return 'service_clicks_${year}_W$week';
  }
}
