import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// 强制更新全屏弹窗
///
/// 当远程配置开启 force_update 且本地版本低于 minimum_allow_version 时弹出，
/// 用户只能点击下载最新版，无法关闭弹窗进入主界面。
Future<void> showForceUpdateDialog(
  BuildContext context, {
  required String latestVersion,
  required String downloadUrl,
  String updateLog = '',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本已停止使用，请更新到 v$latestVersion 后继续使用。',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (updateLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '更新内容：',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                updateLog,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              UpdateService.openExternalUrl(downloadUrl);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('下载最新版'),
          ),
        ],
      ),
    ),
  );
}
