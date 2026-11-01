/// 服务列表排序工具。
class ServiceOrderUtils {
  /// 将 [pinnedNames] 中的服务置顶，其余保持原有相对顺序。
  ///
  /// 置顶优先级高于点击排序与自定义排序，调用方在完成既有排序后
  /// 再调用本方法即可；[pinnedNames] 中不存在的名字会被忽略。
  static List<T> applyPinnedOrder<T>(
    List<T> items,
    String Function(T) nameOf,
    Set<String> pinnedNames,
  ) {
    if (pinnedNames.isEmpty) return items;
    final pinned = items.where((s) => pinnedNames.contains(nameOf(s)));
    final rest = items.where((s) => !pinnedNames.contains(nameOf(s)));
    return [...pinned, ...rest];
  }

  /// 按最近打开时间降序取前 [limit] 个；从未打开的服务不参与，
  /// 时间相同的按传入顺序稳定排列（List.sort 不保证稳定，用下标辅助）。
  static List<T> mostRecent<T>(
    List<T> items,
    String Function(T) nameOf,
    Map<String, int> lastOpenedMs, {
    int limit = 5,
  }) {
    final entries = <MapEntry<T, int>>[];
    for (final item in items) {
      final ts = lastOpenedMs[nameOf(item)];
      if (ts != null) entries.add(MapEntry(item, ts));
    }
    final indices = List<int>.generate(entries.length, (i) => i);
    indices.sort((a, b) {
      final byTime = entries[b].value.compareTo(entries[a].value);
      return byTime != 0 ? byTime : a.compareTo(b);
    });
    return indices.take(limit).map((i) => entries[i].key).toList();
  }
}
