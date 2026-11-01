import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_hub/services/storage_service.dart';
import 'package:ai_hub/utils/week_utils.dart';

void main() {
  late StorageService storage;

  group('StorageService 收藏置顶', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    test('默认无置顶，写入后可读回', () async {
      expect(await storage.getPinnedServices(), isEmpty);

      await storage.setPinnedServices(['Kimi', 'DeepSeek']);
      expect(await storage.getPinnedServices(), ['Kimi', 'DeepSeek']);

      await storage.setPinnedServices([]);
      expect(await storage.getPinnedServices(), isEmpty);
    });
  });

  group('StorageService 历史周数据', () {
    test('getWeeklyHistory 聚合多个周键并忽略非点击记录', () async {
      SharedPreferences.setMockInitialValues({
        'service_clicks_2026_W44_Kimi': 3,
        'service_clicks_2026_W44_DeepSeek': 1,
        'service_clicks_2026_W43_Kimi': 2,
        'service_clicks_2026_W43_my_bot': 5,
        'service_clicks_2025_W52_Kimi': 9,
        'theme_mode': 'dark',
        'hidden_services': <String>['X'],
      });
      storage = StorageService();
      await storage.init();

      final history = await storage.getWeeklyHistory();
      expect(history.keys.length, 3);
      expect(history['service_clicks_2026_W44'], {'Kimi': 3, 'DeepSeek': 1});
      expect(history['service_clicks_2026_W43'], {'Kimi': 2, 'my_bot': 5});
      expect(history['service_clicks_2025_W52'], {'Kimi': 9});
    });

    test('pruneHistory 只清理 keepWeeks 周之前的记录并返回条数', () async {
      final currentWeekKey = WeekUtils.getCurrentWeekKey();
      SharedPreferences.setMockInitialValues({
        '${currentWeekKey}_Kimi': 2, // 本周，保留
        'service_clicks_2020_W10_Kimi': 5, // 远古，清理
        'service_clicks_2020_W10_DeepSeek': 1, // 远古，清理
        'theme_mode': 'dark', // 非点击记录，不受影响
      });
      storage = StorageService();
      await storage.init();

      final removed = await storage.pruneHistory(keepWeeks: 12);
      expect(removed, 2);

      final history = await storage.getWeeklyHistory();
      expect(history.keys.toList(), [currentWeekKey]);
      expect(history[currentWeekKey], {'Kimi': 2});

      // 主题等其它存储不受清理影响
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('pruneHistory 无可清理数据时返回 0', () async {
      final currentWeekKey = WeekUtils.getCurrentWeekKey();
      SharedPreferences.setMockInitialValues({
        '${currentWeekKey}_Kimi': 2,
      });
      storage = StorageService();
      await storage.init();

      expect(await storage.pruneHistory(keepWeeks: 12), 0);
    });
  });
}
