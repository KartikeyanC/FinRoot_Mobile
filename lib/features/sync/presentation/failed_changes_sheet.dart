import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money_format.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design.dart';
import '../application/sync_engine.dart';
import '../domain/sync_types.dart';

/// "1 change didn't sync" → Details: each change the server refused, what it
/// was, the server's exact reason, and Retry / Discard — so a stuck change
/// can always be cleared from the phone instead of nagging forever.
Future<void> showFailedChanges(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FailedChangesSheet(),
    );

/// A one-line description of what an outbox entry was going to do.
String describeChange(OutboxEntry e) {
  final p = e.payload == null ? const <String, dynamic>{} : jsonDecode(e.payload!) as Map<String, dynamic>;
  final what = switch (e.operation.name) {
    final n when n.startsWith('create') => 'New',
    final n when n.startsWith('update') => 'Edit to',
    _ => 'Delete of',
  };
  final amount = double.tryParse('${p['amount'] ?? ''}');
  final parts = [
    '$what ${p['type'] ?? 'transaction'}',
    if (amount != null) MoneyFormat.money(amount, currency: '${p['currency'] ?? 'INR'}'),
    if (p['category'] != null) '${p['category']}',
  ];
  final at = DateTime.tryParse('${p['occurred_at'] ?? ''}');
  if (at != null) parts.add(DateFormat('d MMM').format(at.toLocal()));
  return parts.join(' · ');
}

class FailedChangesSheet extends ConsumerWidget {
  const FailedChangesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(failedChangesProvider).value ?? const <OutboxEntry>[];
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter, 0, AppSpacing.screenGutter, AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Changes that didn\'t sync', style: tt.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The server refused these. Retry once the reason is fixed, or '
              'discard a change to put things back as they are on the server.',
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            if (failed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text('Everything is synced.', textAlign: TextAlign.center, style: tt.bodyLarge),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in failed)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(describeChange(e), style: tt.titleSmall),
                              const SizedBox(height: AppSpacing.xs),
                              SelectableText(
                                e.lastError ?? 'No reason was given.',
                                style: tt.bodySmall?.copyWith(color: scheme.error),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _discard(context, ref, e),
                                  child: const Text('Discard'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: failed.isEmpty
                  ? null
                  : () {
                      ref.read(syncEngineProvider.notifier).retryFailed();
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry all'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, OutboxEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard this change?'),
        content: Text(
          '${describeChange(e)}\n\n'
          '${e.operation.isCreate ? 'It will be removed from this phone.' : 'The server\'s version will be put back.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok == true) await ref.read(syncEngineProvider.notifier).discardFailed(e);
  }
}
