import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/social_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/share_card.dart';

/// Home row that opens friends and challenges.
class SocialCard extends StatelessWidget {
  const SocialCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
        title: const Text('Friends and challenges',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Leaderboards, 30-day challenge, share progress'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SocialScreen()),
        ),
      ),
    );
  }
}

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _svc = SocialService.instance;

  @override
  void initState() {
    super.initState();
    _svc.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = cloudEnabled && context.watch<AppState>().signedIn;
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Friends and challenges'),
              actions: [
                IconButton(
                  tooltip: 'Share progress',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => showShareCard(context),
                ),
              ],
              bottom: _svc.enabled
                  ? const TabBar(tabs: [
                      Tab(text: 'Leaderboard'),
                      Tab(text: 'Friends'),
                      Tab(text: 'Challenges'),
                    ])
                  : null,
            ),
            body: !signedIn
                ? const _Note('Sign in to your account to use friends and challenges.')
                : !_svc.loaded && _svc.loading
                    ? const Center(child: CircularProgressIndicator())
                    : !_svc.loaded && _svc.error != null
                        ? _Retry(message: _svc.error!, onRetry: _svc.refresh)
                        : !_svc.enabled
                            ? _TurnOn(svc: _svc)
                            : TabBarView(children: [
                                _LeaderboardTab(svc: _svc),
                                _FriendsTab(svc: _svc),
                                _ChallengesTab(svc: _svc),
                              ]),
          ),
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Retry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _TurnOn extends StatefulWidget {
  final SocialService svc;

  const _TurnOn({required this.svc});

  @override
  State<_TurnOn> createState() => _TurnOnState();
}

class _TurnOnState extends State<_TurnOn> {
  late final TextEditingController _name =
      TextEditingController(text: context.read<AppState>().accountName ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final n = _name.text.trim();
    if (n.length < 2) {
      setState(() => _error = 'Enter a name with at least 2 letters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await widget.svc.enable(n);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Compete with friends',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Add friends with a code, see who walks the most, and join a 30-day challenge together.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        AppCard(
          color: AppColors.chipBg,
          borderColor: AppColors.chipBg,
          radius: 14,
          child: const Text(
            'What friends can see: your name, daily steps, whether you worked out and whether you logged food. Never your weight, meals, allergies or health conditions. Other users can find you by name and send a friend request. You can turn this off any time.',
            style: TextStyle(color: AppColors.chipInk, height: 1.4, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: const InputDecoration(labelText: 'Name your friends will see'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _go,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : const Text('Turn on friends'),
        ),
      ],
    );
  }
}

class _LeaderboardTab extends StatefulWidget {
  final SocialService svc;

  const _LeaderboardTab({required this.svc});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  int _metric = 0;

  static const _labels = [
    'Steps today',
    'Steps 7 days',
    'Workout streak',
    'Food streak',
    'Workouts 30 days',
  ];

  int _value(BoardRow r) => switch (_metric) {
        0 => r.stepsToday,
        1 => r.stepsWeek,
        2 => r.workoutStreak,
        3 => r.foodStreak,
        _ => r.workoutDays30,
      };

  String _unit() => switch (_metric) {
        0 || 1 => 'steps',
        2 || 3 => 'days',
        _ => 'days',
      };

  @override
  Widget build(BuildContext context) {
    final rows = [...widget.svc.board]..sort((a, b) => _value(b).compareTo(_value(a)));
    return RefreshIndicator(
      onRefresh: widget.svc.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(_labels[i]),
                selected: _metric == i,
                onSelected: (_) => setState(() => _metric = i),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.length <= 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No friends yet. Open the Friends tab, share your code and add a friend.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                radius: 14,
                color: rows[i].isMe ? AppColors.chipBg : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        i == 0 ? '1st' : '${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? AppColors.ring : AppColors.muted),
                      ),
                    ),
                    Expanded(
                      child: Text(rows[i].isMe ? '${rows[i].name} (you)' : rows[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('${_value(rows[i])} ${_unit()}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatefulWidget {
  final SocialService svc;

  const _FriendsTab({required this.svc});

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  final _code = TextEditingController();
  final _find = TextEditingController();
  String? _msg;
  bool _busy = false;
  List<Person>? _results;
  bool _searching = false;

  Future<void> _doSearch() async {
    final q = _find.text.trim();
    if (q.length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await widget.svc.search(q);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _msg = 'Search failed. Check your internet.');
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _addPerson(Person p) async {
    final m = await widget.svc.requestFriendById(p.userId);
    if (!mounted) return;
    setState(() {
      _msg = m;
      _results = _results?.where((x) => x.userId != p.userId).toList();
    });
  }

  Widget _personRow(Person p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: p.tag.isEmpty ? '' : '  #${p.tag}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ])),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _addPerson(p),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    _code.dispose();
    _find.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final c = _code.text.trim();
    if (c.length < 4) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final m = await widget.svc.requestFriend(c);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = m;
      _code.clear();
    });
  }

  Future<void> _turnOff() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off friends?'),
        content: const Text(
            'Your shared stats, friendships and challenge memberships will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn off')),
        ],
      ),
    );
    if (ok == true) await widget.svc.disable();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    final friends = svc.board.where((r) => !r.isMe).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your friend code',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              Text(svc.code ?? '',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: svc.code ?? ''));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Code copied')));
                    },
                    child: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => Share.share(
                        'Add me on Healthy! Open Friends and challenges, then enter my code: ${svc.code}'),
                    child: const Text('Share code'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Find people',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _find,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _doSearch(),
                decoration: const InputDecoration(
                  labelText: 'Search by name',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _searching ? null : _doSearch,
                style: FilledButton.styleFrom(minimumSize: const Size(80, 52)),
                child: const Text('Search'),
              ),
            ),
          ],
        ),
        if (_results != null) ...[
          const SizedBox(height: 10),
          if (_results!.isEmpty)
            const Text('No one found with that name.',
                style: TextStyle(color: AppColors.muted)),
          for (final p in _results!) _personRow(p),
        ],
        if (svc.suggestions.isNotEmpty && _results == null) ...[
          const SizedBox(height: 16),
          const Text('People you may know',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final p in svc.suggestions) _personRow(p),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: "Friend's code"),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _add,
                style: FilledButton.styleFrom(minimumSize: const Size(80, 52)),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_msg!, style: const TextStyle(color: AppColors.muted)),
          ),
        if (svc.requests.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final r in svc.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                radius: 14,
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(r.name,
                            style: const TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(
                        onPressed: () => svc.respond(r, false), child: const Text('Decline')),
                    FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => svc.respond(r, true),
                        child: const Text('Accept')),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (friends.isEmpty)
          const Text('No friends yet.', style: TextStyle(color: AppColors.muted)),
        for (final f in friends)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              radius: 14,
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                      child: Text(f.name,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () => svc.removeFriend(f.userId),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Let people find me by name'),
          subtitle: const Text('Shows you in search and suggestions',
              style: TextStyle(fontSize: 12)),
          value: svc.discoverable,
          activeColor: AppColors.primary,
          onChanged: svc.setDiscoverable,
        ),
        TextButton(
          onPressed: _turnOff,
          child: const Text('Turn off friends and delete my shared data',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}

class _ChallengesTab extends StatefulWidget {
  final SocialService svc;

  const _ChallengesTab({required this.svc});

  @override
  State<_ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<_ChallengesTab> {
  final _join = TextEditingController();
  String? _msg;

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = TextEditingController(text: '30-day transformation');
    var kind = 'transform';
    var days = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New challenge'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: name,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                        label: const Text('Transformation'),
                        selected: kind == 'transform',
                        onSelected: (_) => setS(() => kind = 'transform')),
                    ChoiceChip(
                        label: const Text('Steps'),
                        selected: kind == 'steps',
                        onSelected: (_) => setS(() => kind = 'steps')),
                    ChoiceChip(
                        label: const Text('Workout days'),
                        selected: kind == 'workouts',
                        onSelected: (_) => setS(() => kind = 'workouts')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  switch (kind) {
                    'steps' => 'Most total steps wins.',
                    'workouts' => 'Most days with a workout wins.',
                    _ => 'Each day: 1 point for logging food, 1 for a workout, 1 for your step goal.',
                  },
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in const [7, 14, 30])
                      ChoiceChip(
                          label: Text('$d days'),
                          selected: days == d,
                          onSelected: (_) => setS(() => days = d)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    final title = name.text.trim();
    name.dispose();
    if (ok != true || title.length < 2) return;
    final e = await widget.svc.createChallenge(title, kind, days);
    if (mounted) setState(() => _msg = e ?? 'Challenge created. Share its code with friends.');
  }

  Future<void> _joinNow() async {
    final c = _join.text.trim();
    if (c.length < 4) return;
    final e = await widget.svc.joinChallenge(c);
    if (!mounted) return;
    setState(() {
      _msg = e ?? 'You joined the challenge.';
      if (e == null) _join.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Start a challenge'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _join,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Challenge code'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _joinNow,
                style: OutlinedButton.styleFrom(minimumSize: const Size(80, 52)),
                child: const Text('Join'),
              ),
            ),
          ],
        ),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_msg!, style: const TextStyle(color: AppColors.muted)),
          ),
        const SizedBox(height: 20),
        if (svc.challenges.isEmpty)
          const Text('No challenges yet. Start one, or join with a code.',
              style: TextStyle(color: AppColors.muted)),
        for (final c in svc.challenges)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              radius: 16,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ChallengeScreen(challenge: c)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${c.kindLabel}  |  ${day.isAfter(c.end) ? 'Finished' : day.isBefore(c.start) ? 'Not started' : '${c.end.difference(day).inDays + 1} days left'}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ChallengeScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeScreen({super.key, required this.challenge});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late Future<List<ChallengeRow>> _future =
      SocialService.instance.challengeBoard(widget.challenge.id);

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: FutureBuilder<List<ChallengeRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Retry(
              message: 'Could not load the scores.',
              onRetry: () => setState(() =>
                  _future = SocialService.instance.challengeBoard(c.id)),
            );
          }
          final rows = snap.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = SocialService.instance.challengeBoard(c.id));
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.kindLabel}: ${c.start.day}/${c.start.month} to ${c.end.day}/${c.end.month}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Code ${c.code}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () => Share.share(
                                'Join my challenge "${c.name}" on Healthy! Open Friends and challenges, then Join with code ${c.code}'),
                            child: const Text('Invite'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      radius: 14,
                      color: rows[i].isMe ? AppColors.chipBg : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(i == 0 ? '1st' : '${i + 1}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: i == 0 ? AppColors.ring : AppColors.muted)),
                          ),
                          Expanded(
                            child: Text(
                                rows[i].isMe ? '${rows[i].name} (you)' : rows[i].name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text('${rows[i].score} ${c.scoreLabel}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await SocialService.instance.leaveChallenge(c.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Leave this challenge',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
