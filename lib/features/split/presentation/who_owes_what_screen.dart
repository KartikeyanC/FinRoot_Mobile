import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/split_providers.dart';
import '../data/split_dues_gateway.dart';
import '../domain/split_dues.dart';
import 'split_state_views.dart';
import 'split_with_friends_screen.dart';

/// Who owes what (web WhoOwesWhat): open dues per person and currency, net of
/// what you owe them; settle fully or partly; settled history. Online-only.
class WhoOwesWhatScreen extends ConsumerWidget {
  const WhoOwesWhatScreen({super.key});

  static const route = '/who-owes-what';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final dues = ref.watch(splitDuesProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    Widget body;
    if (!online && !dues.hasValue) {
      body = const OnlineOnlyView(feature: 'Who owes what');
    } else {
      body = dues.when(
        loading: () => const LoadingView(),
        error: (e, _) => e is SplitDuesMissing
            ? const SplitDuesMissingView()
            : ErrorView(e, onRetry: () => ref.invalidate(splitDuesProvider)),
        data: (list) => _DuesBody(
          dues: list,
          canWrite: canWrite && online,
          offline: !online,
        ),
      );
    }

    return AppPage(
      title: 'Who owes what',
      padBody: false,
      floatingActionButton: canWrite && online && dues.hasValue
          ? AddFab(
              label: 'Split',
              icon: Icons.call_split,
              onPressed: () => context.push(SplitWithFriendsScreen.route),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(splitDuesProvider),
        child: body,
      ),
    );
  }
}

class _DuesBody extends StatefulWidget {
  const _DuesBody({
    required this.dues,
    required this.canWrite,
    required this.offline,
  });

  final List<SplitDue> dues;
  final bool canWrite;
  final bool offline;

  @override
  State<_DuesBody> createState() => _DuesBodyState();
}

class _DuesBodyState extends State<_DuesBody> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final groups = duesByPerson(widget.dues);
    final settled = [
      for (final d in widget.dues)
        if (d.isSettled) d,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        96,
      ),
      children: [
        if (widget.offline)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: InlineNote(
              "You're offline — settling needs a connection.",
              warning: true,
              icon: Icons.cloud_off_outlined,
            ),
          ),
        FilterPills<bool>(
          options: [
            FilterPill(false, 'Open (${groups.length})'),
            FilterPill(true, 'Settled (${settled.length})'),
          ],
          selected: _history,
          onSelected: (v) => setState(() => _history = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!_history) ...[
          if (groups.isEmpty)
            const CardEmpty(
              icon: Icons.handshake_outlined,
              title: 'All square',
              message:
                  'Split a bill with friends or settle a trip, and who owes '
                  'what shows here.',
            )
          else ...[
            _Totals(groups: groups),
            for (final g in groups)
              _PersonCard(balance: g, canWrite: widget.canWrite),
          ],
        ] else if (settled.isEmpty)
          const CardEmpty(icon: Icons.history, title: 'Nothing settled yet')
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [for (final d in settled) _SettledRow(due: d)],
            ),
          ),
      ],
    );
  }
}

String _fmt(double v, String ccy) => MoneyFormat.money(v, currency: ccy);

class _Totals extends StatelessWidget {
  const _Totals({required this.groups});
  final List<PersonBalance> groups;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final byCcy = <String, (int, int)>{};
    for (final g in groups) {
      final cur = byCcy[g.currency] ?? (0, 0);
      byCcy[g.currency] = (
        cur.$1 + toPaise(g.owedToMe),
        cur.$2 + toPaise(g.iOwe),
      );
    }
    return Column(
      children: [
        for (final e in byCcy.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: StatStrip([
              Stat(
                _fmt(fromPaise(e.value.$1), e.key),
                'Owed to you',
                color: finance.income,
              ),
              Stat(
                _fmt(fromPaise(e.value.$2), e.key),
                'You owe',
                color: finance.expense,
              ),
              Stat(_fmt(fromPaise(e.value.$1 - e.value.$2), e.key), 'Net'),
            ]),
          ),
      ],
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.balance, required this.canWrite});
  final PersonBalance balance;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final finance = context.finance;
    final b = balance;
    final net = b.net;
    final headline = net > 0
        ? 'Owes you ${_fmt(net, b.currency)}'
        : net < 0
        ? 'You owe ${_fmt(-net, b.currency)}'
        : 'Even';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(
                  icon: Icons.person_outline,
                  size: 40,
                  round: true,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.person,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        headline,
                        style: AppTypography.caption.copyWith(
                          color: net > 0
                              ? finance.income
                              : net < 0
                              ? finance.expense
                              : palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final d in b.dues) _OpenDueRow(due: d, canWrite: canWrite),
          ],
        ),
      ),
    );
  }
}

class _OpenDueRow extends ConsumerWidget {
  const _OpenDueRow({required this.due, required this.canWrite});
  final SplitDue due;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final left = remainingOf(due);
    final owed = due.direction == DueDirection.owedToMe;
    final label = [
      owed ? 'Owes you' : 'You owe',
      if (due.note?.isNotEmpty == true) due.note!,
      if (due.settledAmount > 0)
        '${_fmt(due.settledAmount, due.currency)} of '
            '${_fmt(due.amount, due.currency)} paid',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: palette.muted),
            ),
          ),
          Text(
            _fmt(left, due.currency),
            style: AppTypography.bodyStrong.copyWith(color: palette.ink),
          ),
          if (canWrite)
            TextButton(
              onPressed: () => _settle(context, ref, due),
              child: const Text('Settle'),
            ),
        ],
      ),
    );
  }
}

Future<void> _settle(BuildContext context, WidgetRef ref, SplitDue due) async {
  final left = remainingOf(due);
  final amount = await showDialog<double>(
    context: context,
    builder: (_) => _SettleDialog(due: due, left: left),
  );
  if (amount == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    // Full: let the server settle whatever is left (p_amount NULL).
    await ref
        .read(splitDuesControllerProvider)
        .settle(due.id, amount: amount >= left ? null : amount);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          amount >= left
              ? 'Marked settled'
              : '${_fmt(amount, due.currency)} settled',
        ),
      ),
    );
  } on SplitDuesMissing {
    messenger.showSnackBar(
      const SnackBar(content: Text(kSplitDuesMissingMessage)),
    );
  } on Failure catch (f) {
    messenger.showSnackBar(SnackBar(content: Text(f.message)));
  }
}

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.due, required this.left});
  final SplitDue due;
  final double left;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final _amount = TextEditingController(
    text: widget.left.toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _ok() {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    // Over-settling is capped (the server does the same).
    Navigator.pop(context, v > widget.left ? widget.left : v);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.due;
    final who = d.direction == DueDirection.owedToMe
        ? '${d.person} paid you'
        : 'You paid ${d.person}';
    return AlertDialog(
      title: Text('Settle with ${d.person}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_fmt(widget.left, d.currency)} left. $who:'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('settle-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: d.currency,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, widget.left),
          child: const Text('Settle all'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Settle')),
      ],
    );
  }
}

class _SettledRow extends StatelessWidget {
  const _SettledRow({required this.due});
  final SplitDue due;

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(due.settledAt ?? '')?.toLocal();
    return ListRow(
      icon: Icons.check_circle_outline,
      title: due.person,
      subtitle: [
        due.direction == DueDirection.owedToMe ? 'Paid you' : 'You paid',
        if (due.note?.isNotEmpty == true) due.note!,
        if (at != null) '${at.day}/${at.month}/${at.year}',
      ].join(' · '),
      trailing: Text(_fmt(due.amount, due.currency)),
    );
  }
}
