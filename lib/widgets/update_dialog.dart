import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';

/// OTA 更新提示弹窗：展示新版本号与更新说明，可跳转系统浏览器下载。
/// 「忽略此版本」会记录版本号，启动时的自动检查将跳过该版本。
Future<void> showUpdateDialog(
  BuildContext context,
  Map<String, dynamic> update,
) {
  final latestVersion = update['latestVersion'] as String? ?? '';
  final downloadUrl = update['downloadUrl'] as String? ?? '';
  final releaseNotes = update['releaseNotes'] as String? ?? '';

  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final messenger = ScaffoldMessenger.of(dialogCtx);
      return AlertDialog(
        title: Text('发现新版本 v$latestVersion'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              releaseNotes.isEmpty ? '新版本已发布，是否前往下载？' : releaseNotes,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('稍后再说'),
          ),
          if (latestVersion.isNotEmpty)
            TextButton(
              onPressed: () async {
                // 写入忽略记录后关闭，启动检查不再提示该版本
                final storage = dialogCtx.read<StorageService>();
                await storage.setIgnoredUpdateVersion(latestVersion);
                if (!dialogCtx.mounted) return;
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('忽略此版本'),
            ),
          if (downloadUrl.isNotEmpty)
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final uri = Uri.tryParse(downloadUrl);
                if (uri == null) return;
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('打开下载链接失败，请稍后重试')),
                  );
                }
              },
              child: const Text('前往下载'),
            ),
        ],
      );
    },
  );
}
