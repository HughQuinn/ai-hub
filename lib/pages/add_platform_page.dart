import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../config/icons_config.dart';
import '../config/services_config.dart';
import '../services/storage_service.dart';

class AddPlatformPage extends StatefulWidget {
  /// 传入要编辑的自定义平台名称时进入编辑模式，null 为新增模式。
  final String? editName;

  const AddPlatformPage({super.key, this.editName});

  @override
  State<AddPlatformPage> createState() => _AddPlatformPageState();
}

class _AddPlatformPageState extends State<AddPlatformPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();

  IconData _selectedIcon = Icons.smart_toy_outlined;
  String _selectedRegion = 'domestic';
  List<Map<String, dynamic>> _existingPlatforms = [];
  bool _isSaving = false;
  bool _isCooldown = false;
  bool _loaded = false;
  Timer? _cooldownTimer;

  bool get _isEditing => widget.editName != null;

  final _presetIcons = presetIcons;

  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _loadExistingPlatforms();
  }

  Future<void> _loadExistingPlatforms() async {
    final platforms = await _storageService.getCustomPlatforms();
    if (!mounted) return;
    setState(() {
      _existingPlatforms = platforms;
      // 编辑模式下用既有数据预填表单（仅执行一次）
      if (!_loaded && _isEditing) {
        _loaded = true;
        final source = platforms
            .where((p) => p['name'] == widget.editName)
            .firstOrNull;
        if (source != null) {
          _nameController.text = source['name'] as String? ?? '';
          _urlController.text = source['url'] as String? ?? '';
          final desc = source['description'] as String?;
          if (desc != null && desc != '自定义平台') {
            _descController.text = desc;
          }
          _selectedIcon =
              getIconByName(source['iconName'] as String? ?? '') ??
                  Icons.smart_toy_outlined;
          _selectedRegion = source['region'] as String? ?? 'domestic';
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _descController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _isCooldown = true);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isCooldown = false);
      }
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入平台名称';
    }
    final name = value.trim();
    // 编辑模式下名称未变时不算重复
    if (name == widget.editName) {
      return null;
    }
    // 检查内置服务名称
    if (aiServices.any((s) => s.name == name)) {
      return '该名称已存在';
    }
    // 检查自定义服务名称
    if (_existingPlatforms.any((p) => p['name'] == name)) {
      return '该名称已存在';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving || _isCooldown) return;
    if (!_formKey.currentState!.validate()) {
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请检查输入内容')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final iconName = getIconName(_selectedIcon);
      final platform = {
        'name': _nameController.text.trim(),
        'url': _urlController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? '自定义平台'
            : _descController.text.trim(),
        'iconName': iconName,
        'region': _selectedRegion,
      };

      final customPlatforms = await _storageService.getCustomPlatforms();
      if (_isEditing) {
        // 原位替换，保持用户在排序页自定义的位置
        final index =
            customPlatforms.indexWhere((p) => p['name'] == widget.editName);
        if (index >= 0) {
          customPlatforms[index] = platform;
        } else {
          customPlatforms.add(platform);
        }
      } else {
        customPlatforms.add(platform);
      }
      await _storageService.saveCustomPlatforms(customPlatforms);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '修改已保存' : '保存成功')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);
    final primaryTextColor = AppColors.primaryText(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑自定义平台' : '添加自定义平台'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称输入框
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText: '请输入平台名称',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: secondaryColor),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),

              // URL 输入框
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: '请输入网址，如 https://example.com',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: secondaryColor),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入网址';
                  }
                  final url = value.trim();
                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    return '网址格式不正确';
                  }
                  // 前缀合法但缺主机名（如 http://）同样无法访问，一并拒绝
                  final uri = Uri.tryParse(url);
                  if (uri == null || uri.host.isEmpty) {
                    return '网址格式不正确';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 描述输入框
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: '描述',
                  hintText: '一句话描述（选填）',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: secondaryColor),
                ),
              ),
              const SizedBox(height: 24),

              // 图标选择
              Text(
                '选择图标',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: _presetIcons.length,
                itemBuilder: (context, index) {
                  final icon = _presetIcons[index];
                  final isSelected = _selectedIcon == icon;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: isSelected ? Colors.blue : secondaryColor,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 分类选择
              Text(
                '选择分类',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRegionCard('domestic', '国内', secondaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRegionCard('overseas', '海外', secondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isCooldown) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCooldown ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isCooldown
                              ? '请稍候...'
                              : (_isEditing ? '保存修改' : '保存'),
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionCard(String region, String label, Color secondaryColor) {
    final isSelected = _selectedRegion == region;

    return GestureDetector(
      onTap: () => setState(() => _selectedRegion = region),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : secondaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
