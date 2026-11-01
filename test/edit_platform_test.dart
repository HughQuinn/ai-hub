import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_hub/pages/add_platform_page.dart';
import 'package:ai_hub/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  Future<void> pumpEditor(WidgetTester tester) async {
    await storage.init();
    // 表单含图标网格与分类卡片，放大视口让保存按钮完整可见
    tester.view.physicalSize = const Size(800, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<StorageService>.value(value: storage)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddPlatformPage(editName: 'MyAI'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('编辑模式预填既有数据并原位保存', (tester) async {
    SharedPreferences.setMockInitialValues({
      'custom_platforms': [
        '{"name":"MyAI","url":"https://old.example.com","description":"旧描述","iconName":"chat_bubble_outline","region":"domestic"}',
      ],
    });
    storage = StorageService();
    await pumpEditor(tester);

    // 预填校验
    expect(find.text('编辑自定义平台'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'MyAI'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'https://old.example.com'),
        findsOneWidget);

    // 修改 URL 并保存
    await tester.enterText(
      find.widgetWithText(TextField, 'https://old.example.com'),
      'https://new.example.com',
    );
    await tester.ensureVisible(find.text('保存修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pump(const Duration(milliseconds: 400));

    final platforms = await storage.getCustomPlatforms();
    expect(platforms.length, 1);
    expect(platforms.first['name'], 'MyAI');
    expect(platforms.first['url'], 'https://new.example.com');
  });

  testWidgets('与内置服务重名时阻止保存', (tester) async {
    SharedPreferences.setMockInitialValues({
      'custom_platforms': [
        '{"name":"MyAI","url":"https://old.example.com","description":"旧描述","iconName":"chat_bubble_outline","region":"domestic"}',
      ],
    });
    storage = StorageService();
    await pumpEditor(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'MyAI'),
      'Kimi',
    );
    await tester.ensureVisible(find.text('保存修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('该名称已存在'), findsOneWidget);
    final platforms = await storage.getCustomPlatforms();
    expect(platforms.first['url'], 'https://old.example.com');
  });

  testWidgets('名称未变时允许保存', (tester) async {
    SharedPreferences.setMockInitialValues({
      'custom_platforms': [
        '{"name":"MyAI","url":"https://old.example.com","description":"旧描述","iconName":"chat_bubble_outline","region":"domestic"}',
      ],
    });
    storage = StorageService();
    await pumpEditor(tester);

    // 名称保持 MyAI 不变，仅改描述
    await tester.enterText(
      find.widgetWithText(TextField, '旧描述'),
      '新描述',
    );
    await tester.ensureVisible(find.text('保存修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pump(const Duration(milliseconds: 400));

    final platforms = await storage.getCustomPlatforms();
    expect(platforms.first['name'], 'MyAI');
    expect(platforms.first['description'], '新描述');
  });
}
