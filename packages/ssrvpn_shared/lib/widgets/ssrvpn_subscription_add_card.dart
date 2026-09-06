part of 'ssrvpn_subscription_view.dart';

class _SubscriptionAddCard extends StatelessWidget {
  const _SubscriptionAddCard({
    required this.urlController,
    required this.inputFocusNode,
    required this.addActionKey,
    required this.isAdding,
    required this.isBusy,
    required this.onAdd,
  });

  final TextEditingController urlController;
  final FocusNode inputFocusNode;
  final GlobalKey addActionKey;
  final bool isAdding;
  final bool isBusy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
