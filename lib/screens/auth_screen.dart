import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Email login so each user's data is saved to their own account.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _valid() {
    final e = _email.text.trim();
    if (!e.contains('@') || !e.contains('.')) {
      _show('Enter a valid email address.', true);
      return false;
    }
    if (_password.text.length < 6) {
      _show('Password must be at least 6 characters.', true);
      return false;
    }
    return true;
  }

  void _show(String text, bool error) {
    setState(() {
      _message = text;
      _isError = error;
    });
  }

  Future<void> _submit({required bool create}) async {
    if (!_valid()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final s = context.read<AppState>();
    final email = _email.text.trim();
    final r = create
        ? await s.signUp(email, _password.text)
        : await s.signIn(email, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (r.error != null) {
      _show(r.error!, true);
    } else if (r.needsEmailConfirm) {
      _show('Account created. Open the confirmation email, then sign in here.', false);
    }
    // On success the app switches screens by itself.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          children: [
            const Text('Healthy',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Sign in to save your diary, workouts and allergies to your own account, and use them on any phone.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _isError ? AppColors.danger : AppColors.safe,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _submit(create: false),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : () => _submit(create: true),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => context.read<AppState>().continueAsGuest(),
              child: const Text('Continue without an account'),
            ),
          ],
        ),
      ),
    );
  }
}
