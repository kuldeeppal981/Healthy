import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_service.dart';

/// Social part 2: weekly league, groups, group challenges, accountability
/// partner, buddy matching. Everything goes through SECURITY DEFINER RPCs.

class LeagueRow {
  final String userId;
  final String name;
  final int points;
  final int workouts;
  final int steps;
  final bool isMe;
  const LeagueRow(this.userId, this.name, this.points, this.workouts, this.steps, this.isMe);
}

class GroupInfo {
  final String id;
  final String name;
  final String code;
  final int members;
  final bool isOwner;
  const GroupInfo(this.id, this.name, this.code, this.members, this.isOwner);
}

class GroupChallenge {
  final String id;
  final String name;
  final String kind;
  final DateTime start;
  final DateTime end;
  final bool joined;
  const GroupChallenge(this.id, this.name, this.kind, this.start, this.end, this.joined);
}

class PartnerInfo {
  final String other;
  final String name;
  final bool active;
  final bool incoming;
  final bool loggedToday;
  final bool workoutToday;
  final int stepsToday;
  final int theirDays;
  final int myDays;
  const PartnerInfo(this.other, this.name, this.active, this.incoming, this.loggedToday,
      this.workoutToday, this.stepsToday, this.theirDays, this.myDays);
}

class Buddy {
  final String userId;
  final String name;
  final String goal;
  final String level;
  final String slot;
  const Buddy(this.userId, this.name, this.goal, this.level, this.slot);
}

class CommunityService {
  CommunityService._();
  static SupabaseClient get _c => Supabase.instance.client;

  static String _today() => SocialService.dayText(DateTime.now());

  static String err(Object e) {
    if (e is PostgrestException) {
      final m = e.message;
      if (m.contains('too_many')) return 'You can own up to 5 groups.';
      if (m.contains('no_profile')) return 'Turn on friends first (Community, Friends).';
      if (m.contains('not_member')) return 'Join the group first.';
      return m;
    }
    return 'Something went wrong. Check your internet and try again.';
  }

  static List<LeagueRow> _league(List r) => [
        for (final x in r)
          LeagueRow(x['user_id'] as String, (x['name'] as String?) ?? 'Friend',
              (x['points'] as num).toInt(), (x['workouts'] as num).toInt(),
              (x['steps'] as num).toInt(), x['is_me'] as bool),
      ];

  static Future<List<LeagueRow>> weeklyLeague() async =>
      _league(await _c.rpc('weekly_league', params: {'p_today': _today()}) as List);

  static Future<List<LeagueRow>> groupLeague(String group) async => _league(
      await _c.rpc('group_league', params: {'p_group': group, 'p_today': _today()}) as List);

  // ---- groups ----

  static Future<List<GroupInfo>> myGroups() async {
    final r = await _c.rpc('my_groups') as List;
    return [
      for (final x in r)
        GroupInfo(x['id'] as String, x['name'] as String, x['code'] as String,
            (x['members'] as num).toInt(), x['is_owner'] as bool),
    ];
  }

  static Future<String?> createGroup(String name) async {
    try {
      await _c.rpc('create_group', params: {'p_name': name});
      return null;
    } catch (e) {
      return err(e);
    }
  }

  static Future<String?> joinGroup(String code) async {
    try {
      final r = await _c.rpc('join_group', params: {'p_code': code}) as String;
      return switch (r) {
        'ok' => null,
        'already' => 'You are already in this group.',
        'full' => 'This group is full (30 people).',
        'no_profile' => 'Turn on friends first (Community, Friends).',
        _ => 'No group has that code.',
      };
    } catch (e) {
      return err(e);
    }
  }

  static Future<void> leaveGroup(String id) async {
    try {
      await _c.rpc('leave_group', params: {'p_group': id});
    } catch (_) {}
  }

  static Future<List<GroupChallenge>> groupChallenges(String group) async {
    final r = await _c.rpc('group_challenges', params: {'p_group': group}) as List;
    return [
      for (final x in r)
        GroupChallenge(x['id'] as String, x['name'] as String, x['kind'] as String,
            DateTime.parse(x['start_day'] as String), DateTime.parse(x['end_day'] as String),
            x['joined'] as bool),
    ];
  }

  static Future<String?> createGroupChallenge(String group, String name, String kind, int days) async {
    try {
      final s = DateTime.now();
      await _c.rpc('create_group_challenge', params: {
        'p_group': group,
        'p_name': name,
        'p_kind': kind,
        'p_start': SocialService.dayText(s),
        'p_end': SocialService.dayText(s.add(Duration(days: days - 1))),
      });
      return null;
    } catch (e) {
      return err(e);
    }
  }

  static Future<String?> joinGroupChallenge(String id) async {
    try {
      await _c.rpc('join_group_challenge', params: {'p_cid': id});
      return null;
    } catch (e) {
      return err(e);
    }
  }

  // ---- partner ----

  static Future<PartnerInfo?> myPartner() async {
    final r = await _c.rpc('my_partner', params: {'p_today': _today()}) as List;
    if (r.isEmpty) return null;
    final x = r.first;
    return PartnerInfo(
      x['other'] as String,
      (x['name'] as String?) ?? 'Partner',
      x['status'] == 'active',
      x['incoming'] as bool,
      x['logged_today'] as bool,
      x['workout_today'] as bool,
      (x['steps_today'] as num).toInt(),
      (x['active_days_7'] as num).toInt(),
      (x['my_active_days_7'] as num).toInt(),
    );
  }

  static Future<String?> requestPartner(String userId) async {
    try {
      final r = await _c.rpc('request_partner', params: {'p_user': userId}) as String;
      return switch (r) {
        'ok' => null,
        'have_partner' => 'You already have a partner. End it first.',
        'they_have_partner' => 'They already have a partner.',
        'not_friends' => 'You can only pick a friend.',
        _ => 'Could not send the request.',
      };
    } catch (e) {
      return err(e);
    }
  }

  static Future<void> respondPartner(String userId, bool accept) async {
    try {
      await _c.rpc('respond_partner', params: {'p_user': userId, 'p_accept': accept});
    } catch (_) {}
  }

  static Future<void> endPartner() async {
    try {
      await _c.rpc('end_partner');
    } catch (_) {}
  }

  // ---- buddy matching ----

  static Future<Map<String, dynamic>?> myBuddyProfile() async {
    final r = await _c.rpc('get_buddy_profile') as List;
    return r.isEmpty ? null : Map<String, dynamic>.from(r.first as Map);
  }

  static Future<String?> saveBuddyProfile(String goal, String level, String slot, bool looking) async {
    try {
      await _c.rpc('set_buddy_profile',
          params: {'p_goal': goal, 'p_level': level, 'p_slot': slot, 'p_looking': looking});
      return null;
    } catch (e) {
      return err(e);
    }
  }

  static Future<List<Buddy>> findBuddies() async {
    final r = await _c.rpc('find_buddies') as List;
    return [
      for (final x in r)
        Buddy(x['user_id'] as String, (x['name'] as String?) ?? 'Someone', x['goal'] as String,
            x['level'] as String, x['slot'] as String),
    ];
  }
}
