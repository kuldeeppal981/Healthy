import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/community_service.dart';
import '../services/social_service.dart';
import '../theme.dart';

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget _empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      ),
    );

Future<String?> _askText(BuildContext context, String title, String hint, {int max = 40}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        maxLength: max,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Weekly league, groups, accountability partner and buddy matching.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('League and groups'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'League'),
              Tab(text: 'Groups'),
              Tab(text: 'Partner'),
              Tab(text: 'Buddies'),
            ],
          ),
        ),
        body: AppBackground(
          child: ListenableBuilder(
            listenable: SocialService.instance,
            builder: (context, _) {
              final soc = SocialService.instance;
              if (!soc.available || !soc.enabled) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _empty(
                      'Turn on Friends first (Community, Friends). Then the league, groups and partner work.'),
                );
              }
              return const TabBarView(
                children: [_LeagueTab(), _GroupsTab(), _PartnerTab(), _BuddyTab()],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---- League ----

class _LeagueList extends StatelessWidget {
  final List<LeagueRow> rows;
  const _LeagueList(this.rows);

  @override
  Widget build(BuildContext context) {
    if (rows.length <= 1) {
      return _empty('Add friends or join a group to compete.');
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              radius: 16,
              color: rows[i].isMe ? AppColors.chipBg : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(i == 0 ? '1' : '${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? AppColors.primary : AppColors.muted)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].isMe ? '${rows[i].name} (you)' : rows[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${rows[i].workouts} workouts  |  ${rows[i].steps} steps',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Text('${rows[i].points} pts',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _pointsNote =
    'Points over the last 7 days: 20 for each workout day, 5 for each day you log food, 2 for every 1000 steps (up to 20000 a day).';

class _LeagueTab extends StatefulWidget {
  const _LeagueTab();
  @override
  State<_LeagueTab> createState() => _LeagueTabState();
}

class _LeagueTabState extends State<_LeagueTab> {
  late Future<List<LeagueRow>> _f = CommunityService.weeklyLeague();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _f = CommunityService.weeklyLeague());
        await _f;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text('Weekly league',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('You and your friends.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          FutureBuilder<List<LeagueRow>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) return _empty('Could not load. Pull down to try again.');
              return _LeagueList(snap.data ?? const []);
            },
          ),
          const SizedBox(height: 6),
          Text(_pointsNote, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// ---- Groups ----

class _GroupsTab extends StatefulWidget {
  const _GroupsTab();
  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  late Future<List<GroupInfo>> _f = CommunityService.myGroups();

  void _reload() => setState(() => _f = CommunityService.myGroups());

  Future<void> _create() async {
    final n = await _askText(context, 'New group', 'Group name');
    if (n == null || n.length < 2) return;
    final e = await CommunityService.createGroup(n);
    if (!mounted) return;
    if (e != null) _snack(context, e);
    _reload();
  }

  Future<void> _join() async {
    final c = await _askText(context, 'Join a group', 'Invite code', max: 8);
    if (c == null || c.isEmpty) return;
    final e = await CommunityService.joinGroup(c);
    if (!mounted) return;
    _snack(context, e ?? 'Joined.');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _join,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Join with code'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<GroupInfo>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                  padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final list = snap.data ?? const <GroupInfo>[];
            if (list.isEmpty) {
              return _empty('No groups yet. Create one and share the code with your gym friends.');
            }
            return Column(
              children: [
                for (final g in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => GroupDetailScreen(group: g)));
                        if (mounted) _reload();
                      },
                      child: AppCard(
                        radius: 20,
                        child: Row(
                          children: [
                            Icon(Icons.groups_outlined, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 16)),
                                  Text('${g.members} members${g.isOwner ? '  |  you own it' : ''}',
                                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
            'Only group members can see the group. Members see each other\'s league points, steps and workout days, never food, weight or allergies.',
            style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final GroupInfo group;
  const GroupDetailScreen({super.key, required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<List<LeagueRow>> _board = CommunityService.groupLeague(widget.group.id);
  late Future<List<GroupChallenge>> _ch = CommunityService.groupChallenges(widget.group.id);

  void _reload() => setState(() {
        _board = CommunityService.groupLeague(widget.group.id);
        _ch = CommunityService.groupChallenges(widget.group.id);
      });

  void _invite() {
    final g = widget.group;
    Share.share(
        'Join my group "${g.name}" on Healthy. Open Healthy, go to Explore, Community, League and groups, tap Groups, Join with code, and enter ${g.code}.');
  }

  Future<void> _newChallenge() async {
    final name = await _askText(context, 'New group challenge', 'Name');
    if (name == null || name.length < 2 || !mounted) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in const [
              ['steps', 'Step competition'],
              ['workouts', 'Workout days'],
              ['transform', 'Transformation points'],
            ])
              ListTile(title: Text(k[1]), onTap: () => Navigator.pop(ctx, k[0])),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in const [7, 14, 30])
              ListTile(title: Text('$d days'), onTap: () => Navigator.pop(ctx, d)),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    final e = await CommunityService.createGroupChallenge(widget.group.id, name, kind, days);
    if (!mounted) return;
    if (e != null) _snack(context, e);
    _reload();
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    await CommunityService.leaveGroup(widget.group.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(g.name)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invite code', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        Text(g.code,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _invite,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Invite'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('This week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            FutureBuilder<List<LeagueRow>>(
              future: _board,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return _empty('Could not load.');
                return _LeagueList(snap.data ?? const []);
              },
            ),
            Text(_pointsNote, style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Group challenges',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: _newChallenge,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
            FutureBuilder<List<GroupChallenge>>(
              future: _ch,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <GroupChallenge>[];
                if (list.isEmpty) return _empty('No challenges yet. Start one for the group.');
                return Column(
                  children: [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          radius: 16,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                        '${c.kind}  |  ends ${c.end.day}/${c.end.month}',
                                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              if (c.joined)
                                Icon(Icons.check_circle, color: AppColors.primary)
                              else
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                                  onPressed: () async {
                                    final e = await CommunityService.joinGroupChallenge(c.id);
                                    if (!mounted) return;
                                    if (e != null) _snack(context, e);
                                    _reload();
                                  },
                                  child: const Text('Join'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Text('Scores show in Friends, Challenges after you join.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            TextButton(onPressed: _leave, child: const Text('Leave group')),
          ],
        ),
      ),
    );
  }
}

// ---- Accountability partner ----

class _PartnerTab extends StatefulWidget {
  const _PartnerTab();
  @override
  State<_PartnerTab> createState() => _PartnerTabState();
}

class _PartnerTabState extends State<_PartnerTab> {
  late Future<PartnerInfo?> _f = CommunityService.myPartner();

  void _reload() => setState(() => _f = CommunityService.myPartner());

  Future<void> _pick() async {
    final friends = SocialService.instance.board.where((b) => !b.isMe).toList();
    if (friends.isEmpty) {
      _snack(context, 'Add a friend first.');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pick your partner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final f in friends)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(f.name),
                onTap: () => Navigator.pop(ctx, f.userId),
              ),
          ],
        ),
      ),
    );
    if (id == null || !mounted) return;
    final e = await CommunityService.requestPartner(id);
    if (!mounted) return;
    _snack(context, e ?? 'Request sent. They need to accept it.');
    _reload();
  }

  Widget _tick(bool on, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(on ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18, color: on ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text('Accountability partner',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('One friend who keeps you on track. You see each other\'s daily check-in, nothing else.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        FutureBuilder<PartnerInfo?>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = snap.data;
            if (p == null) {
              return Column(
                children: [
                  _empty('You do not have a partner yet.'),
                  GradientButton(label: 'Choose a partner', icon: Icons.handshake_outlined, onPressed: _pick),
                ],
              );
            }
            if (!p.active && p.incoming) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} wants to be your accountability partner.',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: () async {
                              await CommunityService.respondPartner(p.other, true);
                              _reload();
                            },
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: () async {
                              await CommunityService.respondPartner(p.other, false);
                              _reload();
                            },
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            if (!p.active) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waiting for ${p.name} to accept.',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () async {
                        await CommunityService.endPartner();
                        _reload();
                      },
                      child: const Text('Cancel request'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.name} today',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _tick(p.loggedToday, 'Logged food'),
                      _tick(p.workoutToday, 'Worked out'),
                      _tick(p.stepsToday > 0, '${p.stepsToday} steps'),
                      const Divider(height: 24),
                      Text('Active days in the last 7:  you ${p.myDays}  |  ${p.name} ${p.theirDays}',
                          style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () async {
                          final r = await SocialService.instance.nudge(p.other);
                          if (mounted) _snack(context, r);
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 18),
                        label: const Text('Nudge'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () async {
                          await CommunityService.endPartner();
                          _reload();
                        },
                        child: const Text('End partnership'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---- Buddy matching ----

class _BuddyTab extends StatefulWidget {
  const _BuddyTab();
  @override
  State<_BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<_BuddyTab> {
  static const _goals = {
    'lose': 'Lose weight',
    'muscle': 'Build muscle',
    'fit': 'Stay fit',
    'steps': 'Walk more',
  };
  static const _levels = {'any': 'Any', 'beginner': 'Beginner', 'regular': 'Regular', 'advanced': 'Advanced'};
  static const _slots = {'any': 'Any time', 'morning': 'Morning', 'evening': 'Evening', 'night': 'Night'};

  String _goal = 'fit';
  String _level = 'any';
  String _slot = 'any';
  bool _looking = true;
  bool _saved = false;
  bool _loading = true;
  List<Buddy>? _matches;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await CommunityService.myBuddyProfile();
      if (p != null) {
        _goal = p['goal'] as String;
        _level = p['level'] as String;
        _slot = p['slot'] as String;
        _looking = p['looking'] as bool;
        _saved = true;
        _matches = await CommunityService.findBuddies();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final e = await CommunityService.saveBuddyProfile(_goal, _level, _slot, _looking);
    if (!mounted) return;
    if (e != null) {
      _snack(context, e);
      return;
    }
    _saved = true;
    final soc = SocialService.instance;
    if (!soc.discoverable) {
      _snack(context, 'Saved. Turn on "Others can find me" in the Privacy dashboard so buddies can see you.');
    }
    try {
      _matches = await CommunityService.findBuddies();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _chips(String title, Map<String, String> opts, String cur, void Function(String) on) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in opts.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: cur == e.key,
                  selectedColor: AppColors.chipBg,
                  onSelected: (_) => setState(() => on(e.key)),
                ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text('Find a workout buddy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Optional. Others with the same goal can find you, only if you turn this on and allow "Others can find me".',
            style: TextStyle(color: AppColors.muted)),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chips('My goal', _goals, _goal, (v) => _goal = v),
              _chips('My level', _levels, _level, (v) => _level = v),
              _chips('Usual time', _slots, _slot, (v) => _slot = v),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show me to buddies', style: TextStyle(fontWeight: FontWeight.w700)),
                value: _looking,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _looking = v),
              ),
              GradientButton(label: _saved ? 'Update and find' : 'Save and find buddies', icon: Icons.search, onPressed: _save),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_matches != null) ...[
          const Text('Matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_matches!.isEmpty)
            _empty('No matches yet. Check again later.')
          else
            for (final b in _matches!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  radius: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${_goals[b.goal] ?? b.goal}  |  ${_levels[b.level] ?? b.level}  |  ${_slots[b.slot] ?? b.slot}',
                                style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: () async {
                          final r = await SocialService.instance.requestFriendById(b.userId);
                          if (mounted) _snack(context, r);
                        },
                        child: const Text('Add friend'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
