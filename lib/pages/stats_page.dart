import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../services/storage_service.dart';
import '../utils/usage_math.dart';
import '../utils/week_utils.dart';
import '../widgets/app_background.dart';

/// 使用统计页：基于按周落盘的点击数据展示本周 Top、近 12 周趋势与累计统计。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const _keepWeeks = 12;

  bool _isLoading = true;
  // weekKey -> {serviceName: count}
  Map<String, Map<String, int>> _history = {};

  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await _storageService.getWeeklyHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  /// 近 [keepWeeks] 周（含本周）的周键，按时间升序。
  List<String> get _recentWeeks {
    final current = WeekUtils.getCurrentWeekKey();
    final sorted = _history.keys.toList()
      ..sort(WeekUtils.compareWeekKeys);
    final index = sorted.indexOf(current);
    if (index < 0) return sorted;
    return sorted.sublist((index - _keepWeeks + 1).clamp(0, sorted.length));
  }

  int _totalForWeek(String weekKey) {
    final counts = _history[weekKey];
    if (counts == null) return 0;
    return counts.values.fold(0, (sum, c) => sum + c);
  }

  int get _grandTotal =>
      _history.values.fold(0, (sum, week) => sum + week.values.fold(0, (s, c) => s + c));

  /// 本周点击排行（降序）。
  List<MapEntry<String, int>> get _todayRanking {
    final current = WeekUtils.getCurrentWeekKey();
    final counts = _history[current] ?? const {};
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  bool get _hasData => _grandTotal > 0;

  Future<void> _pruneHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理历史数据'),
        content: const Text('将删除 $_keepWeeks 周之前的使用记录，本周数据不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await _storageService.pruneHistory(keepWeeks: _keepWeeks);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(removed > 0 ? '已清理 $removed 条历史记录' : '没有需要清理的历史记录')),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '使用统计',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: AppBackground(isDark: isDark)),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!_hasData)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.query_stats,
                    size: 64,
                    color: secondaryColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本周还没有使用记录\n去首页打开一个 AI 服务吧',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryColor, fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildTodaySection(isDark),
                const SizedBox(height: 16),
                _buildTrendSection(isDark),
                const SizedBox(height: 16),
                _buildSummarySection(isDark),
                const SizedBox(height: 16),
                _buildPruneTile(isDark, secondaryColor),
              ],
            ),
        ],
      ),
    );
  }

  // ---- 本周 Top ----

  Widget _buildTodaySection(bool isDark) {
    final ranking = _todayRanking;
    final maxCount = ranking.isEmpty ? 1 : ranking.first.value;
    // 上一个自然周的记录（该周无任何记录时不展示环比）
    final prevKey = WeekUtils.weekKeyForMonday(
        WeekUtils.currentWeekMonday().subtract(const Duration(days: 7)));
    final prevCounts = _history[prevKey];
    final currentCounts = <String, int>{
      for (final e in ranking) e.key: e.value,
    };

    return _buildSectionCard(
      isDark: isDark,
      title: '本周 Top',
      icon: Icons.leaderboard_outlined,
      child: Column(
        children: [
          for (final entry in ranking.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRankRow(
                entry.key,
                entry.value,
                maxCount,
                isDark,
                prevCounts == null
                    ? null
                    : UsageMath.weekDelta(currentCounts, prevCounts, entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankRow(
    String name,
    int count,
    int maxCount,
    bool isDark,
    int? delta,
  ) {
    final fraction = count / maxCount;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x1A3B82F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            name.characters.first,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText(isDark: isDark),
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: AppColors.searchBorder(isDark: isDark),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$count 次',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryText(isDark: isDark),
              ),
            ),
            if (delta != null)
              Text(
                UsageMath.formatWeekDelta(delta),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: delta > 0
                      ? const Color(0xFF4CAF50)
                      : delta < 0
                          ? const Color(0xFFE57373)
                          : AppColors.secondaryText(isDark: isDark),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- 近 12 周趋势 ----

  Widget _buildTrendSection(bool isDark) {
    final weeks = _recentWeeks;
    final totals = weeks.map(_totalForWeek).toList();
    final maxTotal = totals.fold(1, (m, t) => t > m ? t : m);
    final currentWeekKey = WeekUtils.getCurrentWeekKey();

    return _buildSectionCard(
      isDark: isDark,
      title: '近 12 周趋势',
      icon: Icons.show_chart,
      child: weeks.isEmpty
          ? Text(
              '暂无历史数据',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText(isDark: isDark)),
            )
          : SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < weeks.length; i++)
                    Expanded(
                      child: _buildTrendBar(
                        weekKey: weeks[i],
                        total: totals[i],
                        maxTotal: maxTotal,
                        isCurrent: weeks[i] == currentWeekKey,
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTrendBar({
    required String weekKey,
    required int total,
    required int maxTotal,
    required bool isCurrent,
    required bool isDark,
  }) {
    final parsed = WeekUtils.parseWeekKey(weekKey);
    final label = 'W${parsed?.$2 ?? '?'}';
    final barColor = isCurrent ? const Color(0xFF3B82F6) : const Color(0x803B82F6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            total > 0 ? '$total' : '',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.secondaryText(isDark: isDark),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: (total > 0 ? 68 * total / maxTotal : 2).toDouble(),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCurrent ? '本周' : label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: AppColors.secondaryText(isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 累计统计 ----

  Widget _buildSummarySection(bool isDark) {
    final activeWeeks =
        _history.values.where((week) => week.values.any((c) => c > 0)).length;
    final recordedServices =
        _history.values.fold<Set<String>>({}, (set, week) => set..addAll(week.keys)).length;

    final items = [
      ('累计打开', '$_grandTotal 次'),
      ('活跃周数', '$activeWeeks 周'),
      ('使用服务', '$recordedServices 个'),
    ];

    return _buildSectionCard(
      isDark: isDark,
      title: '累计统计',
      icon: Icons.functions_outlined,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.searchBackground(isDark: isDark),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText(isDark: isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText(isDark: isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPruneTile(bool isDark, Color secondaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
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
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.cleaning_services_outlined, color: Colors.red),
          title: const Text('清理历史数据'),
          subtitle: Text('删除 $_keepWeeks 周前的记录', style: TextStyle(fontSize: 12, color: secondaryColor)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pruneHistory,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark: isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondaryText(isDark: isDark)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText(isDark: isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
