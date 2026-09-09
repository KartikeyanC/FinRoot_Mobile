import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../quick_add/application/quick_add_controller.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../data/speech_service.dart';
import '../domain/voice_parse.dart';

enum VoicePhase { idle, listening, review }

class VoiceCaptureState {
  const VoiceCaptureState({
    this.phase = VoicePhase.idle,
    this.transcript = '',
    this.draft,
    this.error,
  });

  final VoicePhase phase;
  final String transcript;
  final VoiceDraft? draft;

  /// Transient — a short message, shown then cleared on the next action.
  final String? error;

  VoiceCaptureState copyWith({
    VoicePhase? phase,
    String? transcript,
    VoiceDraft? draft,
    String? error,
    bool clearError = false,
    bool clearDraft = false,
  }) => VoiceCaptureState(
    phase: phase ?? this.phase,
    transcript: transcript ?? this.transcript,
    draft: clearDraft ? null : (draft ?? this.draft),
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives voice capture: listen → live transcript → parse to a [VoiceDraft] →
/// review / correct → log via the normal Quick Add write path.
class VoiceCaptureController extends Notifier<VoiceCaptureState> {
  late final SpeechService _speech;

  @override
  VoiceCaptureState build() {
    _speech = ref.read(speechServiceProvider);
    final speech = _speech;
    ref.onDispose(() {
      if (speech.isListening) speech.stop();
    });
    return const VoiceCaptureState();
  }

  Future<void> startListening() async {
    state = const VoiceCaptureState(phase: VoicePhase.listening);
    await _speech.start(
      onResult: (transcript, isFinal) {
        state = state.copyWith(transcript: transcript);
        if (isFinal) _finish(transcript);
      },
      onDone: () {
        if (state.phase == VoicePhase.listening) _finish(state.transcript);
      },
      onError: (message) => state = const VoiceCaptureState().copyWith(
        error: message,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    if (state.phase == VoicePhase.listening) _finish(state.transcript);
  }

  void _finish(String transcript) {
    if (transcript.trim().isEmpty) {
      state = const VoiceCaptureState(
        error: 'Did not catch that — try again.',
      );
      return;
    }
    state = state.copyWith(
      phase: VoicePhase.review,
      transcript: transcript,
      draft: parseUtterance(transcript),
      clearError: true,
    );
  }

  void editDraft({
    QuickAddKind? kind,
    Money? amount,
    String? category,
    String? paymentMode,
    DateTime? occurredAt,
    String? note,
  }) {
    final d = state.draft;
    if (d == null) return;
    state = state.copyWith(
      draft: d.copyWith(
        kind: kind,
        amount: amount,
        category: category,
        paymentMode: paymentMode,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  void reset() => state = const VoiceCaptureState();

  /// Log the reviewed draft as one transaction via Quick Add.
  Future<String> confirm() async {
    final d = state.draft;
    if (d == null || !d.understood) {
      throw const ValidationFailure('Add an amount first.');
    }
    if (d.kind == QuickAddKind.transfer) {
      throw const ValidationFailure(
        'Transfers need two accounts — use Quick Add for those.',
      );
    }
    state = state.copyWith(clearError: true);
    try {
      final id = await ref.read(quickAddControllerProvider).submit(
        kind: d.kind,
        amount: d.amount!,
        occurredAt: d.occurredAt,
        category: resolvedCategory(d),
        note: d.note,
        paymentMode: d.paymentMode,
      );
      reset();
      return id;
    } on Failure catch (f) {
      state = state.copyWith(error: f.message);
      rethrow;
    }
  }
}

final voiceCaptureControllerProvider =
    NotifierProvider<VoiceCaptureController, VoiceCaptureState>(
  VoiceCaptureController.new,
  name: 'voiceCaptureController',
);
