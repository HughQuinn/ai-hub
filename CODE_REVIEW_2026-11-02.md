# AI Hub 代码库审查报告

- **审查对象**：`F:/forge/AiHub`（v1.4.0+3，Flutter 3.44 / Dart 3.12）
- **审查时间**：2026-11-02
- **覆盖范围**：`lib/` 全部 22 个 Dart 文件（4,103 行）、`android/` 2 个 Kotlin 文件与 Manifest/Gradle 配置、`test/` 8 个测试文件（532 行）、README/AGENTS/CLAUDE 文档
- **手段**：逐文件通读 + `flutter analyze` + 全量 `flutter test` + 对关键算法写临时脚本实测

## 基线事实

| 项目 | 结果 |
|------|------|
| `flutter analyze` | No issues found（0 error / 0 warning / 0 info） |
| `flutter test` | 39 个用例全部通过 |
| 代码分层 | config / models / pages / providers / services / utils / widgets 职责边界清晰 |
| 版本控制 | **v1.4.0 的全部改动尚未提交**：11 个文件已修改、8 个新增文件（含 `stats_page.dart` 与全部新测试）处于 untracked 状态 |

> 环境备注：本机 `HTTP_PROXY` 环境变量会导致 `flutter test` 的 `flutter_tester` WebSocket 握手失败，需 `NO_PROXY=localhost,127.0.0.1` 才能跑。CI 上不会遇到，但本地开发会被误判为"测试全挂"。

## 结论摘要：先修这三件

1. **跨年那几天点"清理历史数据"，会把统计全删掉**（A-1）。这是唯一会造成不可逆数据丢失的缺陷，且已实测复现。
2. **统计页看到的数据永远是上次启动时的**（A-2）。核心新功能实际不可用，用户会以为统计坏了。
3. **自定义平台数据一旦损坏，排序页/添加页直接红屏**（A-3）。JSON 解析没有防御，三个入口里只有一个做了兜底。

---

# 一、问题清单

优先级定义：
- **P0**：会造成数据丢失或安全风险，修复成本低，应立即处理
- **P1**：主流程正确性/体验受损，或显著技术债
- **P2**：局部体验或可维护性问题
- **P3**：打磨项，可排期处理

## A. 正确性缺陷

### A-1（P0）跨年周键错乱，清理历史会误删全部数据
- **位置**：`lib/utils/week_utils.dart:56-58`（`getCurrentYear`）、`:63-86`（`getCurrentWeekNumber`）、`:89-93`（`getCurrentWeekKey`）；触发点 `lib/services/storage_service.dart:116-134`（`pruneHistory`）
- **现象**：周键用「日历年份 + ISO 周号」拼接，两者在跨年时不同源。实测：
  - `2027-01-01` → 键 `2027_W53`（正确应为 `2026_W53`）→ `weekMonday(2027,53)` 推算成 `2028-01-03`，**偏差 367 天**
  - `pruneHistory` 的截止日随之变成 `2027-10-18`，所有历史周都早于该日 → **一次性清空全部统计**
  - `2028-01-02` 同样触发（推算偏差 358 天）
  - 即使不崩，`2025-12-29~31` 记为 `2025_W53`、`2026-01-01~04` 记为 `2026_W1`，**同一个 ISO 周被拆成两个桶**
- **理由**：ISO 8601 的"周年（week-year）"由该周周四所在年份决定，与 `DateTime.now().year` 不是一回事。当前实现只在"1 月 1 日早于当年第一周周一"时走上一年的分支，却仍然用当年年份拼键，于是年份与周号错配。这个分支平均每年有 3/7 的概率被触发（1 月 1 日为周五/六/日），持续 1~3 天。
- **建议**：不要用「年 + 周号」做键。直接以**该周周一的日期字符串**（`2026-11-02`）作为周键：天然唯一、天然可排序、跨年无歧义，`pruneHistory` 只需字符串比较；若坚持保留周号，则必须按 ISO 规则推导 week-year（`mondayOf(now).year`），并补 `2027-01-01` 这类固定日期的测试（现测试依赖真实时钟，覆盖不到，见 E-2）。
- **修复成本**：约 30 行 + 1 个迁移函数（把旧键归一化到新键）。

### A-2（P1）统计页数据永不刷新，必须重启 App
- **位置**：`lib/pages/stats_page.dart:26-39`（仅在 `initState` 调 `_loadData`）+ `lib/pages/main_shell.dart:57-60`（`IndexedStack` 保活）
- **现象**：`IndexedStack` 让三个页面常驻，`StatsPage` 的 `initState` 只执行一次。用户在首页点开若干服务后切到"统计"，看到的仍是启动时的数据；重启 App 才会更新。
- **理由**：数据加载时机绑定在 widget 生命周期上，而页面的"可见"与"创建"在这一架构下不再等价。这是 `IndexedStack` 的经典陷阱。
- **建议**：把点击计数提升为 `ChangeNotifier`（或 `ValueNotifier<Map<String,int>>`）由 Provider 提供，统计页 `Consumer` 订阅；或给 `StatsPage` 一个 `refresh()` 由 `MainShell.onTap` 在切页时调用（与现有 `HomePage.refreshServices` 同一思路，但更彻底的做法是去掉 GlobalKey，见 D-3）。
- **同类隐患**：`SettingsPage` 的语言也在 `didChangeDependencies` 只读一次，但它不依赖会变的数据，暂不构成缺陷。

### A-3（P1）自定义平台 JSON 无防御，脏数据直接红屏
- **位置**：`lib/services/storage_service.dart:70-73`（`getCustomPlatforms` 直接 `jsonDecode` + 强转）；调用点 `lib/pages/sort_hide_page.dart:31-46`、`lib/pages/add_platform_page.dart:40-45`、`lib/pages/settings_page.dart:472-483`
- **现象**：`jsonDecode(json) as Map<String, dynamic>` 与随后的 `p['name'] as String` 均无校验。任意一条记录缺字段、或 `jsonDecode` 抛 `FormatException`，三个页面分别会红屏/白屏；只有 `home_page.dart:116-134` 做了 try/catch。
- **理由**：存储层把"反序列化"这件本应容错的事，交给了每个调用方各自处理，而调用方只实现了一次。数据来源包括历史版本写入、用户改机恢复、异常退出导致的半写，概率不低。
- **建议**：在 `StorageService` 内部统一兜底——`try/catch` + 过滤非法项 + 丢弃坏记录并返回空列表；同时给 `AiService` 补 `fromMap`（见 D-2），把字段映射收敛到一处。

### A-4（P1）「检查更新」把网络失败说成"已是最新版本"
- **位置**：`lib/services/update_service.dart:62-64`（`catch (_) { return null; }`）+ `lib/pages/settings_page.dart:387-401`
- **现象**：`null` 同时表示"没有新版本"和"检查失败"，设置页据此提示"当前已是最新版本"。断网、超时、GitHub 限流（未认证 60 次/小时/IP）都会被描述成"已是最新"。
- **理由**：用单一返回值承载三态语义，调用方无法区分，用户得到的是错误结论而非错误提示。
- **建议**：改为返回 `UpdateCheckResult`（`available` / `upToDate` / `failed(message)`）三态；失败时提示"检查失败，请检查网络"。启动时的静默检查可以继续忽略失败，但手动检查必须区分。

### A-5（P2）"近 12 周趋势"在本周无点击时退化为全部历史
- **位置**：`lib/pages/stats_page.dart:42-49`
- **现象**：`sorted.indexOf(current) < 0` 时直接 `return sorted`。本周（11 月第一周）若还没点开任何服务，图表会把全部历史周都画出来，可能是几十根柱子，而不是 12 根。
- **理由**：用"历史里存在的周"作为横轴，而不是"最近 12 个周"。缺周不补 0，逻辑上把"无数据"误当成"无该周"。
- **建议**：从本周周一往前推 11 周，生成 12 个周键，再逐键取 `_history[key] ?? {}`。

### A-6（P2）点击即重排：卡片会在手指下方跳走；打开失败也照样计数
- **位置**：`lib/pages/home_page.dart:493-532`（`_openService`），排序逻辑 `:137-186`
- **现象**：每次点击先 `incrementClick`，再 `getAllClickCounts` 全量重读，然后 `setState`。在"按周点击排序"模式下，被点的卡片立刻升位，网格重排；用户下一次点同一位置，可能点到别的服务。另外计数发生在打开动作之前，打开失败（`openUrl` 抛错）也计一次。
- **理由**：把"记录"与"排序刷新"耦合在一次交互里。排序是慢变量，不该在点击瞬间重算。
- **建议**：点击只写计数（不立即刷新排序），页面在重新进入、下拉刷新或切 Tab 时再重排；计数写入放到"打开成功"之后，或明确接受"尝试即计数"并写进注释。

### A-7（P2）以显示名作为服务主键，改名/重名即丢数据
- **位置**：`lib/models/ai_service.dart:4-29`；全链路使用 `service.name` 作存储键：`storage_service.dart:16/22/35`（点击）、`:50-99`（隐藏/排序/置顶）
- **现象**：内置服务改一次显示名（例如"千问"→"通义千问"），历史点击、排序位置、置顶状态全部失联；删除自定义平台后，`pinned_services` 里的名字不会被清理，成为永久残留。
- **理由**：把"展示字段"当"标识字段"。展示名是产品文案，天然会变；存储键必须稳定。
- **建议**：给 `AiService` 加 `id`（内置用固定串，自定义用生成 UUID），所有持久化改用 `id`，展示名只用于 UI。这是一次性迁移，越晚做成本越高（数据越多）。

### A-8（P2）「语言」设置是空壳
- **位置**：`lib/pages/settings_page.dart:30-34`（三种语言名）、`:318-365`（选择对话框）；写入 `storage_service.dart:82-89`；**全项目无 `flutter_localizations`**
- **现象**：设置页可写 `language`，但界面文案全部硬编码中文（首页 hint、设置分组标题、SnackBar 等），没有任何读取该值的渲染路径。选"简体中文"等于什么都没发生；繁中/English 标着"即将支持"。
- **理由**：设置了不存在的功能，比没有这个设置更伤信任。同时 `available = {'zh-CN'}` 这层校验暗示作者知道它无效，属于临时占位没清理。
- **建议**：二选一——要么接 `flutter_localizations` + ARB 真正落地（工作量大），要么先把入口降级为"仅简体中文"的只读展示，等 i18n 就绪再开放。

### A-9（P3）主题加载与用户操作存在竞态
- **位置**：`lib/providers/theme_provider.dart:12-29`
- **现象**：构造函数异步 `getInstance()` 后才赋值 `_prefs`。若用户在这之前切换主题，`setThemeMode` 里 `_prefs?.setString` 静默失败（不落盘）；若读回晚于用户操作，还会用旧值覆盖新选择。默认 `ThemeMode.dark` 也会让浅色用户看到一帧深色。
- **建议**：在 `main()` 里先 `await SharedPreferences.getInstance()` 再构造 Provider 并传入实例（与 `StorageService` 的做法保持一致），或提供 `Future<ThemeProvider> create()`。

### A-10（P3）卡片视图宽度与 `viewportFraction` 不一致
- **位置**：`lib/pages/home_page.dart:30-31`（`viewportFraction: 0.78`）与 `:268-285`（宽屏 `widthFactor = 0.65`）
- **现象**：屏幕宽度 > 420 时，卡片按 0.65 屏宽绘制，但 PageView 的视口仍按 0.78 分配，卡片左右留白过大、相邻卡片露出比例失真。
- **建议**：`viewportFraction` 与 `widthFactor` 用同一变量推导，或直接用 `LayoutBuilder` 计算两者。

## B. 安全与发布

### B-1（P1）WebView 把任意 scheme 交给系统 Intent
- **位置**：`android/app/src/main/kotlin/com/example/ai_hub/WebViewActivity.kt:48-65`
- **现象**：`shouldOverrideUrlLoading` 对**所有非 http(s)** 的 URL 直接 `startActivity(Intent(ACTION_VIEW, Uri.parse(url)))`，白名单缺失。页面里的 `intent://...`、`file://`、`content://` 链接都会被原样投递给系统。
- **理由**：`intent:` scheme 可以携带 extras 启动任意组件（intent redirection），是 WebView 的已知攻击面；`content://`/`file://` 则可能被用来探测本地资源。AI 站点本身可信，但页面内的第三方广告/镜像/跳转不可控，而本 App 恰恰把 WebView 当作主浏览器在用。
- **建议**：显式白名单 `http/https/mailto/tel`，其余一律 `return true` 丢弃；对 `intent:` 明确拒绝。若确需调起支付宝/微信等，单独列包名白名单。

### B-2（P1）用 shell 启动应用 + 主线程 `waitFor()`
- **位置**：`android/app/src/main/kotlin/com/example/ai_hub/MainActivity.kt:57-71`
- **现象**：`getLaunchIntentForPackage` 返回 null 时，执行 `Runtime.getRuntime().exec(arrayOf("sh","-c","am start ... $packageName"))`，随后 `process.waitFor()` **在 MethodChannel 主线程同步等待**，并读取两个流。
- **理由**：三点叠加——(1) 字符串拼接进 `sh -c`，`packageName` 含 `;`/`` ` `` 即为命令注入（当前值来自内置配置，但通道对外可调）；(2) `waitFor()` 阻塞主线程，子进程慢即 ANR；(3) 应用 UID 无 `am` 命令权限，这条兜底在真机上基本不生效，属于"看起来更稳，实际上更危险"的死代码。
- **建议**：删除整个 shell 分支，`getLaunchIntentForPackage` 为 null 就直接 `result.error(...)`，由 Dart 侧回退到 WebView。

### B-3（P2）`checkAppInstalled` 用了 `MATCH_UNINSTALLED_PACKAGES`
- **位置**：`android/.../MainActivity.kt:43`
- **现象**：该 flag 会把"已卸载但保留数据"的包算作已安装（Android 11+ 语义）。于是 Dart 侧判定 `installed == true` → 尝试 `launchApp` → 失败 → 兜底跳外部浏览器，用户看到"点了卡片却打开浏览器"。
- **建议**：`getPackageInfo(pkg, 0)`；同时把 `checkAppInstalled` 的 19 次串行调用合并为一次批量查询（见 C-4）。

### B-4（P2）全屏 WebView 无地址栏，用户无法确认域名
- **位置**：`android/.../WebViewActivity.kt` 整体（仅 ProgressBar + 错误页）
- **现象**：加载后看不到当前 URL，站内任意跳转都在同一壳内完成，没有刷新、没有"在浏览器打开"、没有分享。
- **理由**：一方面这是钓鱼的温床（用户无法判断自己是否还在 kimi.moonshot.cn）；另一方面是可用性死角——页面卡住、登录异常时，用户只能退出重进。
- **建议**：顶部加一条 32dp 的地址条（域名 + 刷新 + 更多菜单），或至少在"更多"里提供刷新/复制链接/浏览器打开/清 Cookie。

### B-5（P2）release 缺签名时静默回退 debug 签名
- **位置**：`android/app/build.gradle.kts` 的 `buildTypes.release`
- **现象**：`signingConfig = if (keystorePropertiesFile.exists()) release else debug`。没有 `key.properties` 时照样产出名为 release 的 APK，但用 debug key 签名。
- **理由**：这种包装不上架，且**无法覆盖安装到已发布的版本**（签名不一致），而构建过程一声不吭。所谓"签名缺失守卫"实际是"签名缺失降级"。
- **建议**：缺失时 `throw GradleException("...")` 中断构建；debug 签名只留给 `debug`/`profile` 变体。

### B-6（P2）签名材料放在工程目录内
- **位置**：`android/app/release-key.jks`、`android/key.properties`（均已被 `.gitignore` 忽略，未进版本库）
- **理由**：keystore 与明文口令同处工程目录，一次打包分享/云同步/误提交（`.gitignore` 是软约束）就会同时泄露两者；keystore 泄露等于别人可以给你的 App 签名发版。
- **建议**：keystore 移出仓库（如 `~/.android-keys/` 或 CI secret），口令走环境变量；`.gitignore` 再加一道 `*.jks`（已有）并考虑 `git secrets`/pre-commit 扫描。

### B-7（P3）未关闭 `allowBackup`
- **位置**：`android/app/src/main/AndroidManifest.xml:3-7`
- **理由**：默认 `allowBackup=true`，应用数据（自定义平台、统计、置顶）可被 adb/云备份带走。对无账号体系的本地工具类 App，建议显式 `android:allowBackup="false"`，或提供自己的导出功能（见 F-1）后关闭系统备份。

### B-8（P3）OTA 下载链路无完整性校验
- **位置**：`lib/widgets/update_dialog.dart:32-47`
- **现象**：跳系统浏览器下载 APK，App 不参与下载与校验，也不校验签名/哈希。
- **建议**：若继续走浏览器，至少在弹窗展示版本与 SHA256 前 8 位；若改为应用内下载，务必校验 `PackageManager` 签名与当前包一致后再引导安装。

## C. 性能

### C-1（P1）双份常驻全屏动画，且永不停
- **位置**：`lib/widgets/app_background.dart:18-25`（20 秒 `repeat()`）、`:33-47`（`AnimatedBuilder` 每帧重建 `CustomPaint`）；`lib/pages/main_shell.dart:57-60`（`IndexedStack`）
- **现象**：`HomePage` 与 `StatsPage` 各挂一个 `AppBackground`。`IndexedStack` 会保留非当前页的 element 与 ticker，因此**两个 20 秒循环动画永久同时运行**，即便用户停在设置页、即便屏幕内容静止。每帧都会重建 `CustomPaint` 并触发 `_BackgroundPainter` 的 `paint`。
- **理由**：这是纯粹的持续性耗电与掉帧来源，且用户完全感知不到"它在动"的收益（漂移幅度 6% 屏宽 / 20 秒）。在低端机上会直接压低滚动帧率。
- **建议**：三件事分开做——(1) 不可见页面用 `TickerMode(enabled: false)` 包一层；(2) 静态底纹（三层径向渐变）只画一次，缓存为 `ui.Image` 或 `RepaintBoundary`；(3) 只让柔光圆动，并把动画降到 30fps 或改用 `AnimatedPositioned` 级别的便宜变换。

### C-2（P1）每帧新建 Paint / RadialGradient / Shader
- **位置**：`lib/widgets/app_background.dart:128-143`（`_drawRadialLayer`）、`:146-170`（`_drawOrbs`）
- **现象**：`paint()` 内每帧为 3 层底纹 + 8 个柔光圆各 `new Paint()` 且 `createShader(...)`，共 11 次着色器创建；`_getOrbs()` 每帧新建 `List<_Orb>`（虽然元素是 const）。
- **理由**：`Shader` 创建涉及 GPU 侧资源分配与编译，是绘制里最贵的操作之一。这段代码把"每帧做 11 次"写在了热路径上。
- **建议**：在 `didChangeDependencies`/尺寸变化时预生成 shader 并缓存（key 用 `Size` + `isDark`）；`_getOrbs()` 提为 `static const`。柔光圆若只是平移，用 `canvas.save/translate` 复用同一个 shader。

### C-3（P2）每张卡片一个 persistent frame callback，滚动回调未节流
- **位置**：`lib/pages/home_page.dart:920-936`
- **现象**：`initState` 里 `SchedulerBinding.instance.addPersistentFrameCallback(...)` **从不移除**，19 张卡就是 19 个每帧回调；`_onScroll` 每次滚动事件都 `addPostFrameCallback`（注释写"轻量节流"，实际没有任何节流），回调内还调用 `MediaQuery.of(context)`（注册依赖 + 触发查找）。
- **理由**：入场动画只需一次触发，却用了最贵的持续监听；滚动时每帧可能压入十几个回调，每个都做一次 `localToGlobal` + `MediaQuery` 查找。
- **建议**：改用一次性的 `addPostFrameCallback` + `ScrollNotification` 统一在父级判断可见性；或引入 `visibility_detector`；`MediaQuery.of` 换成在 `build` 里缓存的 `screenHeight`。

### C-4（P2）19 次串行 MethodChannel 调用查安装状态
- **位置**：`lib/pages/home_page.dart:73-88`
- **现象**：`for` 循环里 `await` 逐个 `checkAppInstalled`，19 个包名串行往返，且每个都带 try/catch。加载完成后再触发，用户看到的是"卡片先全部显示网页图标，再逐个变成绿点"。
- **建议**：原生侧提供 `checkAppsInstalled(packageNames: List<String>)` 一次返回 `Map<String, Boolean>`；Dart 侧一次调用。19 次平台通道往返 ≈ 19 次线程切换，合并后开销可忽略。

### C-5（P3）排序比较器里 `list.indexOf`
- **位置**：`lib/pages/home_page.dart:169-176`
- **现象**：`compareByClick` 在比较器内调用 `list.indexOf(a)`，每次比较 O(n)，整体 O(n² log n)；且依赖传入列表的当前顺序（可读性差）。
- **建议**：排序前建 `Map<AiService,int>` 记录原始下标，比较器内 O(1) 查表。19 项时无感，但这是会被复制到更大列表的坏模式。

## D. 架构与可维护性

### D-1（P1）首页 989 行，混合 6 类职责
- **位置**：`lib/pages/home_page.dart` 全文（全项目 4,103 行中占 24%）
- **现象**：同一个 State 里同时承担：服务数据聚合与排序、安装状态探测、WebView 通道调用、搜索/筛选、两套视图（网格 + 卡片堆叠）渲染、长按操作面板、AI 直达提问。README 自己定的规则是"一个文件一个 class，不超过 300 行"，此处超了 3 倍多（`settings_page.dart` 607 行、`stats_page.dart` 454 行同样越界）。
- **理由**：任何一处改动都要在 989 行里定位；`_buildCardView` 一个方法 180 行、嵌套 8 层，无法单测；新增视图（如列表模式）只能继续堆。
- **建议**：按职责切分为 `HomeController`（数据 + 排序 + 计数）、`ServiceGrid`、`ServiceCardStack`、`ServiceActionSheet`、`AskServiceRow`、`ServiceLauncher`（通道封装）。先抽最独立的 `_AnimatedCard`（已在文件底部，可直接迁出）与长按面板，风险最低。

### D-2（P1）"Dart Map → AiService"映射复制了 3 份
- **位置**：`lib/pages/home_page.dart:115-135`、`lib/pages/sort_hide_page.dart:37-46`、`lib/pages/settings_page.dart:475-483`
- **现象**：三处几乎相同的 `AiService(name: p['name'] as String, url: ..., description: ..., region: ...)`。第三份**漏了 `iconName`**，所以可达性检测里的服务没有自定义图标（该页面不显示图标，暂时无感，但字段一旦用于展示就是 bug）。
- **理由**：序列化格式的事实源头散落在 UI 层。新增字段（如 F-2 的 `askUrlTemplate`）要改三处，漏一处即静默不一致——本次审查已经抓到一次漏改。
- **建议**：`AiService.fromMap` / `toMap` 收敛到模型层，三处改为一行调用；`getCustomPlatforms` 直接返回 `List<AiService>` 更彻底。

### D-3（P2）用 GlobalKey 跨层调用子页面方法
- **位置**：`lib/pages/main_shell.dart:24`（`GlobalKey<HomePageState>`）、`:53`（`_homePageKey.currentState?.refreshServices()`）
- **现象**：设置页返回后刷新首页，靠壳层持有首页 State 的 key 直接调方法。为此 `HomePageState` 被迫声明为 public（`home_page.dart:19`）。
- **理由**：页面状态泄漏到导航层，二者强耦合；`currentState` 可能为 null（静默不刷新）；测试里也无法替换。
- **建议**：引入 `ServiceRepository`/`HomeViewModel` 作为唯一数据源，首页 `Consumer` 订阅，设置页写入后自动生效；同时可顺手解决 A-2（统计页刷新）。

### D-4（P2）`region` 用字符串表示枚举
- **位置**：`lib/models/ai_service.dart:11`；散落判断：`home_page.dart:162/192-194`、`sort_hide_page.dart:43`、`add_platform_page.dart:23/105/297`、`settings_page.dart:480`
- **现象**：`'domestic'` / `'overseas'` 字面量出现 6 处以上，拼错不会报错，只会让服务"消失"在某个 Tab 里。
- **建议**：`enum ServiceRegion { domestic, overseas }`，存储时用 `name`，解析时容错默认值。

### D-5（P2）存储层职责混杂 + 危险 API + 死代码
- **位置**：`lib/services/storage_service.dart` 全文
- **现象**：
  - `clearAllData()`（`:45-47`）会 `_prefs.clear()`，连 `theme_mode`、`language`、`custom_platforms` 一起清空——目前无 UI 调用，但作为 public API 存在，任何人接个"清除缓存"按钮就会全灭。
  - 版本/主题/语言/平台/统计/排序七类数据塞在同一个类里，`StorageService` 已达 135 行且持续膨胀。
  - 全量扫描 `getAllClickCounts`（`:28-42`）与 `getWeeklyHistory`（`:103-113`）每次遍历所有 key；`incrementClick` 后调用方又立刻全量重读（A-6）。
  - 死代码：`clearAllData`、`toggleTheme`（`theme_provider.dart:31`）、`getIconByName`（`icons_config.dart:42`）、`AppColors.cardPressed`（`theme_config.dart:12`）、`WeekUtils.storageKeyPrefix`（`:4`，声明了却没人用，前缀在 `:9/:13/:92` 各硬编码一次）。
- **建议**：按领域拆 `ClickStatsStore` / `PreferencesStore` / `CustomPlatformStore`；`clearAllData` 改为带 scope 参数的显式方法；前缀常量真正被三处引用，否则删掉，避免"看起来有单一来源其实没有"。

### D-6（P2）文档与实现漂移
- **位置**：`README.md`、`AGENTS.md`、`pubspec.yaml:2`
- **现象**：
  - README 的目录树缺 `stats_page.dart`、`reachability_service.dart`、`service_order_utils.dart`；`main_shell` 仍写"主页 + 设置"（现实是三个 Tab）。
  - README/AGENTS 写 "Flutter SDK ^3.12.0"——3.12 是 **Dart** 版本，本机 Flutter 为 3.44；把两者混为一谈会让新环境装错 SDK。
  - README 说 "API 21+"，而 `minSdk = flutter.minSdkVersion`（Flutter 3.44 默认 24），实际支持范围与文档不符。
  - README 自定"不超过 300 行"，4 个文件越界（见 D-1），规则形同虚设。
  - `pubspec.yaml:2` 仍是模板默认的 `"A new Flutter project."`（会出现在应用元信息中）。
  - v1.4.0 已发版，但无 `CHANGELOG.md`。
- **建议**：把"文档即代码"落到 CI（见 D-7）——至少在 PR 模板里加一条"改功能是否同步 README/AGENTS"；`pubspec.description` 一句话改掉。

### D-7（P3）无 CI 门禁，质量全靠本地自觉
- **位置**：仓库根目录（缺 `.github/workflows/`）
- **现象**：`flutter analyze` 与 39 个测试都是手动跑；本次审查发现 v1.4.0 全部改动尚未提交（11 改 + 8 新增），说明提交流程也比较随意。
- **建议**：加一个最小 workflow：`flutter analyze` → `flutter test` → `flutter build apk --debug`（PR 门禁）；tag 时构建 release 并上传 GitHub Release（顺带解决 OTA 手工发版）。同时把当前工作区改动按主题拆成多个提交（用户既有习惯：一个提交只做一件事）。

### D-8（P3）包名不一致 + 多平台脚手架残留
- **位置**：`android/app/build.gradle.kts`（`namespace = "com.example.ai_hub"`, `applicationId = "com.xuqiyi.aihub"`）、Kotlin 包 `com.example.ai_hub`；`ios/ macos/ windows/ linux/ web/` 目录
- **现象**：namespace 与 applicationId 不同源，`com.example` 前缀在正式项目里不合适（且与 `MainActivity.kt` 的 package 绑定，迁移需同步改目录与 Manifest）。五个非 Android 平台的脚手架存在，但 MethodChannel 未实现，跑起来功能残缺。
- **建议**：统一为 `com.xuqiyi.aihub`（一次性迁移，越早越便宜）；删除不维护的平台目录，或明确标注"实验性"。

## E. 测试

### E-1（P2）关键路径无覆盖
- **位置**：`test/`（现有 8 文件 532 行，39 例）
- **现状**：纯函数（周工具、排序、直达 URL、版本比较、可达性分类）与 3 个 widget 冒烟覆盖得不错，但以下高风险路径为 0：
  - `SortHidePage` 拖拽排序后的持久化与"新服务追加到末尾"的和解逻辑
  - `AddPlatformPage` 的重名/非法 URL 校验
  - `StorageService` 脏数据（正是 A-3 的崩点）
  - `UpdateService` 的失败分支（正是 A-4 的误报点）
  - 跨年周键（正是 A-1 的爆点）
- **建议**：优先补 A-1/A-3/A-4 对应的回归测试；这三条都是"不发生则已，发生就致命"的类型。

### E-2（P3）测试依赖真实时钟，无法覆盖时间边界
- **位置**：`test/week_utils_test.dart:48-56`（"当前周键与当前周一互相自洽"直接读 `DateTime.now()`）
- **理由**：这类断言在 364 天里都通过，恰好漏掉唯一会出问题的那 1~3 天。A-1 能活到今天，正是因为测试只能在"今天"跑。
- **建议**：`WeekUtils` 的所有方法接受可选 `DateTime now` 参数（默认 `DateTime.now()`），测试传入 `2027-01-01`、`2025-12-31` 等固定日期。

---

# 二、功能建议

排序依据：对现有用户的即时价值 / 与现有数据结构的契合度 / 实现成本。

### F-1（P1）数据导出 / 导入（JSON 备份）
- **落点**：新增 `lib/services/backup_service.dart`；入口 `settings_page.dart` "数据"分组；复用 `StorageService` 的读写
- **理由**：目前所有资产（自定义平台、排序、置顶、12 周统计）都只存在 SharedPreferences 里，换机、清数据、卸载即全失；叠加 A-1 的误删风险，用户没有任何自救手段。导出/导入是成本最低的"保险"，也是后续云同步的地基。
- **要点**：带 `schemaVersion` 字段；导入时校验并合并（按 id 去重）；可选分享到文件/剪贴板。

### F-2（P1）自定义平台补全：可编辑 + 直达提问模板 + 客户端包名
- **落点**：`add_platform_page.dart` 增加编辑模式；`ai_service.dart` 的 `askUrlTemplate` 透传到自定义平台；`storage_service.dart` 的平台 Map 增加字段
- **理由**：现在自定义平台只能"加"和"删"，URL 填错只能删了重建；`askUrlTemplate` 只有内置服务享有，导致"问 XX"对自定义平台永远走"复制到剪贴板"的降级路径——而自定义平台恰恰是重度用户最常用的入口。
- **要点**：编辑时保留原名（避免 A-7 的数据失联）；模板用 `{q}` 占位并给出示例校验。

### F-3（P1）WebView 顶部工具条
- **落点**：`WebViewActivity.kt`（`container` 增加 Toolbar 层，WebView 下移）
- **理由**：补 B-4 指出的可用性死角。用户至少需要：看到域名、刷新、在系统浏览器打开、复制链接。没有这些，一次登录失败就只能反复退出重进。
- **要点**：域名取自 `webView.url` 的 host；深色模式跟随系统（现有错误页已这么做，可复用同一套 `isNight` 判断）。

### F-4（P1）"最近使用"与一键继续
- **落点**：`storage_service.dart` 增加 `last_used_at`（按服务记录时间戳）；首页顶部新增横向"最近"区
- **理由**：现有排序是"本周累计点击"，粒度过粗——早上用 Kimi、下午用 Claude 的用户，看到的仍是周维度的混合排序。记录最后一次使用时间是 1 个字段的事，却能支撑"继续上次"这一最高频动作。
- **要点**：与 A-7 的 id 改造一起做，避免改名丢时间戳；首页可折叠，不挤占首屏。

### F-5（P2）启动时后台健康检查 + 卡片状态角标
- **落点**：复用 `reachability_service.dart`；`home_page.dart` 卡片角标；结果缓存到 prefs（含时间戳）
- **理由**：现有检测是"设置里点一下、弹窗看完即弃"，数据完全浪费。把结果落到卡片上（绿/橙/灰小圆点），用户点开前就知道该服务当前是否可达，比打开后看错误页体验好得多。
- **要点**：只在启动后延迟 3~5 秒跑一次、结果缓存 30 分钟；并发度限制在 4，避免 19 个请求同时打出去。

### F-6（P2）更新体验完善：跳过版本 / 24h 缓存 / 应用内下载
- **落点**：`update_service.dart`、`update_dialog.dart`、`settings_page.dart`
- **理由**：当前每次启动都请求 GitHub 并弹窗（未认证限流 60 次/小时/IP，多设备共用出口 IP 时容易失败），且没有"跳过此版本"，用户会被同一个弹窗反复打扰。配合 A-4 的三态改造一起做最划算。
- **要点**：`skipped_version` + `last_check_at` 两个键即可；应用内下载可顺带做签名校验（B-8）。

### F-7（P2）统计升级：日粒度热力图 + 单服务详情
- **落点**：`stats_page.dart`；`week_utils.dart` 增加日键工具；存储键从"周"改为"周 + 日"（或新增日键，保留周键做兼容）
- **理由**：现在只有"本周 Top 5 + 12 周柱状图"，回答不了"我这几天的使用节奏如何""Claude 最近是不是用得少了"。日粒度数据一旦开始记录，后续所有分析都成立；不记录则永远补不回来。
- **要点**：日键写入会放大 key 数量（19 服务 × 365 天），需同步收紧 `pruneHistory` 的保留策略（如日数据保留 30 天，周汇总保留 52 周）。

### F-8（P2）桌面快捷方式 / App Shortcuts（Top 3 直达）
- **落点**：`android/app/src/main/res/xml/shortcuts.xml` + Manifest `meta-data`；Top 3 由 `StorageService` 计算
- **理由**：这是"启动器"类 App 最自然的延伸——用户长按图标就能直达最常用的 AI，省掉"开 App → 找卡片"两步。纯原生配置 + 静态 shortcuts 即可，不需要额外权限。
- **要点**：用 `dynamic` shortcuts 按周点击动态注册；点击后用 `intent-filter` 带 extra 启动，Flutter 侧读 `initialRoute` 或 MethodChannel 分发。

### F-9（P2）分项清理本地数据
- **落点**：`settings_page.dart` "数据"分组 + `storage_service.dart`（替换危险的 `clearAllData`）
- **理由**：现在只有"清理历史数据"（12 周前）一个粒度，用户想清空统计、或只重置自定义平台，都做不到。分项清理也是 A-1 误删后的兜底手段。
- **要点**：三个独立入口（使用统计 / 自定义平台 / 全部），全部二次确认并显示将影响的条数。

### F-10（P2）无障碍与字体缩放适配
- **落点**：`home_page.dart:216-251`（Tab 用 `GestureDetector`，无 `Semantics`、无水波纹）、`service_card.dart`、`stats_page.dart`
- **理由**：`GestureDetector` 包裹的 Tab 对 TalkBack 不可聚焦，视障用户无法切换"国内/海外"；固定 `fontSize: 9/11` 在系统字体放大后会溢出（卡片描述已被 `maxLines: 1` 截断，尚可；统计页的柱状图标签会挤重叠）。
- **要点**：Tab 换 `ChoiceChip` 或加 `Semantics(button: true, selected: ...)`；统计页在小屏 + 大字号下改为横向滚动。

### F-11（P3）搜索增强：别名 / 拼音首字母 / 标签
- **落点**：`ai_service.dart` 增加 `aliases`/`tags`；`home_page.dart:200-205` 的匹配逻辑
- **理由**：现在只匹配 `name` 与 `description` 的 `contains`。"写代码"搜不到 Claude，"qwen"搜不到"千问"，"tongyi"也搜不到。给每个内置服务加 2~3 个别名是最便宜的检索增强。
- **要点**：别名也参与"问 XX"行的匹配；后续可加拼音首字母（`lpinyin` 包）。

### F-12（P3）外观选项：纯色省电模式 / 网格列数
- **落点**：`app_background.dart`、`home_page.dart:845-855`（固定 `crossAxisCount: 2`）、`settings_page.dart` 新增分组
- **理由**：C-1/C-2 的动画是"好看但要电"的典型。给用户一个"关闭动态背景"的开关，既是省电选项，也是低端机的性能逃生舱。网格 2/3 列则直接服务大屏与折叠屏。
- **要点**：开关落到 prefs；关闭时 `AppBackground` 直接渲染静态图（或 `SizedBox` + 纯色）。

---

# 三、建议实施顺序

**批次 1（本周，止血）**：A-1（周键改造 + 迁移）、B-1（scheme 白名单）、B-2（删 shell 分支）、A-3（存储层容错）
> 这四条的共同点：改动局部、风险可控、不做则随时可能造成不可逆损失。

**批次 2（下个迭代，主流程）**：A-2（统计刷新，顺手做 D-3 数据层）、A-4（更新三态）、B-3（安装检测）、B-5（签名守卫）、C-1/C-2（背景性能）
> 完成后，三个 Tab 的数据一致性与"设置项说到做到"基本闭环。

**批次 3（架构与体验）**：D-1（首页拆分）、D-2（模型映射收敛）、A-7（id 化）、F-1（备份）、F-2（自定义平台补全）、F-3（WebView 工具条）
> A-7 是 F-1/F-4 的前置，建议在写备份功能之前完成。

**批次 4（打磨）**：D-6（文档对齐）、D-7（CI）、E-1/E-2（回归测试）、F-5~F-12 按兴趣取用
