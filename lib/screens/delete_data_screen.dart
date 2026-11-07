import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Delete data or the account. Kept on its own screen so it is hard to hit by accident.
class DeleteDataScreen extends StatelessWidget {
  const DeleteDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Delete data or account')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('These actions cannot be undone. Export your data first from the Privacy dashboard if you want a copy.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete all data?'),
                    content: const Text(
                        'Your profile, allergies, diary and workouts will be removed from this phone and your account.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  await s.clearAll(deleteCloud: true);
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
              child: const Text('Delete all data'),
            ),
            if (s.signedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete your account?'),
                      content: const Text(
                          'This permanently deletes your account, friends, posts and all saved data. It cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete account')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final done = await s.deleteAccount();
                  if (!context.mounted) return;
                  if (done) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not delete the account. Try again later.')),
                    );
                  }
                },
                child: const Text('Delete account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
