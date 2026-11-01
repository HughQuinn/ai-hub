/// AI 直达提问的提问历史与快捷模板。
class AskUtils {
  AskUtils._();

  /// 提问历史上限。
  static const int maxHistory = 5;

  /// 内置快捷提问模板，作为 ask_templates 未初始化时的默认值；
  /// 用户可在提问模板管理页增删改排。
  static const List<String> templates = [
    '帮我写周报',
    '翻译成英文：',
    '总结这段话：',
    '解释这段代码：',
    '润色这段文字：',
    '头脑风暴：',
  ];

  /// 把一次提问压入历史：去重后移到最前，超出 [maxHistory] 截断。
  /// 空白提问不记录，且不修改原列表。
  static List<String> push(List<String> history, String query) {
    final q = query.trim();
    if (q.isEmpty) return history;
    return [q, ...history.where((e) => e != q)].take(maxHistory).toList();
  }

  /// 历史与模板合并为展示用芯片文本：历史在前，模板去重补位。
  static List<String> chipsFor(List<String> history, List<String> templates) {
    final result = [...history];
    for (final t in templates) {
      if (!result.contains(t)) result.add(t);
    }
    return result;
  }
}
