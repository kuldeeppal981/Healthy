import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speaks short form cues during live camera analysis.
/// Modes: 'en' (English), 'hi' (Hindi), 'off'. Saved in SharedPreferences.
class VoiceCoach {
  static const prefKey = 'live_voice_mode';
  final FlutterTts _tts = FlutterTts();
  String mode = 'en';
  bool _ready = false;
  String _lastSpoken = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode = p.getString(prefKey) ?? 'en';
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _applyLang();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> _applyLang() async {
    try {
      await _tts.setLanguage(mode == 'hi' ? 'hi-IN' : 'en-IN');
    } catch (_) {}
  }

  Future<void> setMode(String m) async {
    mode = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(prefKey, m);
    } catch (_) {}
    if (m == 'off') {
      try {
        await _tts.stop();
      } catch (_) {}
    } else {
      await _applyLang();
    }
  }

  String get label => switch (mode) { 'hi' => 'हिं', 'off' => 'Off', _ => 'EN' };

  String next() => switch (mode) { 'en' => 'hi', 'hi' => 'off', _ => 'en' };

  static const _hi = <String, String>{
    'Chest up': 'सीना सीधा रखो',
    'Keep a straight line': 'शरीर सीधा रखो',
    'Cannot see': 'कैमरे में पूरा दिखो',
    'Shallow': 'थोड़ा और नीचे जाओ',
    'Leaning forward': 'आगे मत झुको',
    'Knees moved inward': 'घुटने बाहर रखो',
    'Weight shifted': 'बीच में रहो',
    'Curl higher': 'थोड़ा और ऊपर लाओ',
    'Elbow moved': 'कोहनी साइड में रखो',
    'Body not in a straight': 'कोर टाइट रखो',
    'Lower a little': 'थोड़ा और नीचे जाओ',
    'Pull a little': 'थोड़ा और पीछे खींचो',
    'Bend a little': 'थोड़ा और मोड़ो',
    'Lift to about': 'कंधे तक उठाओ',
    'Left and right': 'दोनों तरफ बराबर रखो',
    'Too fast': 'धीरे करो, कंट्रोल रखो',
    'Hips are sagging': 'कमर ऊपर उठाओ, कोर टाइट रखो',
    'Hips too high': 'कमर थोड़ी नीचे लाओ',
  };

  String _tr(String en) {
    if (mode != 'hi') return en;
    for (final e in _hi.entries) {
      if (en.startsWith(e.key)) return e.value;
    }
    return '';
  }

  Future<void> _say(String text, {bool force = false, int gapSec = 4}) async {
    if (!_ready || mode == 'off' || text.isEmpty) return;
    final now = DateTime.now();
    if (!force && text == _lastSpoken && now.difference(_lastAt).inSeconds < 10) return;
    if (!force && now.difference(_lastAt).inSeconds < gapSec) return;
    _lastSpoken = text;
    _lastAt = now;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Called when a rep is finished: count, then the first tip (or "good").
  Future<void> rep(int n, List<String> notes) async {
    if (!_ready || mode == 'off') return;
    final tip = notes.isEmpty ? '' : _tr(notes.first);
    final good = mode == 'hi' ? 'बढ़िया' : 'Good';
    var text = '$n. ${tip.isEmpty ? good : tip}';
    if (n % 5 == 0) {
      text += mode == 'hi' ? ' बहुत बढ़िया, ऐसे ही चलते रहो' : ' Great work, keep going';
    }
    await _say(text, force: true);
  }

  /// Said when analysing starts, like a trainer setting you up.
  Future<void> intro(String title) async {
    final text = mode == 'hi'
        ? 'तैयार हो जाओ। धीरे और कंट्रोल के साथ करो।'
        : 'Get into position for $title. Move slowly and stay in control.';
    await _say(text, force: true);
  }

  /// Said every 10 seconds of a hold.
  Future<void> holdTick(int secs) async {
    final text = mode == 'hi' ? '$secs सेकंड' : '$secs seconds';
    await _say(text, force: true);
  }

  /// Said when the set is finished.
  Future<void> finish(int? score) async {
    if (score == null) return;
    final text = mode == 'hi'
        ? 'सेट पूरा। फॉर्म स्कोर सौ में से $score।'
        : 'Set done. Form score $score out of 100.';
    await _say(text, force: true);
  }

  /// Called every frame with the live cue; only warnings are spoken, rate limited.
  Future<void> live(String cue, bool uncertain) async {
    if (uncertain) {
      await _say(_tr('Cannot see'), gapSec: 12);
      return;
    }
    if (cue.isEmpty || cue == 'Ready' || cue.startsWith('Good')) return;
    await _say(_tr(cue), gapSec: 5);
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
