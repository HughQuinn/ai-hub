import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('相同版本返回 false', () {
      expect(UpdateService.isNewerVersion('1.3.0', '1.3.0'), isFalse);
    });

    test('远端版本更新时返回 true', () {
      expect(UpdateService.isNewerVersion('1.3.0', '1.4.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.0', '1.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.9.0', '2.0.0'), isTrue);
    });

    test('远端版本更旧时返回 false', () {
      expect(UpdateService.isNewerVersion('1.4.0', '1.3.0'), isFalse);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });

    test('按数值而非字典序比较', () {
      expect(UpdateService.isNewerVersion('1.10.0', '1.9.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.9.0', '1.10.0'), isTrue);
    });

    test('位数不足的部分按 0 处理', () {
      expect(UpdateService.isNewerVersion('1.2', '1.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.1', '1.2'), isFalse);
    });
  });

  group('UpdateService.shouldPrompt', () {
    test('未忽略任何版本时提示', () {
      expect(UpdateService.shouldPrompt('1.4.0', null), isTrue);
    });

    test('最新版本与忽略版本不同则提示', () {
      expect(UpdateService.shouldPrompt('1.4.0', '1.3.0'), isTrue);
      expect(UpdateService.shouldPrompt('1.5.0', '1.4.0'), isTrue);
    });

    test('最新版本即被忽略的版本时不提示', () {
      expect(UpdateService.shouldPrompt('1.4.0', '1.4.0'), isFalse);
    });

    test('最新版本为空时不提示', () {
      expect(UpdateService.shouldPrompt('', null), isFalse);
    });
  });
}
