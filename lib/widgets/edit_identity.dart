import 'package:flutter/material.dart';

import '../services/avatar_service.dart';
import '../services/social_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Bottom sheet to change the profile photo and the display name.
Future<void> showEditIdentity(BuildContext context, AppState s) {
  final c = TextEditingController(text: s.displayName ?? '');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your photo and name',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: AvatarService.instance,
            builder: (context, _) => Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: const AvatarCircle(size: 76),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: () async {
                          final ok = await AvatarService.instance.pick();
                          if (!ok && ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('No photo chosen.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(AvatarService.instance.file == null
                            ? 'Choose photo'
                            : 'Change photo'),
                      ),
                      if (AvatarService.instance.file != null)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                          onPressed: AvatarService.instance.remove,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('The photo stays on this phone.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: c,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Save',
            onPressed: () {
              final n = c.text.trim();
              if (n.length < 2) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter your name (at least 2 letters).')),
                );
                return;
              }
              s.setProfileName(n);
              SocialService.instance.rename(n);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  ).whenComplete(c.dispose);
}
