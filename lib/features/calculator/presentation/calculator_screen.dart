import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart' show LabeledField;
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../domain/calculations.dart';

enum _Mode { sip, lumpSum, emi }

/// Calculators: monthly SIP (with annual step-up), lump-sum growth and loan
/// EMI. Results update as you type; nothing is saved or sent anywhere.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  _Mode _mode = _Mode.sip;

  final _sipAmount = TextEditingController(text: '10000');
  final _sipRate = TextEditingController(text: '12');
  final _sipYears = TextEditingController(text: '10');
  final _sipStep = TextEditingController(text: '0');

  final _lumpAmount = TextEditingController(text: '100000');
  final _lumpRate = TextEditingController(text: '12');
  final _lumpYears = TextEditingController(text: '10');

  final _loanAmount = TextEditingController(text: '1000000');
  final _loanRate = TextEditingController(text: '9');
  final _loanYears = TextEditingController(text: '5');

  List<TextEditingController> get _all => [
    _sipAmount,
    _sipRate,
    _sipYears,
    _sipStep,
    _lumpAmount,
    _lumpRate,
    _lumpYears,
    _loanAmount,
    _loanRate,
    _loanYears,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  static double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim());

  @override
  Widget build(BuildContext context) {
    if (ref.watch(menuStatusProvider(FeatureMenu.calculator)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: 'Calculator',
        body: MenuLockedView(
          feature: 'Calculator',
          icon: Icons.calculate_outlined,
        ),
      );
    }
    return AppPage(
      title: 'Calculator',
      subtitle: 'Plan an investment or a loan',
      header: FilterPills<_Mode>(
        selected: _mode,
        onSelected: (m) => setState(() => _mode = m),
        options: const [
          FilterPill(_Mode.sip, 'SIP'),
          FilterPill(_Mode.lumpSum, 'Lump sum'),
          FilterPill(_Mode.emi, 'Loan EMI'),
        ],
      ),
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: switch (_mode) {
          _Mode.sip => _sip(context),
          _Mode.lumpSum => _lump(context),
          _Mode.emi => _emi(context),
        },
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? prefix,
    String? suffix,
    bool decimal = true,
  }) {
    return LabeledField(
      label: label,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(prefixText: prefix, suffixText: suffix),
      ),
    );
  }

  Widget _inputsCard(List<Widget> fields) => AppCard(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: fields,
    ),
  );

  List<Widget> _growthResult(
    BuildContext context,
    double? invested,
    double? future,
  ) {
    if (invested == null || future == null) {
      return const [
        CardEmpty(
          icon: Icons.calculate_outlined,
          title: 'Enter your numbers',
          message:
              'Fill in every field with a positive amount to see the result.',
        ),
      ];
    }
    final palette = context.palette;
    final income = context.finance.income;
    final gain = future - invested;
    return [
      MetricCard(
        eyebrow: 'Future value',
        figure: MoneyFormat.money(future),
        status: '${MoneyFormat.money(gain)} estimated gain',
        statusColor: income,
        child: SegmentedBar([
          BarSegment(
            'Invested',
            invested,
            palette.accentText,
            amountLabel: MoneyFormat.short(invested),
          ),
          BarSegment(
            'Returns',
            gain < 0 ? 0 : gain,
            income,
            amountLabel: MoneyFormat.short(gain),
          ),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      StatStrip([
        Stat(MoneyFormat.short(invested), 'Invested'),
        Stat(MoneyFormat.short(gain), 'Gain', color: income),
        Stat(MoneyFormat.short(future), 'Total'),
      ]),
    ];
  }

  List<Widget> _sip(BuildContext context) {
    final r = calculateSip(
      monthly: _num(_sipAmount) ?? 0,
      annualRatePct: _num(_sipRate) ?? -1,
      years: (_num(_sipYears) ?? 0).floor(),
      stepUpPct: _num(_sipStep) ?? 0,
    );
    return [
      ..._growthResult(context, r?.invested, r?.future),
      const SizedBox(height: AppSpacing.lg),
      _inputsCard([
        _field('Monthly investment', _sipAmount, prefix: '₹ '),
        _field('Expected return a year', _sipRate, suffix: '%'),
        _field('Years', _sipYears, suffix: 'yrs', decimal: false),
        _field('Yearly step-up', _sipStep, suffix: '%'),
      ]),
    ];
  }

  List<Widget> _lump(BuildContext context) {
    final r = calculateLumpSum(
      principal: _num(_lumpAmount) ?? 0,
      annualRatePct: _num(_lumpRate) ?? -1,
      years: _num(_lumpYears) ?? 0,
    );
    return [
      ..._growthResult(context, r?.invested, r?.future),
      const SizedBox(height: AppSpacing.lg),
      _inputsCard([
        _field('Amount invested', _lumpAmount, prefix: '₹ '),
        _field('Expected return a year', _lumpRate, suffix: '%'),
        _field('Years', _lumpYears, suffix: 'yrs'),
      ]),
    ];
  }

  List<Widget> _emi(BuildContext context) {
    final palette = context.palette;
    final expense = context.finance.expense;
    final r = calculateEmi(
      principal: _num(_loanAmount) ?? 0,
      annualRatePct: _num(_loanRate) ?? -1,
      months: ((_num(_loanYears) ?? 0) * 12).round(),
    );
    return [
      if (r == null)
        const CardEmpty(
          icon: Icons.calculate_outlined,
          title: 'Enter your numbers',
          message:
              'Fill in every field with a positive amount to see the result.',
        )
      else ...[
        MetricCard(
          eyebrow: 'Monthly EMI',
          figure: MoneyFormat.money(r.emi),
          status: '${MoneyFormat.money(r.totalInterest)} total interest',
          statusColor: expense,
          child: SegmentedBar([
            BarSegment(
              'Principal',
              r.principal,
              palette.accentText,
              amountLabel: MoneyFormat.short(r.principal),
            ),
            BarSegment(
              'Interest',
              r.totalInterest,
              expense,
              amountLabel: MoneyFormat.short(r.totalInterest),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        StatStrip([
          Stat(MoneyFormat.short(r.principal), 'Principal'),
          Stat(MoneyFormat.short(r.totalInterest), 'Interest', color: expense),
          Stat(MoneyFormat.short(r.totalPayment), 'Total paid'),
        ]),
      ],
      const SizedBox(height: AppSpacing.lg),
      _inputsCard([
        _field('Loan amount', _loanAmount, prefix: '₹ '),
        _field('Interest rate a year', _loanRate, suffix: '%'),
        _field('Term', _loanYears, suffix: 'yrs'),
      ]),
    ];
  }
}
