import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/utils/ask_utils.dart';

void main() {
  group('AskUtils.push', () {
    test('新提问插入最前', () {
      expect(AskUtils.push(['B', 'C'], 'A'), ['A', 'B', 'C']);
    });

    test('重复提问去重并移到最前', () {
      expect(AskUtils.push(['B', 'A', 'C'], 'A'), ['A', 'B', 'C']);
    });

    test('首尾空白被裁剪后按裁剪值去重', () {
      expect(AskUtils.push(['B', 'A'], '  A  '), ['A', 'B']);
    });

    test('空白提问不记录', () {
      expect(AskUtils.push(['A'], '   '), ['A']);
      expect(AskUtils.push([], ''), isEmpty);
    });

    test('超过上限截断到 5 条', () {
      final history = AskUtils.push(['B', 'C', 'D', 'E', 'F'], 'A');
      expect(history, ['A', 'B', 'C', 'D', 'E']);
    });

    test('不修改原列表', () {
      final original = ['B'];
      AskUtils.push(original, 'A');
      expect(original, ['B']);
    });
  });

  group('AskUtils.chipsFor', () {
    test('历史在前，模板去重补位', () {
      final chips = AskUtils.chipsFor(['自定义问题']);
      expect(chips.first, '自定义问题');
      expect(chips.contains('帮我写周报'), isTrue);
      expect(chips, ['自定义问题', ...AskUtils.templates]);
    });

    test('历史中已有的模板不重复出现', () {
      final chips = AskUtils.chipsFor(['帮我写周报']);
      expect(chips.where((c) => c == '帮我写周报').length, 1);
    });

    test('空历史只展示模板', () {
      expect(AskUtils.chipsFor([]), AskUtils.templates);
    });
  });
}
