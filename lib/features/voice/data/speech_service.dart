import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/logging/app_logger.dart';

/// A callback fired as words are recognised. [isFinal] is true for the last,
/// settled transcript of a session.
typedef TranscriptListener = void Function(String transcript, bool isFinal);

/// A seam over `speech_to_text` so the controller and its tests never touch the
/// platform plugin. **Device-unverified** (no Android SDK / mic).
abstract interface class SpeechService {
  /// Initialise + check the mic permission. Returns true when listening is
  /// possible.
  Future<bool> ensureReady();

  /// Start a listen session. [onResult] streams partial + final transcripts;
  /// [onDone] fires when the session ends (silence, timeout, or [stop]);
  /// [onError] carries a short message.
  Future<void> start({
    required TranscriptListener onResult,
    required void Function() onDone,
    required void Function(String message) onError,
  });

  Future<void> stop();

  bool get isListening;
}

class SpeechToTextService implements SpeechService {
  SpeechToTextService([SpeechToText? impl]) : _speech = impl ?? SpeechToText();

  final SpeechToText _speech;
  final _log = AppLog.of('voice.speech');
  bool _initialised = false;
  void Function()? _onDone;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> ensureReady() async {
    try {
      if (!_initialised) {
        _initialised = await _speech.initialize(
          onError: (e) => _log.warning('speech error: ${e.errorMsg}'),
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') _onDone?.call();
          },
        );
      }
      return _initialised && await _speech.hasPermission;
    } catch (error, stack) {
      _log.warning('speech init failed (device-unverified)', error, stack);
      return false;
    }
  }

  @override
  Future<void> start({
    required TranscriptListener onResult,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    _onDone = onDone;
    final ready = await ensureReady();
    if (!ready) {
      onError('Microphone access is off. Enable it in Settings to speak an entry.');
      return;
    }
    try {
      await _speech.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (error, stack) {
      _log.warning('speech listen failed', error, stack);
      onError('Could not start listening. Try again.');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (error, stack) {
      _log.warning('speech stop failed', error, stack);
    }
  }
}

final speechServiceProvider = Provider<SpeechService>(
  (ref) => SpeechToTextService(),
  name: 'speechService',
);
