import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_hub/app.dart';
import 'package:ai_hub/providers/theme_provider.dart';
import 'package:ai_hub/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'AI Hub',
      packageName: 'com.xuqiyi.aihub',
      version: '1.5.0',
      buildNumber: '2',
      buildSignature: '',
    );
    // WebView 通道：测试环境一律返回客户端未安装
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aihub.webview'),
      (call) async => call.method == 'checkAppInstalled' ? false : null,
    );
  });

  testWidgets('启动后展示服务卡片，可切换到设置页', (tester) async {
    final storage = StorageService();
    await storage.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<StorageService>.value(value: storage),
        ],
        child: const MyApp(),
      ),
    );
    // 跳过加载态并让入场动画/更新检查等定时器全部跑完
    // （背景为无限循环的 Ticker 动画，不能用 pumpAndSettle）
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 12));

    expect(find.text('AI Hub'), findsWidgets);
    expect(find.text('Kimi'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('平台管理'), findsOneWidget);
    expect(find.text('添加自定义平台'), findsOneWidget);
  });
}
