import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/split_providers.dart';
import '../domain/split_dues.dart';
import 'split_state_views.dart';

/// Starting values: the expense Quick Add just saved (then [editingId] is its
/// id, and saving turns it into your share), or nothing.
class SplitPrefill {
  const SplitPrefill({
    this.amount,
    this.category,
    this.note,
    this.occurredAt,
    this.accountId,
    this.paymentMode,
    this.editingId,
  });

  final Money? amount;
  final String? category;
  final String? note;
  final DateTime? occurredAt;
  final String? accountId;
  final String? paymentMode;
  final String? editingId;
}

class _Friend {
  _Friend(this.id)
    : name = TextEditingController(),
      amount = TextEditingController();
  final String id;
  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

/// Split a bill with friends (the phone's Smart Split): your share posts as
/// the expense through Quick Add; friends' shares become `split_dues` — they
/// owe you, or, when a friend paid, you owe them your share.
class SplitWithFriendsScreen extends ConsumerStatefulWidget {
  const SplitWithFriendsScreen({super.key, this.prefill});

  static const route = '/split';

  final SplitPrefill? prefill;

  @override
  ConsumerState<SplitWithFriendsScreen> createState() =>
      _SplitWithFriendsScreenState();
}

class _SplitWithFriendsScreenState
    extends ConsumerState<SplitWithFriendsScreen> {
  static const _mineId = 'mine';

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _total = TextEditingController();
  final _myAmount = TextEditingController();
  final _friends = <_Friend>[];
  var _nextId = 0;
  bool _equal = true;
  String _paidBy = kPaidByMe;
  late String _category;
  late String _currency;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _currency = p?.amount?.currency ?? workspaceCurrency;
    if (p?.amount != null) _total.text = p!.amount!.amount.toString();
    _name.text = p?.note ?? '';
    final cat = p?.category;
    _category = cat != null && kExpenseCategories.contains(cat)
        ? cat
        : (cat ?? kExpenseCategories.first);
    _addFriend();
  }

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _myAmount.dispose();
    for (final f in _friends) {
      f.dispose();
    }
    super.dispose();
  }

  void _addFriend() {
    final f = _Friend('f${_nextId++}');
    f.name.addListener(() => setState(() {}));
    f.amount.addListener(() => setState(() {}));
    _friends.add(f);
  }

  double get _totalNum => parseNum(_total.text.replaceAll(',', ''));

  List<Allocation> get _allocations {
    final named = [
      (
        id: _mineId,
        label: 'Your amount',
        kind: AllocationKind.mine,
        ctl: _myAmount,
      ),
      for (final f in _friends)
        if (f.name.text.trim().isNotEmpty)
          (
            id: f.id,
            label: f.name.text.trim(),
            kind: AllocationKind.shared,
            ctl: f.amount,
          ),
    ];
    // Equal: whole paise, the extra paisa to the first parts (you first), so
    // the shares always add back to the bill.
    final even = _equal
        ? splitPaise(toPaise(_totalNum), named.length)
        : const <int>[];
    return [
      for (var i = 0; i < named.length; i++)
        Allocation(
          id: named[i].id,
          label: named[i].label,
          kind: named[i].kind,
          amount: _equal
              ? fromPaise(even[i]).toStringAsFixed(2)
              : named[i].ctl.text.replaceAll(',', ''),
        ),
    ];
  }

  SplitMode get _mode => SplitMode.amount;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final allocations = _allocations;
    if (allocations.length < 2) {
      setState(() => _error = 'Add at least one friend.');
      return;
    }
    final total = _totalNum;
    if (!_equal) {
      final allocated = allocatedOf(allocations, _mode, total);
      if ((allocated - total).abs() >= 0.005) {
        setState(
          () => _error =
              'Shares add up to ${MoneyFormat.money(allocated, currency: _currency)}'
              ' — they must make ${MoneyFormat.money(total, currency: _currency)}.',
        );
        return;
      }
    }
    final paidBy = allocations.any((a) => a.id == _paidBy)
        ? _paidBy
        : kPaidByMe;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final p = widget.prefill;
      final outcome = await ref
          .read(splitWithFriendsControllerProvider)
          .save(
            allocations: allocations,
            mode: _mode,
            total: total,
            currency: _currency,
            paidBy: paidBy,
            category: _category,
            occurredAt: p?.occurredAt ?? DateTime.now(),
            name: _name.text,
            accountId: p?.accountId,
            paymentMode: p?.paymentMode,
            editingId: p?.editingId,
          );
      if (navigator.canPop()) navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome == SplitSaveOutcome.saved
                ? 'Split saved — your share is in your expenses'
                : 'Your share is saved. $kSplitDuesMissingMessage',
          ),
        ),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final online = ref.watch(isOnlineProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final allocations = _allocations;
    final total = _totalNum;
    final mine = myShareOf(allocations, _mode, total);
    final payers = allocations.where((a) => a.kind == AllocationKind.shared);
    String fmt(double v) => MoneyFormat.money(v, currency: _currency);

    return AppPage(
      title: 'Split with friends',
      padBody: false,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.xs,
            AppSpacing.screenGutter,
            AppSpacing.huge,
          ),
          children: [
            if (!canWrite)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: InlineNote(
                  'Your role in this workspace is view-only.',
                  warning: true,
                ),
              )
            else if (!online)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: InlineNote(
                  "You're offline. Splitting needs a connection so friends' "
                  'shares are recorded with your expense.',
                  warning: true,
                  icon: Icons.cloud_off_outlined,
                ),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('split-total'),
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Bill amount',
                      suffixText: _currency,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        _totalNum > 0 ? null : 'Enter the bill amount',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'What for (optional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in {...kExpenseCategories, _category})
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                ],
              ),
            ),
            SectionTitle(
              'People',
              trailing: TextButton.icon(
                onPressed: () => setState(_addFriend),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Add friend'),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Equal')),
                ButtonSegment(value: false, label: Text('Custom')),
              ],
              selected: {_equal},
              onSelectionChanged: (s) => setState(() => _equal = s.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text(kMe)),
                      if (_equal)
                        Text(fmt(mine), key: const Key('split-my-share'))
                      else
                        SizedBox(
                          width: 120,
                          child: TextField(
                            key: const Key('split-my-amount'),
                            controller: _myAmount,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var i = 0; i < _friends.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: Key('split-friend-$i'),
                              controller: _friends[i].name,
                              decoration: const InputDecoration(
                                hintText: 'Friend name',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (_equal)
                            Text(
                              _friends[i].name.text.trim().isEmpty
                                  ? '—'
                                  : fmt(
                                      _shareOf(
                                        _friends[i].id,
                                        allocations,
                                        total,
                                      ),
                                    ),
                            )
                          else
                            SizedBox(
                              width: 120,
                              child: TextField(
                                key: Key('split-friend-amount-$i'),
                                controller: _friends[i].amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  isDense: true,
                                ),
                              ),
                            ),
                          if (_friends.length > 1)
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                final f = _friends.removeAt(i);
                                if (_paidBy == f.id) _paidBy = kPaidByMe;
                                f.dispose();
                              }),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: const Key('split-paid-by'),
              initialValue: payers.any((a) => a.id == _paidBy)
                  ? _paidBy
                  : kPaidByMe,
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: [
                const DropdownMenuItem(value: kPaidByMe, child: Text(kMe)),
                for (final a in payers)
                  DropdownMenuItem(value: a.id, child: Text(a.label)),
              ],
              onChanged: (v) => setState(() => _paidBy = v ?? kPaidByMe),
            ),
            const SizedBox(height: AppSpacing.md),
            InlineNote(
              _paidBy == kPaidByMe || !payers.any((a) => a.id == _paidBy)
                  ? 'Your share (${fmt(mine)}) is saved as your expense; each '
                        'friend owes you theirs.'
                  : 'Your share (${fmt(mine)}) is saved as your expense, and '
                        'you owe it to ${payers.firstWhere((a) => a.id == _paidBy).label}.',
              icon: Icons.info_outline,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PillButton(
              label: _busy ? 'Saving…' : 'Save split',
              icon: Icons.call_split,
              expand: true,
              onPressed: _busy || !canWrite || !online ? null : _save,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Friends’ shares show in Who owes what. They are not '
              'expenses and move no balance.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }

  double _shareOf(String id, List<Allocation> allocations, double total) {
    for (final a in allocations) {
      if (a.id == id) return parseNum(a.amount);
    }
    return 0;
  }
}
