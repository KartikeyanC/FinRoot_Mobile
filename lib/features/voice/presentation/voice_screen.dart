import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../application/voice_capture_controller.dart';

/// Voice capture (M14) — say an expense ("spent 400 on groceries with card
/// yesterday"), the transcript is parsed on-device to a Quick Add draft, you
/// review, and it logs through the normal write path. No server, no menu gate.
/// Speech recognition is device-unverified (no Android SDK).
class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceCaptureControllerProvider);
    final c = ref.read(voiceCaptureControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice entry'),
        actions: [
          if (state.phase == VoicePhase.review)
            TextButton(onPressed: c.reset, child: const Text('Start over')),
        ],
      ),
      body: switch (state.phase) {
        VoicePhase.review => _Review(state: state),
        _ => _Listen(state: state),
      },
    );
  }
}

class _Listen extends ConsumerWidget {
  const _Listen({required this.state});
  final VoiceCaptureState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(voiceCaptureControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final listening = state.phase == VoicePhase.listening;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            listening ? 'Listening…' : 'Tap to speak an entry',
            style: tt.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.transcript.isNotEmpty
                ? '“${state.transcript}”'
                : 'e.g. “spent 400 on groceries with card yesterday”',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          _MicButton(
            listening: listening,
            onTap: listening ? c.stopListening : c.startListening,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Start listening',
      child: InkResponse(
        onTap: onTap,
        radius: 64,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? scheme.error : scheme.primary,
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            size: 40,
            color: listening ? scheme.onError : scheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.state});
  final VoiceCaptureState state;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final d = widget.state.draft!;
    _amount = TextEditingController(
      text: d.amount == null ? '' : d.amount!.amount.toString(),
    );
    _note = TextEditingController(text: d.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  VoiceCaptureController get _c =>
      ref.read(voiceCaptureControllerProvider.notifier);

  Future<void> _log() async {
    _c.editDraft(
      amount: Money.tryParse(_amount.text),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _c.confirm();
      messenger.showSnackBar(
        const SnackBar(content: Text('Logged from voice')),
      );
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(voiceCaptureControllerProvider).draft!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cats = d.kind == QuickAddKind.income
        ? kIncomeCategories
        : kExpenseCategories;
    final category = d.category != null && cats.contains(d.category)
        ? d.category
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        Text('“${d.transcript}”',
            style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
        if (d.kind == QuickAddKind.transfer)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: AppRadius.field,
            ),
            child: Text(
              'That sounds like a transfer. Transfers need two accounts — '
              'use Quick Add for those.',
              style: tt.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        SegmentedButton<QuickAddKind>(
          segments: const [
            ButtonSegment(value: QuickAddKind.expense, label: Text('Expense')),
            ButtonSegment(value: QuickAddKind.income, label: Text('Income')),
          ],
          selected: {
            d.kind == QuickAddKind.income
                ? QuickAddKind.income
                : QuickAddKind.expense,
          },
          onSelectionChanged: (s) => _c.editDraft(kind: s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          items: [
            for (final cat in cats)
              DropdownMenuItem(value: cat, child: Text(cat)),
          ],
          onChanged: (v) => _c.editDraft(category: v),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: d.paymentMode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Payment mode (optional)',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: [
            const DropdownMenuItem<String>(child: Text('Not set')),
            for (final m in kPaymentModes)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) => _c.editDraft(paymentMode: v),
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: d.occurredAt.isAfter(now) ? now : d.occurredAt,
              firstDate: DateTime(now.year - 5),
              lastDate: now,
            );
            if (picked != null) {
              _c.editDraft(
                occurredAt: DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  d.occurredAt.hour,
                  d.occurredAt.minute,
                ),
              );
            }
          },
          borderRadius: AppRadius.field,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            child: Text(DateFormat('EEE, d MMM yyyy').format(d.occurredAt)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: d.kind == QuickAddKind.transfer ? null : _log,
          child: const Text('Log it'),
        ),
      ],
    );
  }
}
