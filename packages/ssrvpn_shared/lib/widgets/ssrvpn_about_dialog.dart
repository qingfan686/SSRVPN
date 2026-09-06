import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'ssrvpn_info_dialog.dart';

Future<void> showSsrvpnAboutDialog(
  BuildContext context, {
  VoidCallback? onCheckForUpdate,
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '版本 ${AppConstants.appVersion}',
              style: TextStyle(color: accentText),
            ),
            if (onCheckForUpdate != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('ssrvpn-check-update-button'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    onCheckForUpdate();
                  },
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('检查更新'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '客户端地址',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'https://github.com/qingfan686/SSRVPN',
              style: TextStyle(color: accentText),
            ),
            const SizedBox(height: 16),
            const Text(
              '公告',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '清凡VPN 致力于为用户提供稳定、快速的网络加速服务。\n'
              '本软件完全免费，请勿用于商业用途。\n'
              '使用过程中如有问题，请联系作者反馈。',
              style: TextStyle(color: secondaryText, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              '作者：清凡',
              style: TextStyle(color: secondaryText),
            ),
          ],
        );
      },
    ),
  );
}
