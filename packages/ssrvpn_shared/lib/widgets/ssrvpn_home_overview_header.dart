part of 'ssrvpn_home_overview.dart';

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.compact,
    required this.onShowAbout,
    required this.onShowTutorial,
  });

  final bool compact;
  final VoidCallback onShowAbout;
  final VoidCallback onShowTutorial;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final actionWidth = (constraints.maxWidth * .24).clamp(48.0, 92.0);
        final style = TextButton.styleFrom(
            foregroundColor: SsrvpnUiTokens.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 48));
        return Row(children: [
          SizedBox(
              width: actionWidth,
              child: Tooltip(
                  message: '关于',
                  child: TextButton(
                      key: const Key('ssrvpn-about-button'),
                      onPressed: onShowAbout,
                      style: style,
                      child: const SsrvpnHomeText('关于',
                          textAlign: TextAlign.center, maxFontSize: 20)))),
          Expanded(
              child: SsrvpnHomeText('清凡VPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: SsrvpnUiTokens.textPrimary,
                      fontSize: compact ? 29 : 34,
                      fontWeight: FontWeight.w400),
                  minFontSize: 20)),
          SizedBox(
              width: actionWidth,
              child: Tooltip(
                  message: '使用教程',
                  child: TextButton(
                      key: const Key('ssrvpn-tutorial-button'),
                      onPressed: onShowTutorial,
                      style: style,
                      child: const SsrvpnHomeText('使用教程',
                          textAlign: TextAlign.center, maxFontSize: 20)))),
        ]);
      });
}
