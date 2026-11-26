import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../split/application/split_providers.dart';
import '../../split/domain/split_dues.dart';
import '../../split/presentation/split_state_views.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';

/// Move an open trip to another currency (web TripCurrencyDialog).
Future<void> openTripCurrencySheet(BuildContext context, Trip trip) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TripCurrencySheet(trip: trip),
  );
}

/// Keep the numbers (they were typed in the new currency all along) or
/// convert them at a rate. trip_set_currency does both under one lock.
class TripCurrencySheet extends ConsumerStatefulWidget {
  const TripCurrencySheet({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<TripCurrencySheet> createState() => _TripCurrencySheetState();
}

class _TripCurrencySheetState extends ConsumerState<TripCurrencySheet> {
  late final List<String> _choices = [
    for (final c in kTripCurrencies)
      if (c != widget.trip.currency) c,
  ];
  late String _to = _choices.isEmpty ? 'INR' : _choices.first;
  bool _convert = false;
  late final _rate = TextEditingController(
    text: _rateText(suggestedTripRate(widget.trip.currency, _to)),
  );
  bool _busy = false;
  String? _error;

  static String _rateText(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();

  bool get _hasAmounts =>
      widget.trip.expenses.isNotEmpty ||
      widget.trip.allocation.values.any((n) => n > 0);

  /// null keeps the numbers; NaN when the field can't be read.
  double? get _rateValue => _hasAmounts && _convert
      ? double.tryParse(_rate.text.trim().replaceAll(',', '')) ?? double.nan
      : null;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _pick(String c) => setState(() {
    _to = c;
    _rate.text = _rateText(suggestedTripRate(widget.trip.currency, c));
  });

  Future<void> _save() async {
    final rate = _rateValue;
    if (tripCurrencyChangeProblem(widget.trip, _to, rate) != null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(tripsControllerProvider)
          .setCurrency(widget.trip.id, _to, rate: rate);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            rate == null ? 'Trip now in $_to' : 'Trip converted to $_to',
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
    final trip = widget.trip;
    final from = trip.currency;
    final rate = _rateValue;
    final problem = tripCurrencyChangeProblem(trip, _to, rate);
    double after(Iterable<double> ns) => ns.fold(
      0,
      (s, n) => s + (rate == null ? n : convertTripAmount(n, rate)),
    );
    final allocated = trip.allocation.values.fold(0.0, (s, n) => s + n);
    final spent = trip.expenses.fold(0.0, (s, e) => s + e.amount);
    final recorded = [
      for (final d in ref.watch(splitDuesProvider).value ?? const <SplitDue>[])
        if (d.source == DueSource.trip && d.sourceId == trip.id) d,
    ].isNotEmpty;
    String money(double n, String c) => MoneyFormat.money(n, currency: c);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change trip currency',
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Now $from. The budget, every expense and settle-up move to '
              'the new currency.',
              style: AppTypography.body.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              key: const Key('trip-currency-pick'),
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'New currency'),
              items: [
                for (final c in _choices)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) {
                if (v != null) _pick(v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_hasAmounts)
              Text(
                'Nothing is budgeted or logged yet, so there is nothing to '
                'convert.',
                style: AppTypography.caption.copyWith(color: palette.muted),
              )
            else ...[
              SegmentedButton<bool>(
                key: const Key('trip-currency-mode'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Keep amounts')),
                  ButtonSegment(value: true, label: Text('Convert')),
                ],
                selected: {_convert},
                onSelectionChanged: (s) => setState(() => _convert = s.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _convert
                    ? 'Every amount is multiplied by the rate and rounded to '
                          'two decimals.'
                    : 'They were typed in $_to all along; only the label '
                          'changes.',
                style: AppTypography.caption.copyWith(color: palette.muted),
              ),
              if (_convert) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('trip-currency-rate'),
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    prefixText: '1 $from = ',
                    suffixText: _to,
                    helperText:
                        "Suggested from FinRoot's fixed rates. Use the rate "
                        'you actually got.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (problem == null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineNote(
                  [
                    if (allocated > 0)
                      'Budget ${money(allocated, from)} → '
                          '${money(after(trip.allocation.values), _to)}',
                    if (trip.expenses.isNotEmpty)
                      'Spent ${money(spent, from)} → '
                          '${money(after(trip.expenses.map((e) => e.amount)), _to)}',
                  ].join('\n'),
                  icon: Icons.currency_exchange,
                ),
              ],
            ],
            if (problem != null || _error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error ?? problem!,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (recorded) ...[
              const SizedBox(height: AppSpacing.md),
              InlineNote(
                "Dues already recorded from this trip's settle-up stay in "
                '$from.',
                warning: true,
                icon: Icons.info_outline,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PillButton(
              key: const Key('trip-currency-save'),
              label: _busy ? 'Saving…' : 'Change to $_to',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _busy || problem != null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
