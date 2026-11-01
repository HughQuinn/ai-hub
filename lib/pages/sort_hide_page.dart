import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../config/services_config.dart';
import '../models/ai_service.dart';
import '../services/storage_service.dart';
import 'add_platform_page.dart';

class SortHidePage extends StatefulWidget {
  const SortHidePage({super.key});

  @override
  State<SortHidePage> createState() => _SortHidePageState();
}

class _SortHidePageState extends State<SortHidePage> {
  late List<AiService> _services;
  late Set<String> _hiddenNames;

  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _services = List.from(aiServices);
    _hiddenNames = {};
    _loadData();
  }

  Future<void> _loadData() async {
    final customOrder = await _storageService.getCustomOrder();
    final hiddenList = await _storageService.getHiddenServices();
    final customPlatforms = await _storageService.getCustomPlatforms();

    // 合并内置服务和自定义服务
    final customServices = customPlatforms.map((p) {
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
      _services = [...aiServices, ...customServices];
      _hiddenNames = hiddenList.toSet();
      if (customOrder != null && customOrder.isNotEmpty) {
        // 按自定义顺序排序
        final orderMap = <String, int>{};
        for (int i = 0; i < customOrder.length; i++) {
          orderMap[customOrder[i]] = i;
        }
        _services.sort((a, b) {
          final aIndex = orderMap[a.name] ?? 999;
          final bIndex = orderMap[b.name] ?? 999;
          return aIndex.compareTo(bIndex);
        });
      }
    });
  }

  Future<void> _saveData() async {
    final order = _services.map((s) => s.name).toList();
    await _storageService.setCustomOrder(order);
    await _storageService.setHiddenServices(_hiddenNames.toList());
  }

  void _toggleVisibility(AiService service) {
    setState(() {
      if (_hiddenNames.contains(service.name)) {
        _hiddenNames.remove(service.name);
      } else {
        _hiddenNames.add(service.name);
      }
    });
    _saveData();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _services.removeAt(oldIndex);
      _services.insert(newIndex, item);
    });
    _saveData();
  }

  /// 编辑自定义平台，返回后重新加载列表
  Future<void> _editCustomPlatform(AiService service) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlatformPage(editName: service.name),
      ),
    );
    if (!mounted) return;
    _loadData();
  }

  /// 删除自定义平台，同时清理隐藏列表和排序中的残留
  Future<void> _deleteCustomPlatform(AiService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除平台'),
        content: Text('确定删除自定义平台「${service.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final platforms = await _storageService.getCustomPlatforms();
    platforms.removeWhere((p) => p['name'] == service.name);
    await _storageService.saveCustomPlatforms(platforms);

    if (!mounted) return;
    setState(() {
      _services.removeWhere((s) => s.name == service.name);
      _hiddenNames.remove(service.name);
    });
    await _saveData();
  }

  Widget _buildIcon(AiService service, bool isDark) {
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
      return Icon(icon, size: 48, color: AppColors.secondaryText(isDark: isDark));
    }
    return Icon(
      Icons.smart_toy_outlined,
      size: 48,
      color: AppColors.secondaryText(isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('排序/隐藏平台'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // 提示文字
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '拖动排序，点击眼睛图标隐藏/显示服务',
              style: TextStyle(
                fontSize: 13,
                color: secondaryColor,
              ),
            ),
          ),
          // 列表
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _services.length,
              onReorderItem: _onReorder,
              itemBuilder: (context, index) {
                final service = _services[index];
                final isHidden = _hiddenNames.contains(service.name);

                return Card(
                  key: ValueKey(service.name),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Opacity(
                    opacity: isHidden ? 0.4 : 1.0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      leading: _buildIcon(service, isDark),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 编辑按钮（仅自定义平台）
                          if (service.isCustom)
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blueAccent,
                              ),
                              tooltip: '编辑',
                              onPressed: () => _editCustomPlatform(service),
                            ),
                          // 删除按钮（仅自定义平台）
                          if (service.isCustom)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              tooltip: '删除',
                              onPressed: () => _deleteCustomPlatform(service),
                            ),
                          // 眼睛图标
                          IconButton(
                            icon: Icon(
                              isHidden
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: isHidden ? Colors.grey : secondaryColor,
                            ),
                            onPressed: () => _toggleVisibility(service),
                          ),
                          // 拖拽手柄
                          Icon(
                            Icons.drag_handle,
                            color: isHidden
                                ? Colors.grey
                                : secondaryColor.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
