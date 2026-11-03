import 'package:flutter/material.dart';

import '../services/voice_service.dart';
import '../theme.dart';

/// Bottom sheet that listens and returns what the user said (editable),
/// or null if closed. Starts listening as soon as it opens.
Future<String?> showVoiceCapture(BuildContext context, {String hint = 'Say what you ate'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VoiceCapture(hint: hint),
  );
}

class _VoiceCapture extends StatefulWidget {
  final String hint;

  const _VoiceCapture({required this.hint});

  @override
  State<_VoiceCapture> createState() => _VoiceCaptureState();
}

class _VoiceCaptureState extends State<_VoiceCapture> {
  final _text = TextEditingController();
  final _voice = VoiceService.instance;
  String _locale = 'en_IN';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _voice.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() => _error = null);
    final ok = await _voice.start(
      localeId: _locale,
      onText: (t, done) {
        if (!mounted) return;
        setState(() => _text.text = t);
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      },
    );
    if (!ok && mounted) {
      setState(() => _error =
          'Could not start the microphone. Allow microphone permission and make sure Google speech services are on, or type below.');
    }
  }

  Future<void> _toggle() async {
    if (_voice.listening.value) {
      await _voice.stop();
    } else {
      await _listen();
    }
  }

  Future<void> _setLocale(String l) async {
    if (l == _locale) return;
    await _voice.stop();
    setState(() => _locale = l);
    await _listen();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.hint,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Example: "2 roti, ek katori dal aur ek glass doodh"',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('English / Hinglish'),
                selected: _locale == 'en_IN',
                onSelected: (_) => _setLocale('en_IN'),
              ),
              ChoiceChip(
                label: const Text('हिन्दी'),
                selected: _locale == 'hi_IN',
                onSelected: (_) => _setLocale('hi_IN'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: _voice.listening,
            builder: (_, on, __) => GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.ring : AppColors.primary,
                  boxShadow: on
                      ? [BoxShadow(color: AppColors.ring.withOpacity(0.4), blurRadius: 18, spreadRadius: 4)]
                      : null,
                ),
                child: Icon(on ? Icons.stop_rounded : Icons.mic, color: Colors.white, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _voice.listening,
            builder: (_, on, __) => Text(on ? 'Listening...' : 'Tap the mic to speak',
                style: TextStyle(color: AppColors.muted)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What we heard (you can fix it)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final t = _text.text.trim();
                if (t.isNotEmpty) Navigator.pop(context, t);
              },
              child: const Text('Use this'),
            ),
          ),
        ],
      ),
    );
  }
}
