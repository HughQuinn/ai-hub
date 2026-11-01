import 'package:flutter/material.dart';
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

  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'AI Hub',
      packageName: 'com.xuqiyi.aihub',
      version: '1.4.0',
      buildNumber: '2',
      buildSignature: '',
    );
    // WebView 通道：测试环境一律返回客户端未安装
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aihub.webview'),
      (call) async => call.method == 'checkAppInstalled' ? false : null,
    );
    storage = StorageService();
  });

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  testWidgets('长按服务卡片弹出操作面板，可置顶并显示星标', (tester) async {
    await pumpApp(tester);

    await tester.longPress(find.text('Kimi'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('在浏览器打开'), findsOneWidget);
    expect(find.text('隐藏该平台'), findsOneWidget);

    await tester.tap(find.text('置顶'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(await storage.getPinnedServices(), contains('Kimi'));
  });

  testWidgets('统计页展示空状态，切回主页不受影响', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('统计'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('使用统计'), findsOneWidget);
    expect(find.textContaining('本周还没有使用记录'), findsOneWidget);

    await tester.tap(find.text('主页'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI Hub'), findsOneWidget);
    expect(find.text('Kimi'), findsOneWidget);
  });

  testWidgets('搜索词非空时出现 AI 直达提问入口', (tester) async {
    await pumpApp(tester);

    expect(find.text('问 Kimi'), findsNothing);

    await tester.enterText(find.byType(TextField), '帮我写周报');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('问 Kimi'), findsOneWidget);
    expect(find.text('问 豆包'), findsOneWidget);
    expect(find.text('问 DeepSeek'), findsOneWidget);
  });
}
