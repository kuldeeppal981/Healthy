import 'package:flutter/material.dart';

import '../screens/pro_screen.dart';
import '../theme.dart';

/// Friendly sheet when the daily AI limit is used up.
void showProLimitSheet(BuildContext context, String message) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary, size: 40),
            const SizedBox(height: 10),
            const Text('Today\'s free AI requests are done',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const ProScreen()));
              },
              child: const Text('See Healthy Pro'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Maybe later')),
          ],
        ),
      ),
    ),
  );
}
