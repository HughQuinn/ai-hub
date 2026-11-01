import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/config/services_config.dart';
import 'package:ai_hub/models/ai_service.dart';

void main() {
  group('AiService.buildAskUrl', () {
    const service = AiService(
      name: 'Kimi',
      url: 'https://kimi.moonshot.cn',
      description: '',
      region: 'domestic',
      askUrlTemplate: 'https://kimi.moonshot.cn/search?q={q}',
    );

    test('中文与空格正确编码，可无损解码', () {
      final url = service.buildAskUrl('帮我 写周报');
      expect(url, isNotNull);
      expect(url!.scheme, 'https');
      expect(url.host, 'kimi.moonshot.cn');
      expect(url.queryParameters['q'], '帮我 写周报');
    });

    test('特殊字符 & = 不会注入为新的查询参数', () {
      final url = service.buildAskUrl('a&b=c d');
      expect(url, isNotNull);
      expect(url!.queryParameters['q'], 'a&b=c d');
      expect(url.queryParameters.containsKey('b'), isFalse);
    });

    test('首尾空白被裁剪', () {
      final url = service.buildAskUrl('  你好  ');
      expect(url!.queryParameters['q'], '你好');
    });

    test('未配置模板时返回 null', () {
      const plain = AiService(
        name: 'X',
        url: 'https://x.com',
        description: '',
        region: 'domestic',
      );
      expect(plain.buildAskUrl('你好'), isNull);
    });

    test('空问题或纯空白返回 null', () {
      expect(service.buildAskUrl(''), isNull);
      expect(service.buildAskUrl('   '), isNull);
    });
  });

  group('内置服务 askUrlTemplate 配置完整性', () {
    test('至少 7 个服务配置了直达提问模板', () {
      final configured =
          aiServices.where((s) => s.askUrlTemplate != null).toList();
      expect(configured.length, greaterThanOrEqualTo(7));
    });

    test('所有模板均为 https 且含 {q} 占位符，可成功构建链接', () {
      for (final service in aiServices) {
        final template = service.askUrlTemplate;
        if (template == null) continue;
        expect(template.startsWith('https://'), isTrue,
            reason: '${service.name} 的模板应为 https');
        expect(template.contains('{q}'), isTrue,
            reason: '${service.name} 的模板应含 {q} 占位符');
        final url = service.buildAskUrl('test');
        expect(url, isNotNull, reason: '${service.name} 应能构建直达链接');
      }
    });
  });
}
