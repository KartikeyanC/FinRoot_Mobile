import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../../navigation/quick_add_entry.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../../quick_add/presentation/quick_add_sheet.dart';
import '../application/payment_capture_controller.dart';
import '../data/payment_capture_gateway.dart';
import '../domain/detected_payment.dart';

/// Payments FinRoot noticed in your UPI / bank app notifications, waiting for
/// one tap to add (or ignore). Nothing reaches the ledger without that tap.
class DetectedPaymentsScreen extends ConsumerStatefulWidget {
  const DetectedPaymentsScreen({super.key, this.addNoticeId});

  /// Opened from a payment pop-up: go straight to Quick Add for the payment
  /// this notice belongs to.
  final String? addNoticeId;

  @override
  ConsumerState<DetectedPaymentsScreen> createState() =>
      _DetectedPaymentsScreenState();
}

class _DetectedPaymentsScreenState
    extends ConsumerState<DetectedPaymentsScreen> {
  // Payments arrive while FinRoot is in the background, and the user comes
  // back here from the system's Notification access page.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(paymentCaptureProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    if (widget.addNoticeId case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNotice(id));
    }
  }

  Future<void> _openNotice(String noticeId) async {
    // The pop-up's notice arrived after the list was last loaded.
    await ref.read(paymentCaptureProvider.notifier).refresh();
    if (!mounted) return;
    final payment = ref
        .read(paymentCaptureProvider)
        .value
        ?.payments
        .where((p) => p.noticeIds.contains(noticeId))
        .firstOrNull;
    // Null when it was already added or ignored — the list is shown as is.
    if (payment != null) await addDetectedPayment(context, ref, payment);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentCaptureProvider);
    final ledger = ref.watch(recentLedgerForMatchingProvider).value ?? const [];
    final notifier = ref.read(paymentCaptureProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Detected payments')),
      body: switch (async) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ContentBounds(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                if (!value.status.supported)
                  const EmptyView(
                    icon: Icons.phone_android_outlined,
                    title: 'Available on Android',
                    message:
                        'Payment detection reads payment notifications, which '
                        'only Android lets an app do.',
                  )
                else if (!value.status.included)
                  const EmptyView(
                    icon: Icons.shield_outlined,
                    title: 'Not in this version',
                    message:
                        'Automatic payment detection needs access to your '
                        'notifications. Google Play Protect blocks that for apps '
                        'installed outside the Play Store, so this version leaves '
                        'it out. Add payments with Quick Add instead.',
                  )
                else ...[
                  _SetupCard(status: value.status),
                  if (value.status.active) ...[
                    const SizedBox(height: AppSpacing.xl),
                    if (value.payments.isEmpty)
                      const EmptyView(
                        icon: Icons.bolt_outlined,
                        title: 'No new payments',
                        message:
                            'Pay with Google Pay, PhonePe, Paytm or your bank '
                            'app and the payment shows up here, ready to add '
                            'in one tap.',
                      )
                    else ...[
                      SectionHeader('To review (${value.payments.length})'),
                      for (final p in value.payments) ...[
                        _PaymentCard(
                          payment: p,
                          alreadyRecorded: looksAlreadyRecorded(p, ledger),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
        AsyncError(:final error) => ErrorView(error, onRetry: notifier.refresh),
        _ => const LoadingView(),
      },
    );
  }
}

class _SetupCard extends ConsumerWidget {
  const _SetupCard({required this.status});
  final PaymentCaptureStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(paymentCaptureProvider.notifier);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = t.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: status.enabled,
            onChanged: notifier.setEnabled,
            title: const Text('Detect my payments'),
            subtitle: const Text(
              'Reads payment notifications from Google Pay, PhonePe, Paytm '
              'and bank apps.',
            ),
          ),
          if (status.enabled && !status.hasAccess)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'One more step: turn on FinRoot under Notification access.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: notifier.openAccessSettings,
                    child: const Text('Open Notification access'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Installed FinRoot from an APK file? If Android says '
                    '"Restricted setting", open Settings → Apps → FinRoot → '
                    '⋮ → Allow restricted settings, then try again.',
                    style: muted,
                  ),
                ],
              ),
            ),
          if (status.enabled) ...[
            SwitchListTile(
              value: status.popupEnabled,
              onChanged: notifier.setPopupEnabled,
              title: const Text('Pop up when I pay'),
              subtitle: const Text(
                'Shows "₹500 paid — add to FinRoot?" right away. Tap it to '
                'add the payment.',
              ),
            ),
            if (status.popupEnabled && !status.canPostNotifications)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: OutlinedButton(
                  onPressed: notifier.requestPopupPermission,
                  child: const Text('Allow FinRoot notifications'),
                ),
              ),
          ],
          if (status.enabled)
            SwitchListTile(
              value: status.smsEnabled,
              onChanged: notifier.setSmsEnabled,
              title: const Text('Include bank SMS alerts'),
              subtitle: const Text(
                'Catches payments made by card, net banking or any UPI app. '
                'OTPs are never kept.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Stays on this phone. Nothing is saved until you tap Add.',
                    style: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens Quick Add filled in from [p]; once saved, it leaves the queue.
Future<void> addDetectedPayment(
  BuildContext context,
  WidgetRef ref,
  DetectedPayment p,
) async {
  final saved = await openQuickAdd(
    context,
    kind: p.isPaid ? QuickAddKind.expense : QuickAddKind.income,
    prefill: QuickAddPrefill(
      amount: p.amount,
      // The note is what identifies the payment later (and is searchable).
      note: [
        if (p.counterparty != null) p.headline,
        if (p.reference != null) 'Ref ${p.reference}',
      ].join(' · '),
      paymentMode: p.paymentMode,
      occurredAt: p.occurredAt,
    ),
  );
  if (saved == true) {
    await ref.read(paymentCaptureProvider.notifier).resolve(p);
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.payment, required this.alreadyRecorded});

  final DetectedPayment payment;
  final bool alreadyRecorded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final type = p.isPaid ? TxnType.expense : TxnType.income;
    final when =
        '${RelativeTime.dayLabel(p.occurredAt)}, '
        '${DateFormat.jm().format(p.occurredAt)}';
    final muted = t.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(
                  p.isPaid
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 20,
                  color: p.isPaid ? finance.expense : finance.income,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.headline,
                      style: t.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('${p.sources.join(' + ')} · $when', style: muted),
                    if (p.reference != null)
                      Text('Ref ${p.reference}', style: muted),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AmountText.money(p.amount, type: type),
            ],
          ),
          if (alreadyRecorded) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.tertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Looks already added — a ${type.name} of the same amount '
                    'is in your ledger around this time.',
                    style: t.bodySmall?.copyWith(color: scheme.tertiary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(paymentCaptureProvider.notifier).resolve(p),
                  child: const Text('Ignore'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => addDetectedPayment(context, ref, p),
                  child: Text(p.isPaid ? 'Add expense' : 'Add income'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
