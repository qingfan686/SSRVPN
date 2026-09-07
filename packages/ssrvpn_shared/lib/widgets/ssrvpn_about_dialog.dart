import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'ssrvpn_info_dialog.dart';

Future<void> showSsrvpnAboutDialog(
  BuildContext context, {
  VoidCallback? onCheckForUpdate,
  VoidCallback? onShowPerAppProxy,
  String announcementText = '暂无公告，请联网后查看最新公告。',
  bool showDownloadButton = true,
  bool hasNewVersion = false,
  String clientUrlLabel = '客户端地址',
  String clientUrl = 'https://github.com/qingfan686/SSRVPN',
}) {
  return showSsrvpnInfoDialog(
    context,
    panelKey: const Key('ssrvpn-about-glass'),
    scrollKey: const Key('ssrvpn-about-scroll'),
    icon: Icons.vpn_lock_rounded,
    title: '关于 清凡VPN',
    content: Builder(
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        final secondaryText = colors.onSurfaceVariant;
        final accentText = theme.brightness == Brightness.dark
            ? Color.lerp(colors.primary, Colors.white, 0.40)!
            : Color.lerp(colors.primary, Colors.black, 0.16)!;
        return _AboutDialogContent(
          secondaryText: secondaryText,
          accentText: accentText,
          announcementText: announcementText,
          showDownloadButton: showDownloadButton,
          hasNewVersion: hasNewVersion,
          clientUrlLabel: clientUrlLabel,
          clientUrl: clientUrl,
          onCheckForUpdate: onCheckForUpdate,
          onShowPerAppProxy: onShowPerAppProxy,
        );
      },
    ),
  );
}

class _AboutDialogContent extends StatefulWidget {
  final Color secondaryText;
  final Color accentText;
  final String announcementText;
  final bool showDownloadButton;
  final bool hasNewVersion;
  final String clientUrlLabel;
  final String clientUrl;
  final VoidCallback? onCheckForUpdate;
  final VoidCallback? onShowPerAppProxy;

  const _AboutDialogContent({
    required this.secondaryText,
    required this.accentText,
    required this.announcementText,
    required this.showDownloadButton,
    required this.hasNewVersion,
    required this.clientUrlLabel,
    required this.clientUrl,
    required this.onCheckForUpdate,
    required this.onShowPerAppProxy,
  });

  @override
  State<_AboutDialogContent> createState() => _AboutDialogContentState();
}

class _AboutDialogContentState extends State<_AboutDialogContent> {
  bool _downloadClicked = false;

  @override
  Widget build(BuildContext context) {
    final canClose = !widget.hasNewVersion || _downloadClicked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '版本 ${AppConstants.appVersion}',
          style: TextStyle(color: widget.accentText),
        ),
        if (widget.hasNewVersion && !_downloadClicked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '检测到新版本，请点击下方【下载最新版】前往更新',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.showDownloadButton && widget.onCheckForUpdate != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('ssrvpn-check-update-button'),
              onPressed: () {
                setState(() => _downloadClicked = true);
                widget.onCheckForUpdate!();
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: Text(
                widget.hasNewVersion ? '下载最新版（必须点击）' : '下载最新版',
              ),
            ),
          ),
        ],
        if (widget.onShowPerAppProxy != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('ssrvpn-per-app-proxy-button'),
              onPressed: () {
                Navigator.pop(context);
                widget.onShowPerAppProxy!();
              },
              icon: const Icon(Icons.apps_rounded),
              label: const Text('应用分流'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          widget.clientUrlLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        SelectableText(
          widget.clientUrl,
          style: TextStyle(color: widget.accentText),
        ),
        const SizedBox(height: 16),
        const Text(
          '公告',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          widget.announcementText,
          style: TextStyle(color: widget.secondaryText, height: 1.45),
        ),
        const SizedBox(height: 16),
        Text(
          '作者：清凡',
          style: TextStyle(color: widget.secondaryText),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: canClose
                ? () => Navigator.pop(context)
                : null,
            child: Text(
              canClose ? '知道了' : '请先点击下载最新版',
              style: TextStyle(
                color: canClose ? null : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
