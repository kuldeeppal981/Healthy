import 'package:supabase_flutter/supabase_flutter.dart';

class AuthOutcome {
  final String? error;
  final bool needsEmailConfirm;

  const AuthOutcome({this.error, this.needsEmailConfirm = false});
}

class RemoteData {
  final Map<String, dynamic> data;
  final DateTime updatedAt;

  const RemoteData(this.data, this.updatedAt);
}

/// Thin wrapper over Supabase: email login and one JSON snapshot per user.
class CloudSync {
  SupabaseClient get _c => Supabase.instance.client;

  String? get userId => _c.auth.currentUser?.id;
  String? get email => _c.auth.currentUser?.email;

  static const _networkError =
      'Something went wrong. Check your internet connection and try again.';

  Future<AuthOutcome> signIn(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: password);
      return const AuthOutcome();
    } on AuthException catch (e) {
      return AuthOutcome(error: e.message);
    } catch (_) {
      return const AuthOutcome(error: _networkError);
    }
  }

  Future<AuthOutcome> signUp(String email, String password) async {
    try {
      final res = await _c.auth.signUp(email: email, password: password);
      return AuthOutcome(needsEmailConfirm: res.session == null);
    } on AuthException catch (e) {
      return AuthOutcome(error: e.message);
    } catch (_) {
      return const AuthOutcome(error: _networkError);
    }
  }

  Future<void> signOut() => _c.auth.signOut();

  Future<RemoteData?> pull() async {
    final row = await _c
        .from('user_data')
        .select('data, updated_at')
        .eq('user_id', userId!)
        .maybeSingle();
    if (row == null) return null;
    return RemoteData(
      Map<String, dynamic>.from(row['data'] as Map),
      DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<void> push(Map<String, dynamic> data, DateTime at) async {
    await _c.from('user_data').upsert({
      'user_id': userId,
      'data': data,
      'updated_at': at.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteRemote() async {
    await _c.from('user_data').delete().eq('user_id', userId!);
  }
}
