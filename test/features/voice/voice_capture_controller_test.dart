import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/voice/application/voice_capture_controller.dart';
import 'package:finroot_mobile/features/voice/data/speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSpeech implements SpeechService {
  TranscriptListener? _onResult;
  void Function()? _onDone;
  void Function(String)? _onError;
  bool ready = true;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> ensureReady() async => ready;

  @override
  Future<void> start({
    required TranscriptListener onResult,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    if (!ready) {
      onError('Microphone access is off.');
      return;
    }
    _onResult = onResult;
    _onDone = onDone;
    _onError = onError;
    _listening = true;
  }

  @override
  Future<void> stop() async => _listening = false;

  // Test helpers
  void emit(String t, {bool isFinal = false}) => _onResult?.call(t, isFinal);
  void done() {
    _listening = false;
    _onDone?.call();
  }

  void fail(String m) => _onError?.call(m);
}

class _FakeQuickAdd implements QuickAddController {
  final List<Map<String, Object?>> submits = [];
  @override
  Future<String> submit({
    required QuickAddKind kind,
    required Money amount,
    required DateTime occurredAt,
    String? category,
    String? note,
    String? paymentMode,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? editingId,
  }) async {
    submits.add({
      'kind': kind.name,
      'amount': amount.amount.toString(),
      'category': category,
      'mode': paymentMode,
      'note': note,
    });
    return 'txn-9';
  }

  @override
  Future<void> deleteTransaction(String id) async {}
}

({ProviderContainer c, _FakeSpeech sp, _FakeQuickAdd qa}) _setup() {
  final sp = _FakeSpeech();
  final qa = _FakeQuickAdd();
  final c = ProviderContainer(
    overrides: [
      speechServiceProvider.overrideWithValue(sp),
      quickAddControllerProvider.overrideWithValue(qa),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, sp: sp, qa: qa);
}

void main() {
  test('a final result parses to a review draft', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('spent 400 on');
    expect(s.c.read(voiceCaptureControllerProvider).transcript, 'spent 400 on');
    s.sp.emit('spent 400 on groceries with card', isFinal: true);

    final st = s.c.read(voiceCaptureControllerProvider);
    expect(st.phase, VoicePhase.review);
    expect(st.draft!.amount!.amount.toDouble(), 400);
    expect(st.draft!.category, 'Food & Dining');
    expect(st.draft!.paymentMode, 'Card');
  });

  test('onDone with a partial transcript still parses', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('got 5000 salary');
    s.sp.done();
    final st = s.c.read(voiceCaptureControllerProvider);
    expect(st.phase, VoicePhase.review);
    expect(st.draft!.kind, QuickAddKind.income);
  });

  test('empty transcript -> error, back to idle', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.done();
    final st = s.c.read(voiceCaptureControllerProvider);
    expect(st.phase, VoicePhase.idle);
    expect(st.error, isNotNull);
  });

  test('permission denied surfaces the message', () async {
    final s = _setup();
    s.sp.ready = false;
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    expect(s.c.read(voiceCaptureControllerProvider).error, contains('Microphone'));
  });

  test('editDraft overrides parsed fields', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('spent 400 on groceries', isFinal: true);
    n.editDraft(amount: Money.parse('450'), category: 'Shopping');
    final d = s.c.read(voiceCaptureControllerProvider).draft!;
    expect(d.amount!.amount.toDouble(), 450);
    expect(d.category, 'Shopping');
  });

  test('confirm submits one transaction and resets', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('spent 400 on groceries with upi', isFinal: true);
    final id = await n.confirm();
    expect(id, 'txn-9');
    expect(s.qa.submits.single, {
      'kind': 'expense',
      'amount': '400',
      'category': 'Food & Dining',
      'mode': 'UPI',
      'note': 'Groceries',
    });
    expect(s.c.read(voiceCaptureControllerProvider).phase, VoicePhase.idle);
  });

  test('confirm without an amount is refused', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('bought some groceries', isFinal: true);
    await expectLater(n.confirm(), throwsA(isA<ValidationFailure>()));
    expect(s.qa.submits, isEmpty);
  });

  test('confirm refuses a transfer (needs accounts)', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('moved 5000 to savings', isFinal: true);
    await expectLater(n.confirm(), throwsA(isA<ValidationFailure>()));
  });

  test('confirm falls back to Other when no category was parsed', () async {
    final s = _setup();
    final n = s.c.read(voiceCaptureControllerProvider.notifier);
    await n.startListening();
    s.sp.emit('spent 400 on stuff', isFinal: true);
    await n.confirm();
    expect(s.qa.submits.single['category'], 'Other');
  });
}
