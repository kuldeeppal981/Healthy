import 'package:flutter/material.dart';

import '../screens/meal_photo_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/search_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'add_food_sheet.dart';
import 'ui_kit.dart';
import 'voice_review.dart';
import 'weight_dialog.dart';

/// The big "+" button: log anything from one place.
Future<void> showQuickAdd(
  BuildContext context,
  AppState s, {
  required void Function(int tab) onGoto,
}) {
  // [context] belongs to the page below the sheet, so it stays valid after
  // the sheet closes.
  Widget tile(BuildContext ctx, IconData icon, String label, VoidCallback action) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(ctx);
          // Let the sheet finish closing before opening the next thing.
          Future<void>.delayed(const Duration(milliseconds: 180), () {
            if (context.mounted) action();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.chipBg.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                tile(ctx, Icons.restaurant, 'Food', () => showAddFoodSheet(context)),
                tile(ctx, Icons.qr_code_scanner, 'Scan', () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
                  );
                }),
                tile(ctx, Icons.mic, 'Voice', () => logByVoice(context)),
                tile(ctx, Icons.photo_camera_outlined, 'Meal photo', () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MealPhotoScreen()),
                  );
                }),
                tile(ctx, Icons.water_drop, 'Water', () {
                  Haptic.splash();
                  s.addWater(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Water: ${s.waterToday} of ${s.waterTarget} glasses')),
                  );
                }),
                tile(ctx, Icons.fitness_center, 'Workout', () => onGoto(2)),
                tile(ctx, Icons.monitor_weight_outlined, 'Weight', () => showLogWeight(context, s)),
                tile(ctx, Icons.verified_outlined, 'Check in', () {
                  if (!s.checkedInToday) {
                    Haptic.done();
                    s.checkIn();
                  }
                }),
                tile(ctx, Icons.search, 'Search', () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SearchScreen(onGoto: onGoto)),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
