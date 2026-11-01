import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    } catch (_) {}
  }
}
