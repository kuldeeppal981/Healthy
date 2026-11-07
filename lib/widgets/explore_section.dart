import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/hub_screens.dart';
import '../services/l10n.dart';
import '../state/app_state.dart';
import '../theme.dart';

class _Tile {
  final String id;
  final String label;
  final String sub;
  final IconData icon;
  const _Tile(this.id, this.label, this.sub, this.icon);
}

const _allTiles = [
  _Tile('nutrition', 'Nutrition', 'Meals and macros', Icons.restaurant_outlined),
  _Tile('health', 'Health', 'Reports and conditions', Icons.favorite_border),
  _Tile('library', 'Library', 'Exercises and training', Icons.menu_book_outlined),
  _Tile('community', 'Community', 'Friends and privacy', Icons.groups_outlined),
  _Tile('plan', 'Daily plan', 'Today and the week', Icons.event_note_outlined),
  _Tile('challenges', 'Challenges', 'Missions and streaks', Icons.emoji_events_outlined),
];

/// "Explore your fitness": 2x3 shortcut tiles, each opens a hub with tabs.
class ExploreSection extends StatelessWidget {
  final void Function(int tab) onGoto;
  const ExploreSection({super.key, required this.onGoto});

  List<_Tile> _order(AppState s) {
    final saved = s.prefs['explore'];
    if (saved is List) {
      final ids = saved.map((e) => e.toString()).toList();
      final out = <_Tile>[
        for (final id in ids)
          for (final t in _allTiles)
            if (t.id == id) t,
      ];
      if (out.isNotEmpty) return out;
    }
    return _allTiles;
  }

  Widget _page(String id) {
    switch (id) {
      case 'nutrition':
        return nutritionHub(onGoto);
      case 'health':
        return healthHub();
      case 'library':
        return libraryHub();
      case 'community':
        return communityHub();
      case 'plan':
        return dailyPlanHub(onGoto);
      default:
        return challengesHub();
    }
  }

  void _customize(BuildContext context, AppState s) {
    final chosen = _order(s).map((t) => t.id).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customize shortcuts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Pick which ones show on Home.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                for (final t in _allTiles)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    secondary: Icon(t.icon, color: AppColors.primary),
                    title: Text(t.label),
                    value: chosen.contains(t.id),
                    onChanged: (v) {
                      setM(() {
                        if (v == true) {
                          if (!chosen.contains(t.id)) chosen.add(t.id);
                        } else if (chosen.length > 1) {
                          chosen.remove(t.id);
                        }
                      });
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          final next = Map<String, dynamic>.from(s.prefs)..remove('explore');
                          s.savePrefs(next);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () {
                          final ordered = [
                            for (final t in _allTiles)
                              if (chosen.contains(t.id)) t.id,
                          ];
                          final next = Map<String, dynamic>.from(s.prefs)..['explore'] = ordered;
                          s.savePrefs(next);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tiles = _order(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr('Explore your fitness'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () => _customize(context, s),
              child: Text(tr('Customize'), style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            for (final t in tiles)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => _page(t.id))),
                child: AppCard(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(t.icon, color: AppColors.primary, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(t.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            Text(tr(t.sub),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
