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
}
