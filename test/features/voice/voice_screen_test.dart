import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/theme/app_theme.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/voice/data/speech_service.dart';
import 'package:finroot_mobile/features/voice/presentation/voice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSpeech implements SpeechService {
  TranscriptListener? onResult;
  @override
  bool isListening = false;
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<void> start({
    required TranscriptListener onResult,
    required void Function() onDone,
    required void Function(String message) onError,
  }) async {
    this.onResult = onResult;
    isListening = true;
  }

  @override
  Future<void> stop() async => isListening = false;
}

class _FakeQuickAdd implements QuickAddController {
  int calls = 0;
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
    calls++;
    return 'x';
  }

  @override
  Future<void> deleteTransaction(String id) async {}
}

void main() {
  testWidgets('idle shows the prompt and the mic', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(_FakeSpeech()),
        quickAddControllerProvider.overrideWithValue(_FakeQuickAdd()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const VoiceScreen()),
    ));
    await tester.pump();
    expect(find.text('Tap to speak an entry'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('speaking a sentence lands on the review form', (tester) async {
    final speech = _FakeSpeech();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(speech),
        quickAddControllerProvider.overrideWithValue(_FakeQuickAdd()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const VoiceScreen()),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    speech.onResult!('spent 250 on lunch with card', true);
    await tester.pumpAndSettle();

    expect(find.text('Log it'), findsOneWidget);
    expect(find.textContaining('spent 250 on lunch'), findsOneWidget);
    // parsed amount prefilled
    expect(find.widgetWithText(TextField, '250'), findsOneWidget);
  });
}
