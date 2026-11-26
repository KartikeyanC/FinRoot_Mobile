import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';
import 'trip_list_screen.dart';

/// Open the New trip form; resolves to the new trip's id, or null.
Future<String?> openNewTripScreen(BuildContext context) => Navigator.of(context)
    .push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NewTripScreen(),
      ),
    );

/// Plan a trip on the phone (web NewTripDialog): name, type, dates, the
/// currency it's kept in, companions, and how much each account puts into
/// the trip's pool.
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key});

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  final _name = TextEditingController();
  final _days = TextEditingController(text: '5');
  final _companions = TextEditingController();
  final _amounts = <String, TextEditingController>{};
  String _kind = 'solo';
  String _currency = 'INR';
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _companions.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _amountFor(String id) =>
      _amounts.putIfAbsent(id, () => TextEditingController());

  Map<String, double> get _allocation => {
    for (final e in _amounts.entries)
      if ((double.tryParse(e.value.text.trim().replaceAll(',', '')) ?? 0) > 0)
        e.key: double.parse(e.value.text.trim().replaceAll(',', '')),
  };

  double get _total => _allocation.values.fold(0.0, (s, n) => s + n);

  NewTrip get _draft => NewTrip(
    name: _name.text,
    kind: _kind,
    days: int.tryParse(_days.text.trim()) ?? 1,
    startDate: _start,
    companions: parseCompanions(_companions.text),
    allocation: _allocation,
    currency: _currency,
  );

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _submit() async {
    final draft = _draft;
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(tripsControllerProvider).create(draft);
      messenger.showSnackBar(
        SnackBar(content: Text('Trip "${draft.name.trim()}" created')),
      );
      navigator.pop(id);
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
    final accounts = [
      for (final a
          in ref.watch(workspaceAccountsProvider).value ??
              const <AccountEntity>[])
        // The virtual Physical Cash below stands for every cash account (web).
        if (a.type != 'cash') a,
    ];
    final symbol = currencySymbol(_currency);
    final prefix = symbol.isEmpty ? '$_currency ' : '$symbol ';
    final ml = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New trip')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.md,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          TextField(
            key: const Key('new-trip-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Trip name',
              hintText: 'e.g. Himachal solo run',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Trip type',
            style: AppTypography.label.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final k in kTripKindLabels.keys)
                ChoiceChip(
                  avatar: Icon(tripKindIcon(k), size: 18),
                  label: Text(kTripKindLabels[k]!),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStart,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Starts'),
                    child: Text(ml.formatMediumDate(_start)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 96,
                child: TextField(
                  key: const Key('new-trip-days'),
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Days'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('new-trip-currency'),
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              helperText: 'Budget, spends and settle-up are all kept in it.',
            ),
            items: [
              for (final c in kTripCurrencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
          if (_kind != 'solo') ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('new-trip-companions'),
              controller: _companions,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Companions',
                hintText: 'Riya, Aman, Neha',
                helperText:
                    'Comma separated, up to $kTripMaxCompanions. '
                    'You are always in the trip.',
              ),
            ),
          ],
          const SectionTitle('Fund the trip'),
          Text(
            'How much each account puts into the trip pool.',
            style: AppTypography.caption.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _AllocationRow(
                  key: const Key('new-trip-fund-_cash'),
                  icon: Icons.payments_outlined,
                  name: 'Physical Cash',
                  prefix: prefix,
                  controller: _amountFor(kTripCashAccountId),
                  onChanged: () => setState(() {}),
                ),
                for (final a in accounts)
                  _AllocationRow(
                    key: Key('new-trip-fund-${a.id}'),
                    icon: a.type == 'credit'
                        ? Icons.credit_card_outlined
                        : a.type == 'wallet'
                        ? Icons.smartphone_outlined
                        : Icons.account_balance_outlined,
                    name: a.name,
                    prefix: prefix,
                    controller: _amountFor(a.id),
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trip pool',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
              ),
              Text(
                MoneyFormat.money(_total, currency: _currency),
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
            ],
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
            key: const Key('new-trip-create'),
            label: _busy ? 'Saving…' : 'Start trip',
            icon: Icons.flight_takeoff_rounded,
            expand: true,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    super.key,
    required this.icon,
    required this.name,
    required this.prefix,
    required this.controller,
    required this.onChanged,
  });

  final IconData icon;
  final String name;
  final String prefix;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: palette.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: palette.ink),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: prefix,
                hintText: '0',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
