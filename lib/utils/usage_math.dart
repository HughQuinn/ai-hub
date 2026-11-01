/// 使用统计相关的纯计算。
class UsageMath {
  /// 指定服务本周相对上周的点击差值（上周无记录按 0 计）。
  static int weekDelta(
    Map<String, int> currentWeek,
    Map<String, int> previousWeek,
    String serviceName,
  ) {
    return (currentWeek[serviceName] ?? 0) - (previousWeek[serviceName] ?? 0);
  }

  /// 差值的展示文案：正数带加号，零为持平。
  static String formatWeekDelta(int delta) {
    if (delta > 0) return '+$delta';
    if (delta < 0) return '$delta';
    return '持平';
  }
}
