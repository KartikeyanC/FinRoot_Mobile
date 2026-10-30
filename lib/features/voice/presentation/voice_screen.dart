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

    return AppPage(
      title: 'Voice entry',
      subtitle: 'Say it, check it, log it',
      actions: [
        if (state.phase == VoicePhase.review)
          TextButton(onPressed: c.reset, child: const Text('Start over')),
      ],
      padBody: false,
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
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final listening = state.phase == VoicePhase.listening;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xl,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        Center(
          child: _MicButton(
            listening: listening,
            onTap: listening ? c.stopListening : c.startListening,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          listening ? 'Listening…' : 'Tap to speak an entry',
          textAlign: TextAlign.center,
          style: AppTypography.title.copyWith(color: palette.ink),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('What you said'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.transcript.isNotEmpty
                    ? '“${state.transcript}”'
                    : 'e.g. “spent 400 on groceries with card yesterday”',
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.error!,
                  style: AppTypography.bodyStrong.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final danger = context.finance.danger;
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Start listening',
      child: InkResponse(
        onTap: onTap,
        radius: 80,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (listening ? danger : palette.accent).withValues(
              alpha: 0.14,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: listening ? null : palette.gradient,
              color: listening ? AppColors.dangerFill : null,
              boxShadow: AppShadows.lift(palette.shadow),
            ),
            child: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 44,
              color: Colors.white,
            ),
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.huge,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('What you said'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '“${d.transcript}”',
                      style: AppTypography.body.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
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
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              FilterPills<QuickAddKind>(
                options: const [
                  FilterPill(QuickAddKind.expense, 'Expense'),
                  FilterPill(QuickAddKind.income, 'Income'),
                ],
                selected: d.kind == QuickAddKind.income
                    ? QuickAddKind.income
                    : QuickAddKind.expense,
                onSelected: (k) => _c.editDraft(kind: k),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Amount'),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.moneyLarge,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Category'),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Choose a category',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: [
                  for (final cat in cats)
                    DropdownMenuItem(value: cat, child: Text(cat)),
                ],
                onChanged: (v) => _c.editDraft(category: v),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Payment mode (optional)'),
              DropdownButtonFormField<String>(
                initialValue: d.paymentMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(child: Text('Not set')),
                  for (final m in kPaymentModes)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => _c.editDraft(paymentMode: v),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Date'),
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
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM yyyy').format(d.occurredAt),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Note (optional)'),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              onPressed: d.kind == QuickAddKind.transfer ? null : _log,
              child: const Text('Log it'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.label.copyWith(color: context.palette.muted),
    ),
  );
}
