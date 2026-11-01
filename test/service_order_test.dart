import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/models/ai_service.dart';
import 'package:ai_hub/utils/service_order_utils.dart';

AiService _service(String name) => AiService(
      name: name,
      url: 'https://example.com',
      description: '',
      region: 'domestic',
    );

void main() {
  group('ServiceOrderUtils.applyPinnedOrder', () {
    test('置顶服务排在最前，其余保持相对顺序', () {
      final services = [_service('A'), _service('B'), _service('C'), _service('D')];
      final result = ServiceOrderUtils.applyPinnedOrder(
        services,
        (s) => s.name,
        {'C'},
      );
      expect(result.map((s) => s.name), ['C', 'A', 'B', 'D']);
    });

    test('多个置顶服务按原列表相对顺序排列', () {
      final services = [_service('A'), _service('B'), _service('C'), _service('D')];
      final result = ServiceOrderUtils.applyPinnedOrder(
        services,
        (s) => s.name,
        {'D', 'B'},
      );
      expect(result.map((s) => s.name), ['B', 'D', 'A', 'C']);
    });

    test('无置顶时原样返回', () {
      final services = [_service('A'), _service('B')];
      final result = ServiceOrderUtils.applyPinnedOrder(
        services,
        (s) => s.name,
        {},
      );
      expect(result.map((s) => s.name), ['A', 'B']);
    });

    test('置顶集合中的未知名字被忽略', () {
      final services = [_service('A'), _service('B')];
      final result = ServiceOrderUtils.applyPinnedOrder(
        services,
        (s) => s.name,
        {'NotExist'},
      );
      expect(result.map((s) => s.name), ['A', 'B']);
    });

    test('不修改原列表', () {
      final services = [_service('A'), _service('B'), _service('C')];
      ServiceOrderUtils.applyPinnedOrder(services, (s) => s.name, {'C'});
      expect(services.map((s) => s.name), ['A', 'B', 'C']);
    });
  });

  group('ServiceOrderUtils.mostRecent', () {
    test('按最近打开时间降序排列', () {
      final services = [_service('A'), _service('B'), _service('C')];
      final result = ServiceOrderUtils.mostRecent(services, (s) => s.name,
          {'A': 100, 'B': 300, 'C': 200});
      expect(result.map((s) => s.name), ['B', 'C', 'A']);
    });

    test('limit 截断数量', () {
      final services = [_service('A'), _service('B'), _service('C')];
      final result = ServiceOrderUtils.mostRecent(services, (s) => s.name,
          {'A': 100, 'B': 300, 'C': 200}, limit: 2);
      expect(result.map((s) => s.name), ['B', 'C']);
    });

    test('从未打开的服务不参与', () {
      final services = [_service('A'), _service('B')];
      final result = ServiceOrderUtils.mostRecent(
          services, (s) => s.name, {'B': 100});
      expect(result.map((s) => s.name), ['B']);
    });

    test('空时间记录返回空列表', () {
      final services = [_service('A'), _service('B')];
      expect(ServiceOrderUtils.mostRecent(services, (s) => s.name, {}), isEmpty);
    });

    test('时间相同的按原顺序稳定排列', () {
      final services = [_service('A'), _service('B'), _service('C')];
      final result = ServiceOrderUtils.mostRecent(services, (s) => s.name,
          {'A': 100, 'B': 100, 'C': 100});
      expect(result.map((s) => s.name), ['A', 'B', 'C']);
    });
  });
}
