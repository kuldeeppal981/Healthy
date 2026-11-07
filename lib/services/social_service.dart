import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile_models.dart';
import 'reminder_service.dart';

import '../config.dart';
import '../state/app_state.dart';
import 'step_service.dart';

class BoardRow {
  final String userId;
  final String name;
  final int stepsToday;
  final int stepsWeek;
  final int workoutDays30;
  final int workoutStreak;
  final int foodStreak;
  final bool isMe;

  const BoardRow(this.userId, this.name, this.stepsToday, this.stepsWeek,
      this.workoutDays30, this.workoutStreak, this.foodStreak, this.isMe);
}

class FriendRequest {
  final String userId;
  final String name;

  const FriendRequest(this.userId, this.name);
}

class Person {
  final String userId;
  final String name;
  final String tag;

  const Person(this.userId, this.name, this.tag);
}

/// Someone the user blocked or muted.
class BlockedPerson {
  final String userId;
  final String name;
  final bool mute; // true = muted only, false = blocked

  const BlockedPerson(this.userId, this.name, this.mute);
}

class Challenge {
  final String id;
  final String name;
  final String kind; // steps | workouts | transform
  final DateTime start;
  final DateTime end;
  final String code;

  const Challenge(this.id, this.name, this.kind, this.start, this.end, this.code);

  String get kindLabel => switch (kind) {
        'steps' => 'Step competition',
        'workouts' => 'Workout days',
        _ => 'Transformation',
      };

  String get scoreLabel => switch (kind) {
        'steps' => 'steps',
        'workouts' => 'workout days',
        _ => 'points',
      };
}

class ChallengeRow {
  final String userId;
  final String name;
  final int score;
  final bool isMe;

  const ChallengeRow(this.userId, this.name, this.score, this.isMe);
}


class Cheer {
  final String id;
  final String who;
  final String emoji;
  final String postTitle;
  final DateTime at;

  const Cheer(this.id, this.who, this.emoji, this.postTitle, this.at);
}

class FeedPost {
  final String id;
  final String userId;
  final String name;
  final String kind; // pr | workout | streak | badge | steps
  final String title;
  final String? body;
  final DateTime at;
  final bool isMe;
  String? myReaction;
  final Map<String, int> counts;

  FeedPost({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.isMe,
    required this.myReaction,
    required this.counts,
  });

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// A new personal record found in a finished workout.
class NewPr {
  final String exercise;
  final double kg;
  final int reps;
  final double? previousKg;

  const NewPr(this.exercise, this.kg, this.reps, this.previousKg);

  String get text => '${kg == kg.roundToDouble() ? kg.round() : kg} kg x $reps';
}

/// Best set ever logged per exercise (heavier wins, then more reps).
Map<String, Map<String, dynamic>> bestSetsOf(Iterable<WorkoutLog> history) {
  final out = <String, Map<String, dynamic>>{};
  for (final w in history) {
    for (final b in w.bests) {
      final name = (b['name'] as String).toLowerCase();
      final kg = (b['kg'] as num).toDouble();
      final reps = (b['reps'] as num).toInt();
      final cur = out[name];
      if (cur == null ||
          kg > (cur['kg'] as double) ||
          (kg == (cur['kg'] as double) && reps > (cur['reps'] as int))) {
        out[name] = {'kg': kg, 'reps': reps};
      }
    }
  }
  return out;
}

/// Exercises where this workout beat everything logged before. The first time
/// an exercise is logged is not a record, there is nothing to beat yet.
List<NewPr> findNewPrs(Iterable<WorkoutLog> before, List<Map<String, dynamic>> bests) {
  final old = bestSetsOf(before);
  final prs = <NewPr>[];
  for (final b in bests) {
    final name = b['name'] as String;
    final kg = (b['kg'] as num).toDouble();
    final reps = (b['reps'] as num).toInt();
    final prev = old[name.toLowerCase()];
    if (prev == null) continue;
    final pk = prev['kg'] as double;
    final pr = prev['reps'] as int;
    if (kg > pk || (kg == pk && reps > pr)) prs.add(NewPr(name, kg, reps, pk));
  }
  return prs;
}

/// Friends, leaderboards and challenges. All data lives in Supabase and is
/// only visible to friends and challenge members. Sharing is opt-in.
class SocialService extends ChangeNotifier {
  SocialService._();
  static final instance = SocialService._();

  SupabaseClient get _c => Supabase.instance.client;

  bool loading = false;
  bool loaded = false;
  String? error;

  String? name;
  String? code;
  List<BoardRow> board = [];
  List<FriendRequest> requests = [];
  List<Challenge> challenges = [];
  List<Person> suggestions = [];
  bool discoverable = true;

  /// Private profile: not found in search, not on friends' boards or feeds.
  bool privateProfile = false;

  /// Opt-in: friends can see when you were active in the last few minutes.
  bool showActivity = false;

  /// Friends who are active right now (only those who opted in).
  Set<String> activeNow = {};
  List<BlockedPerson> blocked = [];

  String? _uid;

  bool get enabled => code != null;

  static String dayText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get available => cloudEnabled && _c.auth.currentUser != null;

  void reset() {
    name = null;
    code = null;
    board = [];
    requests = [];
    challenges = [];
    suggestions = [];
    feed = [];
    cheers = [];
    privateProfile = false;
    showActivity = false;
    activeNow = {};
    blocked = [];
    cheersSeen = null;
    loaded = false;
    error = null;
    notifyListeners();
  }

  String _err(Object e) {
    if (e is PostgrestException) return e.message;
    return 'Something went wrong. Check your internet and try again.';
  }

  Future<void> refresh() async {
    if (!available) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final uid = _c.auth.currentUser!.id;
      if (_uid != uid) {
        name = null;
        code = null;
        board = [];
        requests = [];
        challenges = [];
        _lastSent = '';
        _uid = uid;
      }
      final me = await _c
          .from('social_profiles')
          .select('name, code, discoverable')
          .eq('user_id', uid)
          .maybeSingle();
      if (me == null) {
        name = null;
        code = null;
        board = [];
        requests = [];
        challenges = [];
        suggestions = [];
      } else {
        name = me['name'] as String;
        code = me['code'] as String;
        discoverable = (me['discoverable'] as bool?) ?? true;
        try {
          final sg = await _c.rpc('suggested_people') as List;
          suggestions = [
            for (final r in sg)
              Person(r['user_id'] as String, (r['name'] as String?) ?? 'Someone',
                  (r['tag'] as String?) ?? ''),
          ];
        } catch (_) {
          suggestions = [];
        }
        final today = dayText(DateTime.now());
        final b = await _c.rpc('friends_board', params: {'p_today': today}) as List;
        board = [
          for (final r in b)
            BoardRow(
              r['user_id'] as String,
              (r['name'] as String?) ?? 'Friend',
              (r['steps_today'] as num).toInt(),
              (r['steps_week'] as num).toInt(),
              (r['workout_days_30'] as num).toInt(),
              (r['workout_streak'] as num).toInt(),
              (r['food_streak'] as num).toInt(),
              r['is_me'] as bool,
            ),
        ];
        final rq = await _c.rpc('pending_requests') as List;
        requests = [
          for (final r in rq)
            FriendRequest(r['requester'] as String, (r['name'] as String?) ?? 'Someone'),
        ];
        await _loadSafety();
        final ch = await _c.from('challenges').select().order('end_day', ascending: false) as List;
        challenges = [
          for (final r in ch)
            Challenge(
              r['id'] as String,
              r['name'] as String,
              r['kind'] as String,
              DateTime.parse(r['start_day'] as String),
              DateTime.parse(r['end_day'] as String),
              r['code'] as String,
            ),
        ];
      }
      loaded = true;
    } catch (e) {
      error = _err(e);
    }
    loading = false;
    notifyListeners();
  }

  /// Privacy switches, activity and the block list. Quiet when the safety SQL
  /// has not been run yet (the old behaviour keeps working).
  Future<void> _loadSafety() async {
    try {
      final pr = await _c.rpc('get_privacy') as List;
      if (pr.isNotEmpty) {
        privateProfile = (pr.first['private_profile'] as bool?) ?? false;
        showActivity = (pr.first['show_activity'] as bool?) ?? false;
      }
      final act = await _c.rpc('friends_activity') as List;
      activeNow = {for (final r in act) r['user_id'] as String};
      final bl = await _c.rpc('my_blocks') as List;
      blocked = [
        for (final r in bl)
          BlockedPerson(r['user_id'] as String, (r['name'] as String?) ?? 'Someone',
              (r['mute'] as bool?) ?? false),
      ];
    } catch (_) {}
  }

  Future<String> setPrivacy({bool? private, bool? activity}) async {
    final p = private ?? privateProfile;
    final a = activity ?? showActivity;
    try {
      await _c.rpc('set_privacy', params: {'p_private': p, 'p_activity': a});
      privateProfile = p;
      showActivity = a;
      if (p) discoverable = false;
      notifyListeners();
      return 'Saved';
    } catch (_) {
      return 'Could not save. Run the latest SQL (social_safety) first.';
    }
  }

  /// Block removes the friendship both ways; mute only hides their posts and
  /// numbers from you.
  Future<String> blockUser(String userId, {required bool mute}) async {
    try {
      await _c.rpc('block_user', params: {'p_user': userId, 'p_mute': mute});
      feed = feed.where((x) => x.userId != userId).toList();
      await refresh();
      return mute ? 'Muted. You will not see their posts.' : 'Blocked.';
    } catch (_) {
      return 'Could not do that. Run the latest SQL (social_safety) first.';
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _c.rpc('unblock_user', params: {'p_user': userId});
    } catch (_) {}
    await refresh();
    await loadFeed();
  }

  Future<String> reportUser(String userId, {String? postId, String? reason}) async {
    try {
      final r = await _c.rpc('report_user', params: {
        'p_user': userId,
        'p_post': postId,
        'p_reason': reason ?? '',
      }) as String;
      return r == 'ok'
          ? 'Thanks, we will look at it.'
          : r == 'limit'
              ? 'You have sent many reports today. Try again tomorrow.'
              : 'Could not send the report.';
    } catch (_) {
      return 'Could not send the report. Run the latest SQL (social_safety) first.';
    }
  }

  /// Keeps the friends name in step with the name in Profile.
  Future<void> rename(String newName) async {
    if (!enabled || !available) return;
    try {
      await _c.rpc('create_social_profile', params: {'p_name': newName.trim()});
      name = newName.trim();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> enable(String displayName) async {
    try {
      await _c.rpc('create_social_profile', params: {'p_name': displayName.trim()});
      await refresh();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Turns sharing off and removes the person's social data.
  Future<String?> disable() async {
    try {
      final uid = _c.auth.currentUser!.id;
      await _c.from('daily_stats').delete().eq('user_id', uid);
      await _c.from('friendships').delete().or('a.eq.$uid,b.eq.$uid');
      await _c.from('challenge_members').delete().eq('user_id', uid);
      await _c.from('social_profiles').delete().eq('user_id', uid);
      reset();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  Future<String> requestFriend(String friendCode) async {
    try {
      final r = await _c.rpc('request_friend', params: {'p_code': friendCode}) as String;
      await refresh();
      return switch (r) {
        'sent' => 'Request sent. They need to accept it.',
        'accepted' => 'You are now friends.',
        'exists' => 'You already sent a request to this person.',
        'self' => 'That is your own code.',
        'not_found' => 'No one has that code. Check it and try again.',
        _ => 'Turn on friends first.',
      };
    } catch (e) {
      return _err(e);
    }
  }

  Future<List<Person>> search(String q) async {
    final r = await _c.rpc('search_people', params: {'p_q': q}) as List;
    return [
      for (final x in r)
        Person(x['user_id'] as String, (x['name'] as String?) ?? 'Someone',
            (x['tag'] as String?) ?? ''),
    ];
  }

  Future<String> requestFriendById(String userId) async {
    try {
      final r = await _c.rpc('request_friend_id', params: {'p_user': userId}) as String;
      await refresh();
      return switch (r) {
        'sent' => 'Request sent. They need to accept it.',
        'accepted' => 'You are now friends.',
        'exists' => 'You already sent a request to this person.',
        'not_found' => 'This person can no longer be found.',
        _ => 'Turn on friends first.',
      };
    } catch (e) {
      return _err(e);
    }
  }

  Future<void> setDiscoverable(bool v) async {
    try {
      await _c
          .from('social_profiles')
          .update({'discoverable': v}).eq('user_id', _c.auth.currentUser!.id);
      discoverable = v;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> respond(FriendRequest r, bool accept) async {
    try {
      final uid = _c.auth.currentUser!.id;
      if (accept) {
        await _c
            .from('friendships')
            .update({'status': 'accepted'})
            .eq('a', r.userId)
            .eq('b', uid);
      } else {
        await _c.from('friendships').delete().eq('a', r.userId).eq('b', uid);
      }
    } catch (_) {}
    await refresh();
  }

  /// Sends a push nudge to a friend. Returns a short message for the user.
  Future<String> nudge(String friendId) async {
    try {
      final r = await _c.rpc('send_nudge', params: {'p_user': friendId}) as String;
      switch (r) {
        case 'ok':
          return 'Nudge sent!';
        case 'already_today':
          return 'You already nudged them today.';
        case 'limit':
          return 'Nudge limit reached for today.';
        case 'not_friends':
          return 'You can only nudge friends.';
        default:
          return 'Could not send the nudge.';
      }
    } catch (_) {
      return 'Could not send the nudge. Check internet and that the latest SQL was run.';
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final uid = _c.auth.currentUser!.id;
      await _c
          .from('friendships')
          .delete()
          .or('and(a.eq.$uid,b.eq.$friendId),and(a.eq.$friendId,b.eq.$uid)');
    } catch (_) {}
    await refresh();
  }

  Future<String?> createChallenge(String title, String kind, int days) async {
    try {
      final start = DateTime.now();
      final end = start.add(Duration(days: days - 1));
      await _c.rpc('create_challenge', params: {
        'p_name': title.trim(),
        'p_kind': kind,
        'p_start': dayText(start),
        'p_end': dayText(end),
      });
      await refresh();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  Future<String?> joinChallenge(String challengeCode) async {
    try {
      final r = await _c.rpc('join_challenge', params: {'p_code': challengeCode}) as String;
      if (r == 'not_found') return 'No challenge has that code.';
      if (r == 'no_profile') return 'Turn on friends first.';
      await refresh();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  Future<void> leaveChallenge(String id) async {
    try {
      final uid = _c.auth.currentUser!.id;
      await _c.from('challenge_members').delete().eq('challenge_id', id).eq('user_id', uid);
    } catch (_) {}
    await refresh();
  }

  Future<List<ChallengeRow>> challengeBoard(String id) async {
    final r = await _c.rpc('challenge_board', params: {'p_cid': id}) as List;
    return [
      for (final x in r)
        ChallengeRow(
          x['user_id'] as String,
          (x['name'] as String?) ?? 'Member',
          (x['score'] as num).toInt(),
          x['is_me'] as bool,
        ),
    ];
  }



  // ---- Cheers from friends ----

  static const emojiOf = {'fire': '🔥', 'clap': '👏', 'muscle': '💪', 'heart': '❤️'};

  List<Cheer> cheers = [];
  DateTime? cheersSeen;
  DateTime? _notifiedAt;
  Timer? _watch;

  int get unreadCheers =>
      cheersSeen == null ? 0 : cheers.where((c) => c.at.isAfter(cheersSeen!)).length;

  /// Checks for new cheers now and then while the app is alive, and shows a
  /// phone notification for any that arrive.
  void startWatching() {
    _watch?.cancel();
    Future<void>.delayed(const Duration(seconds: 8), pollCheers);
    _watch = Timer.periodic(const Duration(seconds: 90), (_) => pollCheers());
  }

  Future<void> pollCheers() async {
    try {
      if (!available) return;
      if (cheersSeen == null) {
        final p = await SharedPreferences.getInstance();
        final t = p.getString('cheersSeen');
        cheersSeen = t == null ? DateTime.now() : DateTime.tryParse(t) ?? DateTime.now();
        if (t == null) await p.setString('cheersSeen', cheersSeen!.toIso8601String());
        _notifiedAt = cheersSeen;
      }
      final r = await _c.rpc('get_cheers', params: {'p_limit': 40}) as List;
      cheers = [
        for (final x in r)
          Cheer(
            x['id'] as String,
            (x['who'] as String?) ?? 'A friend',
            emojiOf[x['emoji']] ?? '👏',
            (x['post_title'] as String?) ?? '',
            DateTime.parse(x['created_at'] as String).toLocal(),
          ),
      ];
      final fresh = cheers.where((c) => c.at.isAfter(_notifiedAt!)).toList();
      if (fresh.isNotEmpty) {
        _notifiedAt = fresh.first.at;
        final c = fresh.first;
        final more = fresh.length > 1 ? ' and ${fresh.length - 1} more' : '';
        // With push set up, the server already sends this cheer; avoid a double alert.
        if (!pushEnabled) await ReminderService.instance.showNow(
          7001,
          '${c.emoji} ${c.who} cheered you$more',
          c.postTitle,
          kind: 'cheer',
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markCheersSeen() async {
    cheersSeen = DateTime.now();
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('cheersSeen', cheersSeen!.toIso8601String());
    } catch (_) {}
  }

  // ---- Friend feed ----

  List<FeedPost> feed = [];
  bool feedLoading = false;
  String? feedError;
  bool shareAchievements = true;
  bool _prefsRead = false;

  Future<void> _readPrefs() async {
    if (_prefsRead) return;
    try {
      final p = await SharedPreferences.getInstance();
      shareAchievements = p.getBool('shareAchievements') ?? true;
    } catch (_) {}
    _prefsRead = true;
  }

  Future<void> setShareAchievements(bool v) async {
    shareAchievements = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('shareAchievements', v);
    } catch (_) {}
  }

  Future<void> loadFeed() async {
    if (!available) return;
    await _readPrefs();
    feedLoading = true;
    feedError = null;
    notifyListeners();
    try {
      final r = await _c.rpc('get_feed', params: {'p_limit': 60}) as List;
      feed = [
        for (final x in r)
          FeedPost(
            id: x['id'] as String,
            userId: x['user_id'] as String,
            name: (x['name'] as String?) ?? 'Friend',
            kind: x['kind'] as String,
            title: x['title'] as String,
            body: x['body'] as String?,
            at: DateTime.parse(x['created_at'] as String).toLocal(),
            isMe: x['is_me'] as bool,
            myReaction: x['my_reaction'] as String?,
            counts: {
              'fire': (x['fire'] as num).toInt(),
              'clap': (x['clap'] as num).toInt(),
              'muscle': (x['muscle'] as num).toInt(),
              'heart': (x['heart'] as num).toInt(),
            },
          ),
      ];
    } catch (e) {
      feedError = _err(e);
    }
    feedLoading = false;
    notifyListeners();
  }

  /// Puts an achievement on the feed. Silent when the person has not turned on
  /// friends, has switched sharing off, or is offline.
  Future<void> postAchievement({
    required String kind,
    required String title,
    String? body,
    required String dedupe,
  }) async {
    try {
      if (!available) return;
      await _readPrefs();
      if (!shareAchievements) return;
      final uid = _c.auth.currentUser!.id;
      if (!enabled || _uid != uid) {
        final me = await _c
            .from('social_profiles')
            .select('user_id')
            .eq('user_id', uid)
            .maybeSingle();
        if (me == null) return;
      }
      await _c.from('feed_posts').upsert(
        {
          'user_id': uid,
          'kind': kind,
          'title': title,
          'body': body,
          'dedupe': dedupe,
        },
        onConflict: 'user_id,dedupe',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<void> deletePost(FeedPost p) async {
    feed = feed.where((x) => x.id != p.id).toList();
    notifyListeners();
    try {
      await _c.from('feed_posts').delete().eq('id', p.id);
    } catch (_) {}
  }

  /// Tap an emoji to cheer; tap the same one again to take it back.
  Future<void> react(FeedPost p, String emoji) async {
    final old = p.myReaction;
    final next = old == emoji ? null : emoji;
    if (old != null) p.counts[old] = (p.counts[old] ?? 1) - 1;
    if (next != null) p.counts[next] = (p.counts[next] ?? 0) + 1;
    p.myReaction = next;
    notifyListeners();
    try {
      await _c.rpc('react_to_post', params: {'p_post': p.id, 'p_emoji': next ?? ''});
    } catch (_) {
      await loadFeed();
    }
  }

  // ---- Sending today's numbers ----

  String _lastSent = '';
  Timer? _timer;

  /// Call whenever data changes. Sends today's numbers a few seconds later.
  void schedulePush(AppState s) {
    if (!enabled || !available || _uid != _c.auth.currentUser?.id) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () => _push(s));
  }

  Future<void> _push(AppState s) async {
    try {
      final now = DateTime.now();
      final steps = StepService.instance.steps;
      final workouts = s.workouts.where((w) => AppState.sameDay(w.at, now)).length;
      final row = {
        'user_id': _c.auth.currentUser!.id,
        'day': dayText(now),
        'steps': steps,
        'workouts': workouts,
        'logged': s.today.isNotEmpty,
        'goal_met': steps >= StepService.instance.goal,
      };
      final sig = row.toString();
      if (sig == _lastSent) return;
      await _c.from('daily_stats').upsert(row);
      _lastSent = sig;
      if (showActivity) {
        try {
          await _c.rpc('touch_activity');
        } catch (_) {}
      }
    } catch (_) {}
  }
}
