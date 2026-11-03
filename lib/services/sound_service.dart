import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short feel-good sounds (check-in chime, set done pop, water splash).
/// Can be turned off in Settings. Never throws: if sound fails, the app goes on.
class SoundService extends ChangeNotifier {
  SoundService._();
  static final instance = SoundService._();

  bool enabled = true;
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool('sounds_on') ?? true;
      await _player.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('sounds_on', v);
    } catch (_) {}
  }

  /// name: 'win', 'pop' or 'splash' (files in assets/sounds/).
  Future<void> play(String name) async {
    if (!enabled || !_ready) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {}
  }
}
