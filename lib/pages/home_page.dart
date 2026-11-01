import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme_config.dart';
import '../config/services_config.dart';
import '../models/ai_service.dart';
import '../services/storage_service.dart';
import '../widgets/service_card.dart';
import '../widgets/app_background.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const _channel = MethodChannel('com.aihub.webview');
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  Map<String, int> _clickCounts = {};
  int _selectedTab = 0; // 0=全部, 1=国内, 2=国外
  bool _viewModeCard = false; // false=网格, true=卡片
  final PageController _pageController =
      PageController(viewportFraction: 0.78);
  int _currentPage = 0;

  bool _isLoading = true;
  bool _initialized = false;

  // 隐藏服务和自定义排序
  Set<String> _hiddenNames = {};
  List<String>? _customOrder;
  List<AiService> _customServices = [];

  // 客户端安装状态缓存
  final Map<String, bool> _installedClients = {};

  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initData();
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _loadClickCounts();
    await _loadHiddenAndOrder();
    await _loadCustomPlatforms();
    setState(() => _isLoading = false);
    _checkInstalledClients();
  }

  /// 检测所有服务的客户端安装状态
  Future<void> _checkInstalledClients() async {
    final allServices = [...aiServices, ..._customServices];
    for (var service in allServices) {
      if (service.packageName != null) {
        try {
          final result = await _channel.invokeMethod('checkAppInstalled', {
            'packageName': service.packageName,
          });
          _installedClients[service.name] = result == true;
        } catch (e) {
          _installedClients[service.name] = false;
        }
      }
    }
    setState(() {});
  }

  Future<void> _loadClickCounts() async {
    final counts = await _storageService.getAllClickCounts();
    setState(() {
      _clickCounts = counts;
    });
  }

  Future<void> _loadHiddenAndOrder() async {
    final hiddenList = await _storageService.getHiddenServices();
    final order = await _storageService.getCustomOrder();
    setState(() {
      _hiddenNames = hiddenList.toSet();
      _customOrder = order;
    });
  }

  /// 刷新服务列表（从排序页面返回时调用）
  Future<void> refreshServices() async {
    await _loadHiddenAndOrder();
    await _loadClickCounts();
    await _loadCustomPlatforms();
  }

  Future<void> _loadCustomPlatforms() async {
    try {
      final platforms = await _storageService.getCustomPlatforms();
      final customServices = platforms.map((p) {
        return AiService(
          name: p['name'] as String,
          url: p['url'] as String,
          description: (p['description'] as String?) ?? '',
          iconName: (p['iconName'] as String?) ?? 'smart_toy_outlined',
          region: (p['region'] as String?) ?? 'domestic',
          isCustom: true,
        );
      }).toList();
      setState(() {
        _customServices = customServices;
      });
    } catch (e) {
      // 自定义平台数据损坏时不让首页崩溃
      debugPrint('[AiHub] _loadCustomPlatforms error: $e');
    }
  }

  List<AiService> get _sortedServices {
    // 合并内置服务和自定义服务
    final allServices = [...aiServices, ..._customServices];

    // 过滤隐藏的服务
    var services = allServices
        .where((s) => !_hiddenNames.contains(s.name))
        .toList();

    // 如果有自定义排序，按自定义顺序排列
    if (_customOrder != null && _customOrder!.isNotEmpty) {
      final orderMap = <String, int>{};
      for (int i = 0; i < _customOrder!.length; i++) {
        orderMap[_customOrder![i]] = i;
      }
      services.sort((a, b) {
        final aIndex = orderMap[a.name] ?? 999;
        final bIndex = orderMap[b.name] ?? 999;
        return aIndex.compareTo(bIndex);
      });
    } else {
      // 按点击量排序
      final domestic = <AiService>[];
      final overseas = <AiService>[];
      for (final s in services) {
        if (s.region == 'domestic') {
          domestic.add(s);
        } else {
          overseas.add(s);
        }
      }

      int compareByClick(List<AiService> list, AiService a, AiService b) {
        final aCount = _clickCounts[a.name] ?? 0;
        final bCount = _clickCounts[b.name] ?? 0;
        if (aCount > 0 && bCount > 0) return bCount.compareTo(aCount);
        if (aCount > 0) return -1;
        if (bCount > 0) return 1;
        return list.indexOf(a).compareTo(list.indexOf(b));
      }

      domestic.sort((a, b) => compareByClick(domestic, a, b));
      overseas.sort((a, b) => compareByClick(overseas, a, b));
      services = [...domestic, ...overseas];
    }

    return services;
  }

  List<AiService> get _filteredServices {
    var result = _sortedServices;
    // Tab 筛选
    if (_selectedTab == 1) {
      result = result.where((s) => s.region == 'domestic').toList();
    } else if (_selectedTab == 2) {
      result = result.where((s) => s.region == 'overseas').toList();
    }
    // 搜索二次过滤
    if (_searchQuery.isEmpty) {
      return result;
    }
    final query = _searchQuery.toLowerCase();
    final filtered = result.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.description.toLowerCase().contains(query);
    }).toList();
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);
    // 选中态使用蓝色强调色，确保深色/浅色模式都清晰可见
    const accentColor = Color(0xFF3B82F6);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _currentPage = 0;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : secondaryColor,
          ),
        ),
      ),
    );
  }

  // ---- 卡片堆叠视图 ----

  Widget _buildCardView(List<AiService> services, bool isDark) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          '没有找到匹配的服务',
          style: TextStyle(
            color: AppColors.secondaryText(isDark: isDark),
            fontSize: 14,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 自适应尺寸：根据屏幕宽度分级
    double widthFactor;
    double heightFactor;
    if (screenWidth < 360) {
      widthFactor = 0.80;
      heightFactor = 0.50;
    } else if (screenWidth > 420) {
      widthFactor = 0.65;
      heightFactor = 0.40;
    } else {
      widthFactor = 0.78;
      heightFactor = 0.45;
    }
    final cardWidth = screenWidth * widthFactor;
    final cardHeight = screenHeight * heightFactor;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: services.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final service = services[index];
              final value = (_pageController.page ?? _currentPage.toDouble()) -
                  index;
              final scale = (1.0 - value.abs() * 0.07).clamp(0.85, 1.0);
              final translateX = value * cardWidth * 0.15;
              final translateY = value.abs() * -10;
              final opacity =
                  (1.0 - value.abs() * 0.3).clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(translateX, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: GestureDetector(
                      onTap: () => _openService(service),
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _getGradientColors(service, isDark),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 主内容
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 图标 + 名称
                                  Row(
                                    children: [
                                      _buildCardIcon(service),
                                      const SizedBox(width: 12),
                                      Text(
                                        service.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 描述
                                  Text(
                                    service.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const Spacer(),
                                  // 打开按钮
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '打开 →',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // VPN 角标
                            if (service.needVpn)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'VPN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(AiService service, bool isDark) {
    final map = <String, List<Color>>{
      'Kimi': [
        const Color(0xFF1a1a3e),
        const Color(0xFF2d1b69),
      ],
      'DeepSeek': [
        const Color(0xFF0c1a3a),
        const Color(0xFF1a3a5c),
      ],
      '豆包': [
        const Color(0xFF1a2a1a),
        const Color(0xFF2a4a2a),
      ],
      '通义千问': [
        const Color(0xFF3a1a1a),
        const Color(0xFF5c2a1a),
      ],
      'ChatGPT': [
        const Color(0xFF1a1a1a),
        const Color(0xFF3a3a3a),
      ],
      'Claude': [
        const Color(0xFF2a1a1a),
        const Color(0xFF4a2a1a),
      ],
      'Gemini': [
        const Color(0xFF1a2a2a),
        const Color(0xFF2a4a4a),
      ],
    };
    return map[service.name] ??
        [
          isDark ? const Color(0xFF2a2a3a) : const Color(0xFF4a4a5a),
          isDark ? const Color(0xFF1a1a2a) : const Color(0xFF3a3a4a),
        ];
  }

  Widget _buildCardIcon(AiService service) {
    if (service.iconPath != null) {
      final path = service.iconPath!;
      final ext = path.split('.').last.toLowerCase();
      if (ext == 'svg') {
        return SvgPicture.asset(path, width: 48, height: 48);
      }
      return Image.asset(path, width: 48, height: 48, fit: BoxFit.contain);
    }
    final icon = service.resolvedIcon;
    if (icon != null) {
      return Icon(icon, size: 48, color: Colors.white);
    }
    return Icon(Icons.smart_toy_outlined, size: 48, color: Colors.white);
  }

  Future<void> _openService(AiService service) async {
    // 在任何 await 之前捕获，避免跨异步间隙使用 context
    final messenger = ScaffoldMessenger.of(context);

    await _storageService.incrementClick(service.name);
    final newCounts = await _storageService.getAllClickCounts();
    if (mounted) setState(() => _clickCounts = newCounts);

    try {
      if (service.packageName != null) {
        final installed = await _channel.invokeMethod(
            'checkAppInstalled', {'packageName': service.packageName});
        if (installed == true) {
          try {
            await _channel.invokeMethod(
                'launchApp', {'packageName': service.packageName});
            return;
          } on PlatformException catch (e) {
            debugPrint('[AiHub] launchApp failed: ${e.message}');
          }
        }
      }
      await _channel.invokeMethod('openUrl', {'url': service.url});
    } on PlatformException catch (e) {
      debugPrint('[AiHub] MethodChannel failed: ${e.message}');
      // 内置 WebView 打开失败时用系统浏览器兜底
      final uri = Uri.tryParse(service.url);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('打开失败，请检查网络后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);
    final searchBg = AppColors.searchBackground(isDark: isDark);
    final searchBorderColor = AppColors.searchBorder(isDark: isDark);
    final filtered = _filteredServices;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Hub',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _viewModeCard ? Icons.grid_view : Icons.view_carousel_outlined,
            ),
            onPressed: () {
              setState(() {
                _viewModeCard = !_viewModeCard;
                _currentPage = 0;
              });
              if (_pageController.hasClients) {
                _pageController.jumpToPage(0);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 底层：背景渐变 + 柔光圆
          Positioned.fill(child: AppBackground(isDark: isDark)),
          // 上层：原有内容
          Column(
            children: [
          // ---- Tab 栏 ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTabButton('全部', 0),
                const SizedBox(width: 8),
                _buildTabButton('国内', 1),
                const SizedBox(width: 8),
                _buildTabButton('海外', 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索 AI 服务...',
                hintStyle: TextStyle(color: secondaryColor),
                prefixIcon: Icon(Icons.search_outlined, color: secondaryColor),
                filled: true,
                fillColor: searchBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: searchBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: searchBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: searchBorderColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _viewModeCard
                ? _buildCardView(filtered, isDark)
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: secondaryColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '没有找到匹配的服务',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final service = filtered[index];
                      return _AnimatedCard(
                        key: ValueKey(service.name),
                        index: index,
                        scrollController: _scrollController,
                        child: ServiceCard(
                          service: service,
                          hasClient: _installedClients[service.name] ?? false,
                          onTap: () => _openService(service),
                        ),
                      );
                    },
                  ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 滚动入场动画包装：卡片首次进入可视区域时播放淡入 + 上滑动画
class _AnimatedCard extends StatefulWidget {
  final int index;
  final ScrollController scrollController;
  final Widget child;

  const _AnimatedCard({
    super.key,
    required this.index,
    required this.scrollController,
    required this.child,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;
  final GlobalKey _cardKey = GlobalKey();
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 持续检测可见性，直到首次触发动画（解决首帧 renderObject 未就绪问题）
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_animated || !mounted) return;
      _checkVisibility();
    });
    // 同时注册滚动监听，用于滚动停止后检查
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_animated || !mounted) return;
    // 仅在滚动停止时检查（通过 addPostFrameCallback 实现轻量节流）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _animated) return;
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (_animated || !mounted) return;
    final renderObject = _cardKey.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final box = renderObject as RenderBox;
    final cardPosition = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    // 卡片顶部进入屏幕可见区域即触发动画
    if (cardPosition.dy < screenHeight) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    if (_animated || !mounted) return;
    _animated = true;
    widget.scrollController.removeListener(_onScroll);
    // 按 index 错开动画起始时间
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: FractionalTranslation(
            translation: _slideAnim.value,
            child: child,
          ),
        );
      },
      child: SizedBox(
        key: _cardKey,
        child: widget.child,
      ),
    );
  }
}
