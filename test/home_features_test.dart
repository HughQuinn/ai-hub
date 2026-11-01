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
      version: '1.10.0',
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

  testWidgets('置顶后向原生同步桌面快捷方式（通道契约）', (tester) async {
    final shortcutCalls = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aihub.webview'),
      (call) async {
        if (call.method == 'updateShortcuts') {
          shortcutCalls.add(Map<String, dynamic>.from(call.arguments as Map));
          return null;
        }
        return call.method == 'checkAppInstalled' ? false : null;
      },
    );

    await pumpApp(tester);

    await tester.longPress(find.text('Kimi'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('置顶'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(shortcutCalls, isNotEmpty);
    final names = (shortcutCalls.last['shortcuts'] as List)
        .map((e) => (e as Map)['name'])
        .toList();
    expect(names, contains('Kimi'));
  });

  testWidgets('打开服务后切到统计 Tab 应显示最新使用记录', (tester) async {
    await pumpApp(tester);

    // 打开 Kimi（通道 mock 放行），产生本周点击
    await tester.tap(find.text('Kimi'));
    await tester.pump(const Duration(milliseconds: 300));

    // 切到统计 Tab：MainShell 会触发 StatsPage.refresh
    await tester.tap(find.text('统计'));
    await tester.pump(const Duration(milliseconds: 500));

    // 不应停留在空状态，且本周 Top 含 Kimi
    expect(find.textContaining('本周还没有使用记录'), findsNothing);
    expect(find.text('使用统计'), findsOneWidget);
    expect(find.text('Kimi'), findsWidgets);
  });

  testWidgets('设置页广告拦截开关与存储联动', (tester) async {
    // 数据分组在页面下方，放大视口使开关完整可见
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    await tester.tap(find.text('设置'));
    await tester.pump(const Duration(milliseconds: 500));

    final findSwitch = find.byType(Switch);
    expect(findSwitch, findsOneWidget);
    expect(tester.widget<Switch>(findSwitch).value, isTrue);

    await tester.tap(findSwitch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await storage.getAdBlockEnabled(), isFalse);
  });

  testWidgets('聚焦搜索框展示提问模板，提问后历史可回填', (tester) async {
    await pumpApp(tester);

    // 未聚焦时无提问历史行
    expect(find.text('帮我写周报'), findsNothing);

    // 聚焦搜索框 → 内置模板出现
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('帮我写周报'), findsOneWidget);

    // 输入问题 → 模板行让位于直达提问入口
    await tester.enterText(find.byType(TextField), '总结一下这段话');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('帮我写周报'), findsNothing);
    expect(find.text('问 Kimi'), findsOneWidget);

    // 提问 → 记录历史
    await tester.tap(find.text('问 Kimi'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await storage.getAskHistory(), contains('总结一下这段话'));

    // 清空输入重新聚焦 → 历史可回填
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('总结一下这段话'), findsOneWidget);

    // 点击历史芯片 → 回填搜索框并出现直达提问
    await tester.tap(find.text('总结一下这段话'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('问 Kimi'), findsOneWidget);
  });

  testWidgets('统计页 Top 点击直达对应服务', (tester) async {
    final openCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aihub.webview'),
      (call) async {
        if (call.method == 'openUrl') {
          openCalls.add(call.arguments['url'] as String);
          return null;
        }
        return call.method == 'checkAppInstalled' ? false : null;
      },
    );

    await pumpApp(tester);

    // 先打开 Kimi 产生本周记录，再切统计
    await tester.tap(find.text('Kimi'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('统计'));
    await tester.pump(const Duration(milliseconds: 500));
    openCalls.clear();

    // 点击 Top 行的 Kimi（.last 为统计页行，前面是 IndexedStack 中主页的卡片）
    await tester.tap(find.text('Kimi').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(openCalls, contains('https://kimi.moonshot.cn'));
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

  testWidgets('打开服务后出现在最近使用行，输入搜索词时隐藏', (tester) async {
    await pumpApp(tester);

    expect(find.byIcon(Icons.history), findsNothing);

    // 点击 Kimi 卡片（通道 mock 放行），最近使用行出现
    await tester.tap(find.text('Kimi'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.history), findsOneWidget);
    final lastOpened = await storage.getAllLastOpened();
    expect(lastOpened.keys, contains('Kimi'));

    // 输入搜索词后最近行让位于直达提问入口
    await tester.enterText(find.byType(TextField), '写周报');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.history), findsNothing);
    expect(find.text('问 Kimi'), findsOneWidget);
  });
}
