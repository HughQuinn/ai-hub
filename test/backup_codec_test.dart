import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/utils/backup_codec.dart';

void main() {
  group('BackupCodec.encode/decode 往返', () {
    test('编码后解码能完整还原各字段', () {
      final json = BackupCodec.encode(
        customPlatforms: [
          {'name': '我的平台', 'url': 'https://example.com', 'region': 'domestic'},
        ],
        hiddenServices: ['豆包'],
        customOrder: ['DeepSeek', 'Kimi'],
        pinnedServices: ['Kimi'],
        askHistory: ['帮我写周报', '翻译成英文：'],
        language: 'zh-CN',
        themeMode: 'dark',
        exportedAt: DateTime.utc(2026, 11, 2),
      );

      final data = BackupCodec.decode(json);
      expect(BackupCodec.platformList(data), [
        {'name': '我的平台', 'url': 'https://example.com', 'region': 'domestic'},
      ]);
      expect(BackupCodec.stringList(data, 'hiddenServices'), ['豆包']);
      expect(BackupCodec.stringList(data, 'customOrder'), ['DeepSeek', 'Kimi']);
      expect(BackupCodec.stringList(data, 'pinnedServices'), ['Kimi']);
      expect(BackupCodec.stringList(data, 'askHistory'),
          ['帮我写周报', '翻译成英文：']);
      expect(data['language'], 'zh-CN');
      expect(data['themeMode'], 'dark');
    });

    test('导出 JSON 自带 app 与 schemaVersion 标识', () {
      final json = BackupCodec.encode(
        customPlatforms: const [],
        hiddenServices: const [],
        customOrder: const [],
        pinnedServices: const [],
        askHistory: const [],
        language: 'zh-CN',
      );
      expect(json, contains('"app":"ai_hub"'));
      expect(json, contains('"schemaVersion":1'));
    });
  });

  group('BackupCodec.decode 校验', () {
    test('非 JSON 文本被拒绝', () {
      expect(
        () => BackupCodec.decode('这不是 JSON'),
        throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', '不是有效的 JSON 文本')),
      );
    });

    test('非对象 JSON 被拒绝', () {
      expect(() => BackupCodec.decode('[1,2,3]'), throwsA(isA<FormatException>()));
    });

    test('其它应用的备份被拒绝', () {
      expect(
        () => BackupCodec.decode('{"app":"other_app","schemaVersion":1,"data":{}}'),
        throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', '不是 AiHub 的备份文件')),
      );
    });

    test('不支持的 schemaVersion 被拒绝', () {
      expect(
        () => BackupCodec.decode(
            '{"app":"ai_hub","schemaVersion":99,"data":{}}'),
        throwsA(isA<FormatException>().having(
          (e) => e.message, 'message', '备份版本不受支持，请先升级应用')),
      );
    });

    test('缺少 data 字段被拒绝', () {
      expect(
        () => BackupCodec.decode('{"app":"ai_hub","schemaVersion":1}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('字段类型不正确被拒绝', () {
      const head = '{"app":"ai_hub","schemaVersion":1,"data":';
      expect(
        () => BackupCodec.decode('$head{"hiddenServices":"Kimi"}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupCodec.decode('$head{"customPlatforms":["Kimi"]}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupCodec.decode(
            '$head{"customPlatforms":[{"name":"X"}]}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupCodec.decode('$head{"themeMode":1}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupCodec.decode('$head{"askHistory":1}}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupCodec.decode('$head{"language":42}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('缺失的可选字段按空处理', () {
      final data = BackupCodec.decode('{"app":"ai_hub","schemaVersion":1,"data":{}}');
      expect(BackupCodec.stringList(data, 'hiddenServices'), isEmpty);
      expect(BackupCodec.stringList(data, 'pinnedServices'), isEmpty);
      expect(BackupCodec.platformList(data), isEmpty);
    });
  });
}
