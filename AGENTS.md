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
│       ├── MainActivity.kt     # 主 Activity + MethodChannel（openUrl/checkAppInstalled/launchApp/clearWebCache/updateShortcuts）+ 快捷方式意图
│       ├── WebViewActivity.kt  # 内置 WebView 页面（进度条/错误重试页/Cookie 持久化/广告拦截）
│       └── AdBlocker.kt        # WebView 广告/追踪域名黑名单匹配
├── lib/                        # Flutter 代码
│   ├── main.dart              # 入口文件
│   ├── app.dart               # App 配置（主题/启动时更新检查）
│   ├── config/                # 配置文件（services_config/icons_config/theme_config）
│   ├── models/                # 数据模型
│   ├── pages/                 # 页面（main_shell/home_page/stats_page/settings_page/add_platform_page/sort_hide_page）
│   ├── providers/             # 状态管理
│   ├── services/              # 服务层（storage_service/update_service/reachability_service/app_info）
│   ├── utils/                 # 工具类（week_utils/service_order_utils/backup_codec）
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
| WebViewClient | 链接接管 + 错误页 + 请求拦截 | 自定义 WebView 行为（广告拦截已实现，见 AdBlocker.kt） |
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
// 已实现方法: openUrl / checkAppInstalled / launchApp / clearWebCache / updateShortcuts
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

### 广告拦截（v1.8.0 已实现）

- `AdBlocker.kt` 维护保守的广告/统计域名黑名单，`WebViewClient.shouldInterceptRequest`
  按主机后缀精确匹配（`host == 项` 或 `host.endsWith(".项")`），命中返回空
  `WebResourceResponse`；不包含 CDN 与第三方登录域名，避免误伤站点功能
- 设计取舍：仅做请求级拦截，不做 DOM/JS 注入隐藏元素——后者需逐站点维护选择器且易误伤
- 开关存于 `ad_block_enabled`（默认开启），设置页「广告拦截」可切换；原生
  WebViewActivity 直接读取 Flutter SharedPreferences 的 `flutter.ad_block_enabled` 键，
  两侧键名需保持一致；开关变更对已打开页面在下次加载时生效

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

## 功能模块说明（v1.5.0 新增）

### 配置备份与恢复（设置-数据）

- 「导出配置」将自定义平台/隐藏/排序/置顶/语言/主题编码为带 `schemaVersion` 的 JSON 复制到剪贴板
  （此前 path_provider 已被移除，剪贴板方案保持零依赖）；「从剪贴板导入」读取、校验、
  弹窗预览条目数后确认写入
- 编解码与校验全部在纯函数 `BackupCodec` 中：app 标识不符、版本不支持、字段类型错误均拒绝导入，
  缺失字段按空处理；不备份周点击统计等使用数据
- 主题字符串互转使用 `ThemeProvider.themeModeKey` / `setThemeModeFromKey`

### 最近使用（首页）

- 打开服务时写入 `last_opened_{name}` 毫秒时间戳；首页在搜索词为空时显示「最近:」行
  （`ServiceOrderUtils.mostRecent` 稳定降序取前 5 个，从未打开的不参与），输入搜索词时让位于直达提问入口

### 长按菜单补充「复制链接」

- 与置顶/浏览器打开/隐藏并列，复制 `service.url` 到剪贴板，不影响点击统计

## 功能模块说明（v1.6.0 新增）

### 编辑自定义平台

- 排序/隐藏页的自定义平台行新增编辑按钮，进入 `AddPlatformPage(editName:)` 编辑模式：
  预填名称/URL/描述/图标/分类，保存时原位替换（保持用户排序位置）
- 重名校验在编辑模式下放行自身原名；重命名后旧的点击计数/置顶记录不迁移（与新增平台语义一致）

### 统计周环比

- 本周 Top 每行显示较上一自然周的差值（`UsageMath.weekDelta`/`formatWeekDelta`）：
  绿色 +N / 红色 -N / 持平
- 上一周键由 `WeekUtils.weekKeyForMonday`（与 weekMonday 互逆，含 53 周跨年边界）从
  上周一日期反推；上周无任何记录时不展示环比

### 更新提醒「忽略此版本」

- 更新弹窗新增「忽略此版本」，写入 `ignored_update_version`；启动自动检查经
  `UpdateService.shouldPrompt` 过滤已忽略版本；设置-关于显示忽略状态并可「恢复提醒」
- 手动「检查更新」不受忽略影响，保证用户主动操作总有结果

## 功能模块说明（v1.7.0 新增）

### 桌面长按快捷方式

- 首页把「置顶服务优先 + 最近使用补足」（上限 4 个）经 `AppShortcutsService.update`
  通过 `updateShortcuts` 通道同步为 Android 动态快捷方式；触发时机：应用启动、置顶变更、
  打开服务
- 原生（MainActivity）用 `ShortcutManagerCompat.setDynamicShortcuts` 整体替换，低版本自动 no-op；
  快捷方式以显式意图（extra `shortcut_url`）打开 MainActivity（singleTop），
  `onCreate/onNewIntent` 转交 `WebViewActivity` 直达对应服务
- 通道契约有 widget 测试覆盖（置顶后应推送含该服务的 shortcuts 列表）

### 缺陷修复

- **周键跨年边界**：1 月初的日期此前被记为「当前年份 + 上一年周号」（如 2027-01-01 →
  `2027_W53`），现统一由 `WeekUtils.isoWeekYearWeek` 给出 ISO 周年口径（→ `2026_W53`），
  `getCurrentWeekKey` / `currentWeekMonday` / 历史清理随之修正
- **自定义平台 URL 校验**：`http://` 这类缺少主机名的地址此前可保存，现校验
  `Uri.tryParse` 主机非空

## 功能模块说明（v1.9.0 新增）

### 提问历史与快捷模板

- 直达提问工作流增强：搜索框聚焦且无输入时显示「提问:」行——提问历史（最近 5 条，
  去重置顶）在前、内置模板（AskUtils.templates）补位；点击回填搜索框继续编辑，
  有历史时行尾提供「清空」；未聚焦时该行让位于「最近使用」行，输入非空时让位于直达提问行
- 触发提问（问 XX）时经 `AskUtils.push` 记录历史并持久化到 `ask_history`
- 卡片堆叠视图补齐与网格一致的徽章：客户端状态点/地球图标、自定义平台徽章

## 功能模块说明（v1.10.0 新增）

### 统计页 Top 点击直达与统一服务入口

- 新增 `ServiceLauncher.open`：点击计数、最近打开记录、客户端唤起（仅主页）、
  通道打开与系统浏览器兜底的统一实现；首页与统计页共用
- 修复潜在缺陷：原实现只捕获 `PlatformException`，在无原生实现的环境
  （如 Windows 桌面构建）会抛出未捕获的 `MissingPluginException`，
  现统一兜底走系统浏览器
- 统计页本周 Top 行可点击直达对应服务（含自定义平台；已删除的平台仅展示不可点，
  行尾以 chevron 图标提示可点），打开后自动刷新统计
- 卡片堆叠视图打开按钮左侧显示「本周 N 次」点击徽章
- 配置备份纳入提问历史（ask_history），导入预览显示条数

## 测试规范

测试文件位于 `test/`，`update_service_test.dart`（纯函数单测）与
`widget_test.dart`（启动冒烟测试，mock SharedPreferences/PackageInfo/MethodChannel）。
v1.4.0 补充：`week_utils_test.dart`/`service_order_test.dart`/`ask_url_test.dart`/
`reachability_test.dart`/`storage_history_test.dart`（存储与纯函数）与
`home_features_test.dart`（置顶/统计页/直达提问的 widget 测试）。
v1.5.0 补充：`backup_codec_test.dart`（备份编解码与校验），
并在 `service_order_test.dart`/`storage_history_test.dart`/`home_features_test.dart`
中补充最近使用的用例。v1.6.0 补充：`usage_math_test.dart`（周环比计算）、
`edit_platform_test.dart`（编辑自定义平台 widget 测试），
并在 `week_utils_test.dart`/`update_service_test.dart`/`storage_history_test.dart`
中补充 weekKeyForMonday、shouldPrompt 与忽略版本的用例。
v1.7.0 补充：`home_features_test.dart` 中新增桌面快捷方式通道契约用例、
统计页实时刷新回归用例；`week_utils_test.dart` 补充 `isoWeekYearWeek` 跨年边界用例；
`edit_platform_test.dart` 补充 URL 空主机校验用例。
v1.9.0 补充：`ask_utils_test.dart`（提问历史去重/截断/模板合并），
`home_features_test.dart` 补充聚焦展示模板、提问记录历史与回填的用例。
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
