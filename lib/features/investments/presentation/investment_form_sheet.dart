import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../application/investment_editor_controller.dart';
import '../data/symbol_search_gateway.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
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
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = InvestmentDraft(
      asset: _asset,
      name: _name.text,
      invested: Money.tryParse(_invested.text)!,
      current: Money.tryParse(_current.text)!,
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
                'With a ticker, the live value is price x quantity; the '
                'current value below stays as the saved fallback.',
            helperMaxLines: 3,
          ),
          validator: InvestmentValidators.quantity,
        ),
      ),
    ];
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
