import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../price_alerts/domain/price_alert.dart' show formatPrice;
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../data/live_price_gateway.dart';
import '../data/symbol_search_gateway.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import '../domain/symbol_search.dart';

Future<void> openInvestmentForm(
  BuildContext context, {
  InvestmentRecord? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _InvestmentFormSheet(editing: editing),
  );
}

class _InvestmentFormSheet extends ConsumerStatefulWidget {
  const _InvestmentFormSheet({this.editing});
  final InvestmentRecord? editing;

  @override
  ConsumerState<_InvestmentFormSheet> createState() =>
      _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<_InvestmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _invested = TextEditingController();
  final _current = TextEditingController();
  final _ticker = TextEditingController();
  final _quantity = TextEditingController();
  late String _asset;
  Timer? _searchTimer;
  int _searchId = 0;
  List<SymbolHit> _hits = const [];
  bool _searching = false;
  String? _goal;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  double get _qty => double.tryParse(_quantity.text.trim()) ?? 0;

  /// Priceable asset with a ticker and a quantity: the current value comes
  /// from the live price, not from the user.
  bool get _autoValue =>
      isPriceableAsset(_asset) &&
      _ticker.text.trim().isNotEmpty &&
      _qty > 0;

  /// A throwaway record for the typed ticker/quantity, so the same symbol
  /// resolution as the holding rows is used.
  InvestmentRecord _probe() => InvestmentRecord(
    id: '',
    asset: _asset,
    currency: 'INR',
    fields: {
      'ticker': _ticker.text.trim(),
      if (_asset == 'mutual_funds') 'units': _quantity.text.trim()
      else 'quantity': _quantity.text.trim(),
    },
    derived: const {},
  );

  LiveHolding? _liveNow() {
    final prices = <String, double>{
      ...(ref.read(holdingPricesProvider).value ?? const {}),
      ..._fetched,
    };
    return liveFor(_probe(), prices);
  }

  /// Prices fetched for the typed ticker (it may not be a saved holding yet).
  Map<String, double> _fetched = const {};
  Timer? _priceTimer;
  int _priceId = 0;

  Future<Map<String, double>> _lookup() async {
    final want = resolveLiveSymbol(_probe());
    if (want == null) return const {};
    try {
      return await ref.read(livePriceGatewayProvider).fetch([want]);
    } catch (_) {
      return const {};
    }
  }

  void _schedulePrice() {
    _priceTimer?.cancel();
    if (!_autoValue) return;
    final id = ++_priceId;
    _priceTimer = Timer(const Duration(milliseconds: 500), () async {
      final got = await _lookup();
      if (!mounted || id != _priceId || got.isEmpty) return;
      setState(() => _fetched = got);
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _asset = e?.asset ?? 'stocks';
    if (e != null) {
      _name.text = e.name;
      _invested.text = e.invested.amount.toString();
      _current.text = e.current.amount.toString();
      _goal = e.goal;
      _ticker.text = tickerTextOf(e);
      _quantity.text = quantityTextOf(e);
    }
  }

  void _onTickerChanged(String v) {
    _searchTimer?.cancel();
    _schedulePrice();
    setState(() {});
    final id = ++_searchId;
    if (v.trim().length < minSymbolQuery) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final found = await ref
          .read(symbolSearchGatewayProvider)
          .search(asset: _asset, query: v);
      if (!mounted || id != _searchId) return;
      setState(() {
        _hits = found;
        _searching = false;
      });
    });
  }

  void _pick(SymbolHit hit) {
    _clearSearch();
    _ticker.text = hit.ticker;
    if (_name.text.trim().isEmpty) _name.text = hit.name;
    _schedulePrice();
    setState(() {});
  }

  void _clearSearch() {
    _searchId++;
    _searchTimer?.cancel();
    _hits = const [];
    _searching = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _invested.dispose();
    _current.dispose();
    _ticker.dispose();
    _quantity.dispose();
    _searchTimer?.cancel();
    _priceTimer?.cancel();
    super.dispose();
  }

  /// Best-effort fresh live value for the typed ticker (null when the price
  /// is not known yet); never throws.
  Future<double?> _fetchLiveValue() async {
    final known = _liveNow()?.value;
    if (known != null) return known;
    return liveFor(_probe(), await _lookup())?.value;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Money current;
    if (_autoValue) {
      final live = (await _fetchLiveValue()) ?? _liveNow()?.value;
      current = live != null
          ? Money(Decimal.parse(live.toStringAsFixed(2)))
          : (_isEditing
                ? widget.editing!.current
                : Money.tryParse(_invested.text)!);
    } else {
      current = Money.tryParse(_current.text)!;
    }
    final draft = InvestmentDraft(
      asset: _asset,
      name: _name.text,
      invested: Money.tryParse(_invested.text)!,
      current: current,
      goal: _goal,
      ticker: isPriceableAsset(_asset) ? _ticker.text : '',
      quantity: isPriceableAsset(_asset) ? _quantity.text : '',
      baseFields: widget.editing?.fields ?? const {},
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(investmentEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!.id, draft);
      } else {
        await c.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Holding updated' : 'Holding added')),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f;
      });
    }
  }

  List<Widget> _liveFields(BuildContext context) {
    final palette = context.palette;
    final fund = _asset == 'mutual_funds';
    final crypto = _asset == 'crypto';
    final helper = fund
        ? 'Type a fund name to search, or enter the scheme code.'
        : crypto
        ? 'Type a coin to search, or enter its code, e.g. BTC.'
        : 'Type a company to search, or enter e.g. NSE:RELIANCE or ITC.NS.';
    return [
      LabeledField(
        label: fund
            ? 'Scheme code (optional)'
            : crypto
            ? 'Coin (optional)'
            : 'Ticker (optional)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _ticker,
              textCapitalization: fund
                  ? TextCapitalization.none
                  : TextCapitalization.characters,
              autocorrect: false,
              onChanged: _onTickerChanged,
              decoration: InputDecoration(
                hintText: fund ? '119551' : (crypto ? 'BTC' : 'NSE:RELIANCE'),
                prefixIcon: const Icon(Icons.search),
                helperText: helper,
                helperMaxLines: 2,
              ),
              validator: (v) => InvestmentValidators.ticker(v, asset: _asset),
            ),
            if (_searching && _hits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Searching...',
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
              ),
            for (final hit in _hits)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pick(hit),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        hit.exchange.isEmpty
                            ? hit.ticker
                            : '${hit.ticker} · ${hit.exchange}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      LabeledField(
        label: fund ? 'Units (optional)' : 'Quantity (optional)',
        child: TextFormField(
          controller: _quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.numbers),
            helperText:
                'With a ticker and quantity, the current value follows the '
                'live price automatically.',
            helperMaxLines: 3,
          ),
          onChanged: (_) {
            _schedulePrice();
            setState(() {});
          },
          validator: InvestmentValidators.quantity,
        ),
      ),
    ];
  }

  Widget _autoValueRow(BuildContext context) {
    final palette = context.palette;
    ref.watch(holdingPricesProvider);
    final value = _liveNow()?.value;
    final symbol = resolveLiveSymbol(_probe())?.symbol ?? '';
    return LabeledField(
      label: 'Current value',
      child: Container(
        key: const ValueKey('auto-current-value'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 18, color: palette.muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value != null
                        ? formatPrice(symbol, value)
                        : 'Calculated once the live price loads',
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    'Updates automatically from the live price',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      formKey: _formKey,
      title: _isEditing ? 'Edit holding' : 'Add holding',
      subtitle:
          'Invested and current value. For stocks, crypto and funds add a '
          'ticker and quantity to see the live price. The web app has the '
          'detailed per-asset calculators.',
      primaryLabel: _isEditing ? 'Save changes' : 'Add holding',
      onPrimary: _submit,
      busy: _busy,
      error: _error?.message,
      children: [
        LabeledField(
          label: 'Asset type',
          child: DropdownButtonFormField<String>(
            initialValue: _asset,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final a in kAssetTypes)
                DropdownMenuItem(
                  value: a,
                  child: Row(
                    children: [
                      Icon(assetIcon(a), size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          assetLabel(a),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _asset = v ?? _asset;
              _clearSearch();
            }),
          ),
        ),
        LabeledField(
          label: 'Name',
          child: TextFormField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'ITC, Nifty 50 fund…',
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: InvestmentValidators.name,
          ),
        ),
        if (isPriceableAsset(_asset)) ..._liveFields(context),
        LabeledField(
          label: 'Amount invested',
          child: TextFormField(
            controller: _invested,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.south_west_rounded),
            ),
            validator: (v) =>
                InvestmentValidators.amount(v, label: 'the amount invested'),
          ),
        ),
        if (_autoValue)
          _autoValueRow(context)
        else
          LabeledField(
          label: 'Current value',
          child: TextFormField(
            controller: _current,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.trending_up),
            ),
            validator: (v) =>
                InvestmentValidators.amount(v, label: 'the current value'),
          ),
        ),
        LabeledField(
          label: 'Goal link (optional)',
          child: DropdownButtonFormField<String>(
            initialValue: _goal,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(child: Text('Not set')),
              for (final g in kInvestmentGoals)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _goal = v),
          ),
        ),
      ],
    );
  }
}
