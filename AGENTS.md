# AGENTS.md - AI 助手开发规范

## 项目概述

**项目名称**: ai_hub
**技术栈**: Flutter + Dart（主框架）+ Android 原生 Kotlin（MethodChannel 桥接）
**项目类型**: AI 服务聚合启动器，内嵌 WebView 加载 AI 网页

## 目录结构规范

```
ai_hub/
├── android/                    # Android 原生代码
│   └── app/src/main/kotlin/com/example/ai_hub/
│       ├── MainActivity.kt     # 主 Activity + MethodChannel（openUrl/checkAppInstalled/launchApp/clearWebCache）
│       └── WebViewActivity.kt  # 内置 WebView 页面（进度条/错误重试页/Cookie 持久化）
├── lib/                        # Flutter 代码
│   ├── main.dart              # 入口文件
│   ├── app.dart               # App 配置（主题/启动时更新检查）
│   ├── config/                # 配置文件（services_config/icons_config/theme_config）
│   ├── models/                # 数据模型
│   ├── pages/                 # 页面（main_shell/home_page/stats_page/settings_page/add_platform_page/sort_hide_page）
│   ├── providers/             # 状态管理
│   ├── services/              # 服务层（storage_service/update_service/reachability_service/app_info）
│   ├── utils/                 # 工具类（week_utils/service_order_utils）
│   └── widgets/               # 组件（service_card/app_background/update_dialog）
└── test/                      # 测试文件
```

## 技术栈详细说明

### Flutter + Dart 层

| 技术 | 用途 | 使用场景 |
|------|------|----------|
| Flutter SDK | App 主框架 | 整体应用架构 |
| Dart | 编程语言 | 所有 Flutter 代码 |
| provider | 状态管理 | 主题状态、StorageService 注入 |
| url_launcher | 打开系统浏览器 | WebView 打开失败时的兜底、更新下载 |
| shared_preferences | 本地存储 | 点击频率、主题、平台配置 |
| package_info_plus | 读取应用版本 | 版本号唯一来源为 pubspec.yaml |
| flutter_svg | 渲染 SVG 图标 | 首页卡片图标 |
| Material Icons | 首页卡片图标 | UI 图标 |

### Android 原生 Kotlin 层

| 技术 | 用途 | 使用场景 |
|------|------|----------|
| WebView | 内嵌加载 AI 网页 | 核心功能 |
| WebViewClient | 链接接管 + 错误页 | 自定义 WebView 行为（广告拦截/JS 注入为规划功能，尚未实现） |
| CookieManager | 登录状态持久化 | onPause 时 flush 落盘 |
| PackageManager | 查询是否安装客户端 | 应用检测（需在 Manifest queries 声明包名） |
| Intent | 调起客户端 App / 外部浏览器 | 应用间通信 |
| MethodChannel | Flutter 与原生通信 | 跨平台通信 |

## 代码规范

### Dart 代码规范

```dart
// 1. 使用 snake_case 命名文件
// 例如: home_page.dart, user_model.dart

// 2. 使用 camelCase 命名变量和函数
String userName = '';
void getUserInfo() {}

// 3. 使用 PascalCase 命名类
class UserModel {}

// 4. 常量使用 camelCase 或 UPPER_SNAKE_CASE
const appVersion = '1.0.0';
const MAX_RETRY_COUNT = 3;

// 5. 导入顺序
// 1) Dart 核心库
// 2) Flutter 框架
// 3) 第三方包
// 4) 本项目文件
```

### Kotlin 代码规范

```kotlin
// 1. 使用 camelCase 命名变量和函数
var webView: WebView? = null
fun loadUrl(url: String) {}

// 2. 使用 PascalCase 命名类
class WebViewActivity : Activity

// 3. 使用 UPPER_SNAKE_CASE 命名常量
const val CHANNEL_NAME = "com.aihub.webview"

// 4. 包名使用全小写
package com.example.ai_hub
```

## MethodChannel 通信规范

### Channel 命名规则

```kotlin
// 格式: {域名}.{功能模块}（当前唯一通道如下）
const val CHANNEL_WEBVIEW = "com.aihub.webview"
// 已实现方法: openUrl / checkAppInstalled / launchApp / clearWebCache
```

### 通信数据格式

```dart
// Flutter 端调用
final result = await platform.invokeMethod('methodName', {
  'key1': value1,
  'key2': value2,
});

// Kotlin 端接收
override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "methodName" -> {
            val key1 = call.argument<String>("key1")
            val key2 = call.argument<Int>("key2")
            // 处理逻辑
            result.success(responseData)
        }
    }
}
```

### 错误处理

```dart
// Flutter 端
try {
  final result = await platform.invokeMethod('methodName');
} on PlatformException catch (e) {
  // 处理错误
  print('Error: ${e.message}');
}
```

```kotlin
// Kotlin 端
override fun onMethodCall(call: MethodCall, result: Result) {
    try {
        // 业务逻辑
        result.success(data)
    } catch (e: Exception) {
        result.error("ERROR_CODE", e.message, null)
    }
}
```

## WebView 开发规范

### 现有实现（MainActivity + WebViewActivity）

```kotlin
// Flutter 侧通过唯一通道调用原生能力
const channel = MethodChannel('com.aihub.webview');
// openUrl(url)            -> 明文 http 且 Android 9+ 时走外部浏览器，否则打开 WebViewActivity
// checkAppInstalled(pkg)  -> 查询客户端是否安装（需在 Manifest <queries> 中声明包名）
// launchApp(pkg)          -> 唤起已安装客户端
// clearWebCache()         -> 临时 WebView 实例清空缓存（保留 Cookie）
```

WebViewActivity 职责：页面加载进度条、加载失败错误页（跟随深浅色）、
返回键回退导航、onPause 时 `CookieManager.flush()` 持久化登录态。

### 广告拦截 / JS 注入（规划功能，尚未实现）

如后续需要，在 WebViewActivity 的 `WebViewClient` 中实现：
`shouldInterceptRequest` 按域名返回空响应拦截广告请求，
`onPageFinished` 中 `evaluateJavascript` 注入隐藏广告元素的脚本。

### Cookie 管理规范

```kotlin
// WebView 内的登录 Cookie 由系统自动维护，
// 关键是在 Activity 生命周期中主动落盘，防止进程被杀丢失：
override fun onPause() {
    CookieManager.getInstance().flush()
    super.onPause()
}
```

## 功能模块说明（v1.4.0 新增）

### 收藏置顶

- 长按首页卡片弹出操作面板：置顶/取消置顶、在浏览器打开、隐藏该平台
- 置顶优先级最高，叠加在周点击排序与自定义排序之上（`ServiceOrderUtils.applyPinnedOrder`）
- 星标徽章显示在卡片左上角；存储键 `pinned_services`
- 「隐藏」复用排序/隐藏页的 `hidden_services` 存储，两处入口互通

### 使用统计（底部第三个 Tab）

- 数据来源为已有的按周点击键 `service_clicks_{year}_W{week}_{serviceName}`，只读聚合，不改变计数逻辑
- 展示：本周 Top 服务条形图、近 12 周趋势柱状图、累计统计（累计打开/活跃周数/使用服务数）
- 历史数据治理：`StorageService.getWeeklyHistory()` 读取全部历史，`pruneHistory({keepWeeks = 12})`
  按 ISO 周一日期清理过期记录；统计页提供手动清理入口
- 周键解析/比较/周一推算等纯逻辑集中在 `WeekUtils`

### AI 直达提问

- 搜索框输入问题后，结果区上方出现「问 XX」入口行（覆盖全部可见服务，不随搜索结果过滤）
- `AiService.askUrlTemplate` 配置直达模板（`{q}` 占位符），已知支持的服务：Kimi/豆包/腾讯元宝/
  ChatGPT/Claude/Perplexity/Copilot/Grok
- 未配置模板的服务回退为「复制问题到剪贴板 + 打开主页」；提问与普通打开一样计入周点击统计
- 自定义平台暂无模板，自动走剪贴板回退

### 服务可达性检测（设置-数据）

- 手动触发，`ReachabilityService.checkAll` 并发 GET 探测（拿到状态码即断开，不下载响应体）
- 三档分类 `classifyStatus`：2xx/3xx 正常；401/403/405/429/451 访问受限（站点在线但拦截探测）；
  其余无法访问
- 纯 Dart `http` 实现，不自动轮询、不涉及原生层

## 测试规范

测试文件位于 `test/`，`update_service_test.dart`（纯函数单测）与
`widget_test.dart`（启动冒烟测试，mock SharedPreferences/PackageInfo/MethodChannel）。
v1.4.0 补充：`week_utils_test.dart`/`service_order_test.dart`/`ask_url_test.dart`/
`reachability_test.dart`/`storage_history_test.dart`（存储与纯函数）与
`home_features_test.dart`（置顶/统计页/直达提问的 widget 测试）。
注意：AppBackground 存在无限循环动画，widget 测试中不可使用 `pumpAndSettle`，
需用固定时长的 `tester.pump()`。

```dart
// 单元测试
// 文件位置: test/
// 命名: {功能}_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('远端版本更新时返回 true', () {
      expect(UpdateService.isNewerVersion('1.3.0', '1.4.0'), isTrue);
    });
  });
}
```

### Widget 测试

```dart
// 文件位置: test/
// 命名: widget_test.dart 或 {组件名}_test.dart
// 注意: mock 掉 SharedPreferences / PackageInfo / MethodChannel 后再 pumpWidget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_hub/models/ai_service.dart';
import 'package:ai_hub/widgets/service_card.dart';

void main() {
  testWidgets('ServiceCard displays name', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ServiceCard(
              service: AiService(
                name: 'Kimi',
                url: 'https://kimi.moonshot.cn',
                description: '擅长长文本处理',
                region: 'domestic',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Kimi'), findsOneWidget);
  });
}
```

## 常用命令

### Flutter 命令

```bash
# 获取依赖
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test

# 代码分析
flutter analyze

# 格式化代码
dart format .

# 构建 APK
flutter build apk

# 构建 App Bundle
flutter build appbundle
```

### Android 构建命令

```bash
# 在 android 目录下执行
./gradlew assembleDebug    # 调试版
./gradlew assembleRelease  # 发布版
./gradlew clean            # 清理
```

## 注意事项

### 1. 版本兼容性

- Flutter SDK: ^3.12.0
- Dart SDK: ^3.12.0
- Kotlin: 保持与项目 build.gradle 一致
- MinSdkVersion: 检查 android/app/build.gradle.kts

### 2. 权限管理

```xml
<!-- AndroidManifest.xml 中需要的权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 3. 性能优化

- WebView 使用硬件加速
- 避免在主线程执行耗时操作
- 合理使用缓存策略
- 及时释放 WebView 资源

### 4. 安全规范

- 不在代码中硬编码密钥
- 使用 HTTPS 协议
- 验证输入数据
- 防止 XSS 攻击

## 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

- **feat**: 新功能
- **fix**: 修复 bug
- **docs**: 文档更新
- **style**: 代码格式（不影响功能）
- **refactor**: 重构
- **test**: 测试相关
- **chore**: 构建/工具相关

### 示例

```
feat(webview): add ad interception feature

- Implement WebViewClient with ad pattern matching
- Add JavaScript injection for hiding ad elements
- Update MethodChannel communication

Closes #123
```

## 调试技巧

### Flutter 调试

```bash
# 启用 Flutter 调试
flutter run --debug

# 使用 DevTools
flutter pub global activate devtools
dart devtools
```

### Android 调试

```bash
# 查看 Logcat
adb logcat -s Flutter

# 查看 WebView 日志
adb logcat -s chromium
```

### MethodChannel 调试

```dart
// Flutter 端
print('Calling method: $method with args: $args');

// Kotlin 端
Log.d("WebViewPlugin", "Method called: ${call.method}")
```

## 文档维护

- 代码变更时同步更新 AGENTS.md
- 新增功能需补充使用说明
- 保持代码示例与实际代码一致
