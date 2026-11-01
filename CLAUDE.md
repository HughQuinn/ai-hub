# CLAUDE.md - AI 行为规则

## Project Overview

Flutter + Kotlin AI 服务聚合启动器，卡片式入口 + 内嵌 WebView 加载 AI 服务网页。

- **技术栈**: Flutter 3.12+ / Dart 3.12+ / Kotlin (Android 原生)
- **包管理**: pubspec.yaml (flutter pub)
- **状态管理**: Provider
- **UI**: Material 3
- **原生通信**: MethodChannel（唯一通道 `com.aihub.webview`）
- **版本号**: pubspec.yaml 的 version 字段是唯一来源，代码通过 AppInfo 读取

## Project Structure

```
lib/
├── main.dart           # 入口，仅调用 MyApp
├── app.dart            # MaterialApp 配置、主题、路由
├── config/             # 配置常量（services_config, theme_config, icons_config）
├── models/             # 数据模型（ai_service）
├── pages/              # 页面级组件（main_shell, home_page, stats_page, settings_page,
│                       #   add_platform_page, sort_hide_page）
├── providers/          # Provider 状态管理（theme_provider）
├── services/           # 业务服务层（storage_service, update_service,
│                       #   reachability_service, app_shortcuts_service, app_info）
├── utils/              # 工具函数（week_utils, service_order_utils, backup_codec, usage_math）
└── widgets/            # 可复用 UI 组件（service_card, app_background, update_dialog）

android/
├── app/src/main/kotlin/com/example/ai_hub/
│   ├── MainActivity.kt         # 主 Activity + MethodChannel + 桌面快捷方式
│   └── WebViewActivity.kt      # 内置 WebView 页面
└── AndroidManifest.xml         # 权限与 queries 声明
```

## Development Rules

### 文件命名
- 文件名: `snake_case.dart`（如 `home_page.dart`）
- 类名: `PascalCase`（如 `MyApp`）
- 变量/函数: `camelCase`（如 `userName`）
- 常量: `camelCase` 或 `UPPER_SNAKE_CASE`

### 文件职责
- 每个文件只放一个 class 或一组紧密相关的函数
- 超过 300 行考虑拆分
- 一个文件一个 widget，不要嵌套定义

### 代码组织
- 页面文件放在 `pages/`
- 可复用组件放在 `widgets/`
- 状态管理放在 `providers/`
- 业务逻辑放在 `services/`
- 数据模型放在 `models/`
- 工具函数放在 `utils/`
- 配置常量放在 `config/`

### 导入顺序
1. Dart 核心库
2. Flutter 框架
3. 第三方包
4. 本项目文件

### MethodChannel
- Channel 命名: `com.aihub.{功能}`
- Flutter 端使用 `MethodChannel` + `invokeMethod`
- Kotlin 端在 `onMethodCall` 中处理
- 错误必须 try-catch，返回 `result.error()`

## UI / UX Rules

- **设计系统**: Material 3（`useMaterial3: true`）
- **主题配置**: 通过 `ThemeData` + `colorSchemeSeed` 配置
- **暗黑模式**: 支持（通过 ThemeProvider 切换）
- **圆角**: 使用 Material 3 默认圆角体系
- **间距**: 统一使用 Material spacing（16px 基准）
- **图标**: 优先使用 Material Icons

## Important Constraints

### 禁止行为
- 不要删除现有文件或目录结构
- 不要修改 `pubspec.yaml` 的 SDK 约束
- 不要升级 Flutter SDK 版本要求
- 不要引入 AGENTS.md 中未列出的新依赖
- 不要一次性重构多个文件
- 不要修改 `analysis_options.yaml` 的 lint 规则
- 不要创建重复的组件或工具函数
- 不要修改 Android 原生的 `MainActivity.kt` 除非有明确需求
- 不要修改 `android/app/build.gradle.kts` 的 minSdkVersion
- 不要在代码中硬编码 API 密钥或敏感信息

### 安全约束
- 不要自动 git commit 或 git push
- 不要修改 `.gitignore`
- 不要创建新的配置文件（如 `.env`）

## Workflow

1. **分析需求**: 先理解任务范围，定位涉及的文件
2. **制定计划**: 输出修改方案，说明改动点
3. **局部修改**: 只改必要的文件，不扩大范围
4. **验证**: 运行 `flutter analyze` 检查错误
5. **保持运行**: 确保修改后项目可正常启动
6. **总结**: 简述变更内容

### 禁止行为
- 未分析直接改代码
- 一次性修改超过 3 个文件
- 随意重构整个模块
- 不测试直接提交

## Preferred Libraries

当前依赖（不要引入其他第三方包）:

| 包名 | 用途 |
|------|------|
| `provider` | 状态管理 |
| `shared_preferences` | 本地键值存储 |
| `url_launcher` | 打开系统浏览器/外部链接 |
| `http` | HTTP 请求（更新检查） |
| `flutter_svg` | SVG 图标渲染 |
| `package_info_plus` | 读取应用版本信息 |

### 禁止引入
- 不要引入 `dio`（已有 `http`）
- 不要引入 `riverpod`（已有 `provider`）
- 不要引入 `bloc` / `getx` 等其他状态管理
- 不要引入 `flutter_bloc`、`mobx`、`redux`

## Response Style

- 回答简洁，直接给结果
- 不输出长篇理论或教程
- 不重复用户问题
- 不输出无关解释
- 修改代码时直接改，不先解释一遍再改

## 常用命令

```bash
# 获取依赖
flutter pub get

# 代码分析
flutter analyze

# 格式化
dart format lib/

# 运行测试
flutter test

# 构建
flutter build apk
```

## 与 AGENTS.md 的关系

本文件定义 **AI 行为规则**，AGENTS.md 定义 **开发规范和技术细节**。

- 修改代码风格 → 查 AGENTS.md
- 新增 MethodChannel → 查 AGENTS.md 通信规范
- WebView 开发 → 查 AGENTS.md WebView 规范
- 判断能否修改 → 查本文件 Important Constraints
- 不确定放哪里 → 查本文件 Project Structure

最后：每次输出前先plan给出方案，等待用户确认在执行。不要直接更改文件。