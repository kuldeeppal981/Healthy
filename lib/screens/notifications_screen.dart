import 'package:flutter/material.dart';

import '../services/social_service.dart';
import '../theme.dart';

/// Bell: friend requests and cheers on your posts.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final svc = SocialService.instance;
    svc.refresh();
    svc.pollCheers().whenComplete(svc.markCheersSeen);
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final svc = SocialService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Notifications')),
      body: AppBackground(
        child: ListenableBuilder(
          listenable: svc,
          builder: (context, _) {
            final empty = svc.requests.isEmpty && svc.cheers.isEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                if (empty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: AppColors.muted),
                        const SizedBox(height: 10),
                        Text('Nothing new',
                            style: TextStyle(color: AppColors.muted, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Friend requests and cheers show up here.',
                            style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                if (svc.requests.isNotEmpty) ...[
                  const Text('Friend requests',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final r in svc.requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(r.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            TextButton(
                              onPressed: () => svc.respond(r, false),
                              child: const Text('Decline'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                              onPressed: () => svc.respond(r, true),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
                if (svc.cheers.isNotEmpty) ...[
                  const Text('Cheers',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final c in svc.cheers.take(30))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        radius: 16,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Text(SocialService.emojiOf[c.emoji] ?? c.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${c.who} cheered',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(c.postTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(_ago(c.at),
                                style: TextStyle(color: AppColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
