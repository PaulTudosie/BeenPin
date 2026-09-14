import 'package:flutter/material.dart';
import 'auth_scope.dart';

class AccountDialog extends StatelessWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AuthScope.of(context);
    final profile = controller.profile;
    return AlertDialog(
      title: const Text('Account'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile?.displayName ?? ''),
            Text('@${profile?.username ?? ''}'),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(controller.errorMessage!),
            ],
          ]),
      actions: [
        TextButton(
            onPressed:
                controller.busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Close')),
        FilledButton(
            onPressed: controller.busy ? null : controller.signOut,
            child: Text(controller.busy ? 'Signing out…' : 'Sign out')),
      ],
    );
  }
}
