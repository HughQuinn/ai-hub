import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/models/ai_service.dart';
import 'package:ai_hub/services/reachability_service.dart';

void main() {
  group('ReachabilityService.classifyStatus', () {
    test('2xx/3xx 归类为正常', () {
      expect(ReachabilityService.classifyStatus(200), ReachabilityStatus.ok);
      expect(ReachabilityService.classifyStatus(204), ReachabilityStatus.ok);
      expect(ReachabilityService.classifyStatus(301), ReachabilityStatus.ok);
      expect(ReachabilityService.classifyStatus(302), ReachabilityStatus.ok);
      expect(ReachabilityService.classifyStatus(399), ReachabilityStatus.ok);
    });

    test('反爬/拦截类状态码归类为访问受限', () {
      expect(
          ReachabilityService.classifyStatus(401), ReachabilityStatus.restricted);
      expect(
          ReachabilityService.classifyStatus(403), ReachabilityStatus.restricted);
      expect(
          ReachabilityService.classifyStatus(405), ReachabilityStatus.restricted);
      expect(
          ReachabilityService.classifyStatus(429), ReachabilityStatus.restricted);
      expect(
          ReachabilityService.classifyStatus(451), ReachabilityStatus.restricted);
    });

    test('其余状态码归类为无法访问', () {
      expect(ReachabilityService.classifyStatus(404),
          ReachabilityStatus.unreachable);
      expect(ReachabilityService.classifyStatus(500),
          ReachabilityStatus.unreachable);
      expect(ReachabilityService.classifyStatus(502),
          ReachabilityStatus.unreachable);
    });
  });

  group('ReachabilityService.check', () {
    test('无效链接直接归类为无法访问且不发起网络请求', () async {
      const bad = AiService(
        name: 'Bad',
        url: 'not a url',
        description: '',
        region: 'domestic',
      );
      final result = await ReachabilityService().check(bad);
      expect(result.status, ReachabilityStatus.unreachable);
      expect(result.detail, '无效链接');
    });
  });
}
