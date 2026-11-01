import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/utils/week_utils.dart';

void main() {
  group('WeekUtils.splitClickStorageKey', () {
    test('拆分标准周键 + 服务名', () {
      expect(
        WeekUtils.splitClickStorageKey('service_clicks_2026_W44_Kimi'),
        ('service_clicks_2026_W44', 'Kimi'),
      );
    });

    test('服务名包含下划线时仍正确拆分', () {
      expect(
        WeekUtils.splitClickStorageKey('service_clicks_2026_W4_my_ai_bot'),
        ('service_clicks_2026_W4', 'my_ai_bot'),
      );
    });

    test('非点击记录键返回 null', () {
      expect(WeekUtils.splitClickStorageKey('theme_mode'), isNull);
      expect(WeekUtils.splitClickStorageKey('hidden_services'), isNull);
      expect(WeekUtils.splitClickStorageKey('service_clicks_bad'), isNull);
    });
  });

  group('WeekUtils.parseWeekKey', () {
    test('解析年份与周号', () {
      expect(WeekUtils.parseWeekKey('service_clicks_2026_W44'), (2026, 44));
      expect(WeekUtils.parseWeekKey('service_clicks_2026_W4'), (2026, 4));
    });

    test('非法周键返回 null', () {
      expect(WeekUtils.parseWeekKey('service_clicks_2026_X44'), isNull);
      expect(WeekUtils.parseWeekKey('pinned_services'), isNull);
    });
  });

  group('WeekUtils.weekMonday', () {
    test('2026 年第 1 周的周一为 2025-12-29（ISO 8601）', () {
      expect(WeekUtils.weekMonday(2026, 1), DateTime(2025, 12, 29));
    });

    test('2026 年第 45 周的周一为 2026-11-02', () {
      expect(WeekUtils.weekMonday(2026, 45), DateTime(2026, 11, 2));
    });

    test('当前周键与当前周一互相自洽', () {
      final key = WeekUtils.getCurrentWeekKey();
      final parsed = WeekUtils.parseWeekKey(key)!;
      final monday = WeekUtils.weekMonday(parsed.$1, parsed.$2);
      expect(monday.weekday, DateTime.monday);
      // 当前周一与今天相差不超过 6 天
      final diff = DateTime.now().difference(monday).inDays;
      expect(diff, inInclusiveRange(0, 6));
    });
  });

  group('WeekUtils.compareWeekKeys', () {
    test('跨年与多位周号均按时间排序', () {
      final keys = [
        'service_clicks_2026_W10',
        'service_clicks_2025_W52',
        'service_clicks_2026_W2',
        'service_clicks_2026_W1',
      ]..sort(WeekUtils.compareWeekKeys);
      expect(keys, [
        'service_clicks_2025_W52',
        'service_clicks_2026_W1',
        'service_clicks_2026_W2',
        'service_clicks_2026_W10',
      ]);
    });

    test('相同周键比较为 0', () {
      expect(
        WeekUtils.compareWeekKeys(
            'service_clicks_2026_W44', 'service_clicks_2026_W44'),
        0,
      );
    });
  });
}
