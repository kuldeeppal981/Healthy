import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

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

/// Thin wrapper over Supabase: email login with a one-time code, Google
/// login, and one JSON snapshot of app data per user.
class CloudSync {
  SupabaseClient get _c => Supabase.instance.client;

  String? get userId => _c.auth.currentUser?.id;
  String? get email => _c.auth.currentUser?.email;

  /// Name given at sign up, or the Google account name.
  String? get displayName {
    final m = _c.auth.currentUser?.userMetadata;
    final n = (m?['name'] ?? m?['full_name'] ?? '').toString().trim();
    return n.isEmpty ? null : n;
  }

  /// Fires when a user completes a new sign-in (password, code or Google).
  Stream<void> get signedInEvents => _c.auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.signedIn)
      .map((_) {});

  /// Fires on any sign-in, sign-out or token change.
  Stream<void> get anyAuthEvents => _c.auth.onAuthStateChange.map((_) {});

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

  /// Creates the account. When email confirmation is on, Supabase emails a
  /// code and [AuthOutcome.needsEmailConfirm] is true.
  Future<AuthOutcome> signUp(String email, String password, {String? name}) async {
    try {
      final res = await _c.auth.signUp(
        email: email,
        password: password,
        data: (name == null || name.isEmpty) ? null : {'name': name},
      );
      return AuthOutcome(needsEmailConfirm: res.session == null);
    } on AuthException catch (e) {
      return AuthOutcome(error: e.message);
    } catch (_) {
      return const AuthOutcome(error: _networkError);
    }
  }

  /// Checks the code from the email. On success the user is signed in.
  Future<AuthOutcome> verifyEmailCode(String email, String code) async {
    try {
      await _c.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
      return const AuthOutcome();
    } on AuthException catch (e) {
      return AuthOutcome(error: e.message);
    } catch (_) {
      return const AuthOutcome(error: _networkError);
    }
  }

  Future<AuthOutcome> resendCode(String email) async {
    try {
      await _c.auth.resend(type: OtpType.signup, email: email);
      return const AuthOutcome();
    } on AuthException catch (e) {
      return AuthOutcome(error: e.message);
    } catch (_) {
      return const AuthOutcome(error: _networkError);
    }
  }

  /// Opens Google sign-in in the browser. The app is reopened through the
  /// deep link [oauthRedirect] and Supabase finishes the login.
  Future<AuthOutcome> signInWithGoogle() async {
    try {
      final started = await _c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirect,
      );
      if (!started) {
        return const AuthOutcome(error: 'Could not open Google sign-in.');
      }
      return const AuthOutcome();
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
