import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/utils/usage_math.dart';

void main() {
  group('UsageMath.weekDelta', () {
    test('本周减上周', () {
      expect(UsageMath.weekDelta({'Kimi': 5}, {'Kimi': 3}, 'Kimi'), 2);
      expect(UsageMath.weekDelta({'Kimi': 3}, {'Kimi': 5}, 'Kimi'), -2);
    });

    test('上周无记录按 0 计', () {
      expect(UsageMath.weekDelta({'Kimi': 5}, {}, 'Kimi'), 5);
    });

    test('本周无记录为负差值', () {
      expect(UsageMath.weekDelta({}, {'Kimi': 4}, 'Kimi'), -4);
    });

    test('两边都无记录为 0', () {
      expect(UsageMath.weekDelta({}, {}, 'Kimi'), 0);
    });

    test('不受其它服务数据影响', () {
      expect(
        UsageMath.weekDelta({'Kimi': 5, '豆包': 9}, {'Kimi': 3, '豆包': 1},
            'Kimi'),
        2,
      );
    });
  });

  group('UsageMath.formatWeekDelta', () {
    test('正数带加号', () {
      expect(UsageMath.formatWeekDelta(3), '+3');
    });

    test('负数原样带符号', () {
      expect(UsageMath.formatWeekDelta(-2), '-2');
    });

    test('零为持平', () {
      expect(UsageMath.formatWeekDelta(0), '持平');
    });
  });
}
