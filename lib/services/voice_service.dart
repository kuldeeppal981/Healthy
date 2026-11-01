import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the phone's speech recognizer.
class VoiceService {
  VoiceService._();
  static final instance = VoiceService._();

  final _stt = SpeechToText();
  bool _ready = false;
  final ValueNotifier<bool> listening = ValueNotifier(false);

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onStatus: (s) => listening.value = s == 'listening',
        onError: (_) => listening.value = false,
      );
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Starts listening. [onText] gets the words so far and whether it is final.
  Future<bool> start({
    required String localeId,
    required void Function(String text, bool done) onText,
  }) async {
    if (!await init()) return false;
    try {
      await _stt.listen(
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
        localeId: localeId,
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    listening.value = false;
  }
}
