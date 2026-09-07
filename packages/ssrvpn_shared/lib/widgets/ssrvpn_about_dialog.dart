import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

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
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _AboutDialog(
      announcementText: announcementText,
      showDownloadButton: showDownloadButton,
      hasNewVersion: hasNewVersion,
      clientUrlLabel: clientUrlLabel,
      clientUrl: clientUrl,
      onCheckForUpdate: onCheckForUpdate,
      onShowPerAppProxy: onShowPerAppProxy,
    ),
  );
}

class _AboutDialog extends StatefulWidget {
  final String announcementText;
  final bool showDownloadButton;
  final bool hasNewVersion;
  final String clientUrlLabel;
  final String clientUrl;
  final VoidCallback? onCheckForUpdate;
  final VoidCallback? onShowPerAppProxy;

  const _AboutDialog({
    required this.announcementText,
    required this.showDownloadButton,
    required this.hasNewVersion,
    required this.clientUrlLabel,
    required this.clientUrl,
    required this.onCheckForUpdate,
    required this.onShowPerAppProxy,
  });

  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  bool _downloadClicked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final secondaryText = colors.onSurfaceVariant;
    final accentText = theme.brightness == Brightness.dark
        ? Color.lerp(colors.primary, Colors.white, 0.40)!
        : Color.lerp(colors.primary, Colors.black, 0.16)!;
    final isDark = theme.brightness == Brightness.dark;
    final canClose = !widget.hasNewVersion || _downloadClicked;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceContainerHigh.withValues(alpha: 0.92)
                    : colors.surfaceContainerHigh.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.tertiary],
                      ),
                    ),
                    child: Icon(
                      Icons.vpn_lock_rounded,
                      color: colors.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '关于 清凡VPN',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '版本 ${AppConstants.appVersion}',
                            style: TextStyle(color: accentText),
                          ),
                          if (widget.hasNewVersion && !_downloadClicked) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '检测到新版本，请点击下方【下载最新版】前往更新',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.showDownloadButton &&
                              widget.onCheckForUpdate != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('ssrvpn-check-update-button'),
                                onPressed: () {
                                  setState(() => _downloadClicked = true);
                                  widget.onCheckForUpdate!();
                                },
                                icon:
                                    const Icon(Icons.system_update_alt_rounded),
                                label: Text(widget.hasNewVersion
                                    ? '下载最新版（必须点击）'
                                    : '下载最新版'),
                              ),
                            ),
                          ],
                          if (widget.onShowPerAppProxy != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key:
                                    const Key('ssrvpn-per-app-proxy-button'),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            widget.clientUrl,
                            style: TextStyle(color: accentText),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '公告',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.announcementText,
                            style: TextStyle(
                                color: secondaryText, height: 1.45),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '作者：清凡',
                            style: TextStyle(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: canClose
                          ? () => Navigator.pop(context)
                          : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: colors.primary.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        foregroundColor: colors.onSurface,
                        disabledForegroundColor:
                            colors.onSurface.withValues(alpha: 0.4),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(canClose ? '知道了' : '请先点击下载最新版'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
