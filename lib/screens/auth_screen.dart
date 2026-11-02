import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

enum _Mode { signIn, register, code }

/// Sign in, or create an account: email + password, then a code sent to the
/// email, then straight into the app. Google sign-in is also offered.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _isError = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _show(String text, {bool error = true}) {
    setState(() {
      _message = text;
      _isError = error;
    });
  }

  void _goto(_Mode m) {
    setState(() {
      _mode = m;
      _message = null;
    });
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  bool _emailOk() {
    final e = _email.text.trim();
    if (!e.contains('@') || !e.contains('.')) {
      _show('Enter a valid email address.');
      return false;
    }
    return true;
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!_emailOk()) return;
    if (_password.text.isEmpty) {
      _show('Enter your password.');
      return;
    }
    await _run(() async {
      final r = await context
          .read<AppState>()
          .signIn(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (r.error != null) _show(r.error!);
    });
  }

  Future<void> _register() async {
    if (_name.text.trim().length < 2) {
      _show('Enter your name (at least 2 letters).');
      return;
    }
    if (!_emailOk()) return;
    if (_password.text.length < 6) {
      _show('Password must be at least 6 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      _show('The two passwords do not match.');
      return;
    }
    await _run(() async {
      final r = await context
          .read<AppState>()
          .signUp(_email.text.trim(), _password.text, name: _name.text.trim());
      if (!mounted) return;
      if (r.error != null) {
        _show(r.error!);
      } else if (r.needsEmailConfirm) {
        _code.clear();
        _goto(_Mode.code);
        _startCooldown();
        _show('We sent a code to ${_email.text.trim()}.', error: false);
      }
      // If no confirmation is needed the app opens by itself.
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      _show('Enter the code from the email.');
      return;
    }
    await _run(() async {
      final r = await context.read<AppState>().verifyCode(_email.text.trim(), code);
      if (!mounted) return;
      if (r.error != null) _show(r.error!);
    });
  }

  Future<void> _resend() async {
    await _run(() async {
      final r = await context.read<AppState>().resendCode(_email.text.trim());
      if (!mounted) return;
      if (r.error != null) {
        _show(r.error!);
      } else {
        _startCooldown();
        _show('A new code is on its way.', error: false);
      }
    });
  }

  Future<void> _google() async {
    await _run(() async {
      final r = await context.read<AppState>().signInWithGoogle();
      if (!mounted) return;
      if (r.error != null) _show(r.error!);
    });
  }

  Widget _spinner() => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.signIn => 'Welcome back',
      _Mode.register => 'Create your account',
      _Mode.code => 'Check your email',
    };
    final subtitle = switch (_mode) {
      _Mode.signIn => 'Sign in to open your diary, workouts and allergies on any phone.',
      _Mode.register => 'Your data is saved to your own account.',
      _Mode.code => 'Enter the code we sent to ${_email.text.trim()}.',
    };

    return Scaffold(
      body: AppBackground(
       child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDeep]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (_mode == _Mode.register) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
            ],
            if (_mode != _Mode.code) ...[
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
                decoration: InputDecoration(
                  labelText: _mode == _Mode.register ? 'Create a password' : 'Password',
                  helperText: _mode == _Mode.register ? 'At least 6 characters' : null,
                ),
              ),
            ],
            if (_mode == _Mode.register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
              ),
            ],
            if (_mode == _Mode.code)
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6),
                decoration: const InputDecoration(
                  labelText: 'Code',
                  counterText: '',
                ),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_mode == _Mode.signIn) ...[
              GradientButton(
                onPressed: _busy ? null : _signIn,
                label: _busy ? 'Please wait...' : 'Sign in',
              ),
              const SizedBox(height: 16),
              _orDivider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _goto(_Mode.register),
                child: const Text("New here? Create an account"),
              ),
            ],
            if (_mode == _Mode.register) ...[
              GradientButton(
                onPressed: _busy ? null : _register,
                label: _busy ? 'Please wait...' : 'Send code',
              ),
              const SizedBox(height: 16),
              _orDivider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Sign up with Google'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _goto(_Mode.signIn),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
            if (_mode == _Mode.code) ...[
              GradientButton(
                onPressed: _busy ? null : _verify,
                label: _busy ? 'Please wait...' : 'Verify and continue',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_busy || _cooldown > 0) ? null : _resend,
                child: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'No email? Check spam. If you already have an account, go back and sign in instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _goto(_Mode.register),
                child: const Text('Use a different email'),
              ),
            ],
            const SizedBox(height: 8),
            if (_mode != _Mode.code)
              TextButton(
                onPressed: _busy ? null : () => context.read<AppState>().continueAsGuest(),
                child: const Text('Continue without an account'),
              ),
          ],
        ),
       ),
      ),
    );
  }

  Widget _orDivider() => const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: Divider()),
        ],
      );
}
