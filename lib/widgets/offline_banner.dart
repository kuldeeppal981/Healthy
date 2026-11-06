import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Shows a small note when the last backup did not go through (no internet).
/// Everything keeps working: data is saved on the phone and sent later.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.signedIn || s.syncError == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: AppColors.warnBg,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warnInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.syncing
                    ? 'Trying to back up...'
                    : 'Offline? Saved on this phone. It will back up when you are online.',
                style: TextStyle(fontSize: 12, color: AppColors.warnInk),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
              onPressed: s.syncing ? null : () => s.syncAfterLogin(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
