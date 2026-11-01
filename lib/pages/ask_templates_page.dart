import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../services/storage_service.dart';
import '../utils/ask_utils.dart';

/// 提问模板管理：新增/编辑/删除/拖动排序，改动即持久化。
/// 清空全部模板后提问行仅展示提问历史（空列表表示用户明确清空）。
class AskTemplatesPage extends StatefulWidget {
  const AskTemplatesPage({super.key});

  @override
  State<AskTemplatesPage> createState() => _AskTemplatesPageState();
}

class _AskTemplatesPageState extends State<AskTemplatesPage> {
  List<String> _templates = [];

  StorageService get _storageService =>
      Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await _storageService.getAskTemplates();
    if (!mounted) return;
    setState(() => _templates = stored ?? [...AskUtils.templates]);
  }

  Future<void> _save() => _storageService.setAskTemplates(_templates);

  Future<void> _showEditDialog({String? initial}) async {
    final isAdd = initial == null;
    final controller = TextEditingController(text: initial ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? '新增模板' : '编辑模板'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: '模板内容',
            hintText: '如：帮我写周报',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final text = controller.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模板内容不能为空')),
        );
      }
      return;
    }
    if (_templates.any((t) => t == text && t != initial)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模板已存在')),
        );
      }
      return;
    }

    setState(() {
      if (isAdd) {
        _templates.add(text);
      } else {
        final index = _templates.indexOf(initial);
        if (index >= 0) _templates[index] = text;
      }
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除「${_templates[index]}」吗？'),
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
    setState(() => _templates.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppColors.secondaryText(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '提问模板管理',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增模板',
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _templates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_edu,
                    size: 64,
                    color: secondaryColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无模板\n点击右下角按钮新增',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: secondaryColor, fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '拖动排序，点击编辑，聚焦搜索框时按此顺序展示',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _templates.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _templates.removeAt(oldIndex);
                        _templates.insert(newIndex, item);
                      });
                      _save();
                    },
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Card(
                        key: ValueKey(template),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.history_edu,
                              color: const Color(0xFF3B82F6)),
                          title: Text(template, maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          onTap: () => _showEditDialog(initial: template),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                tooltip: '删除',
                                onPressed: () => _delete(index),
                              ),
                              Icon(Icons.drag_handle,
                                  color: secondaryColor.withValues(alpha: 0.5)),
                            ],
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
