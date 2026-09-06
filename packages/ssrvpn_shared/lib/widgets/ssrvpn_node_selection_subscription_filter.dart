part of 'ssrvpn_node_selection_page.dart';

class _SubscriptionFilter extends StatelessWidget {
  const _SubscriptionFilter({
    required this.groups,
    required this.value,
    required this.sortByLatency,
    required this.onChanged,
    required this.onSortPressed,
  });

  final List<String> groups;
  final String value;
  final bool sortByLatency;
  final ValueChanged<String> onChanged;
  final VoidCallback onSortPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        key: const Key('ssrvpn-node-latency-sort'),
        tooltip: sortByLatency ? '恢复默认节点顺序' : '按延迟从低到高排序',
        onPressed: onSortPressed,
        color: sortByLatency
            ? SsrvpnUiTokens.primary
            : SsrvpnUiTokens.textSecondary,
        icon: Icon(
          sortByLatency
              ? Icons.filter_list_off_rounded
              : Icons.sort_rounded,
        ),
      ),
    );
  }
}
