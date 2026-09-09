import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../domain/constants.dart';
import '../theme/finance_colors.dart';
import '../tokens/app_typography.dart';

enum AmountSize { inline, large, hero }

/// The one way to render a money figure. Strong tabular type, sign outside the
/// symbol, direction carried by color **and** sign (never color alone — WCAG
/// 2.2). Non-finite → em dash (see [MoneyFormat]).
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.currency = 'INR',
    this.type,
    this.size = AmountSize.inline,
    this.signed = true,
    this.color,
    this.semanticLabel,
  });

  AmountText.money(
    Money money, {
    Key? key,
    TxnType? type,
    AmountSize size = AmountSize.inline,
    bool signed = true,
  }) : this(
         money.amount.toDouble(),
         key: key,
         currency: money.currency,
         type: type,
         size: size,
         signed: signed,
       );

  final num amount;
  final String currency;

  /// When set, income renders positive/green, expense negative/red, transfer
  /// neutral — regardless of the raw sign of [amount] (amounts are stored
  /// positive; web BR-023).
  final TxnType? type;
  final AmountSize size;
  final bool signed;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final n = amount.toDouble();

    double display = n;
    Color resolved = color ?? Theme.of(context).colorScheme.onSurface;
    switch (type) {
      case TxnType.income:
        display = n.abs();
        resolved = color ?? finance.income;
      case TxnType.expense:
        display = -n.abs();
        resolved = color ?? finance.expense;
      case TxnType.transfer:
        display = n.abs();
        resolved = color ?? finance.transfer;
      case null:
        break;
    }

    final text = switch (size) {
      AmountSize.hero => MoneyFormat.short(
        signed ? display : display.abs(),
        currency: currency,
      ),
      _ => MoneyFormat.money(
        signed ? display : display.abs(),
        currency: currency,
      ),
    };

    final style = switch (size) {
      AmountSize.inline => AppTypography.money,
      AmountSize.large => AppTypography.moneyLarge,
      AmountSize.hero => AppTypography.moneyHero,
    }.copyWith(color: resolved);

    // A screen reader would otherwise read "minus rupee sign 1,234.50"; give it
    // the direction as a word and the plain magnitude (WCAG 1.3.1 — the
    // meaning colour + sign carry must survive without them).
    final spoken =
        semanticLabel ??
        () {
          final magnitude = MoneyFormat.money(display.abs(), currency: currency);
          return switch (type) {
            TxnType.income => 'Income $magnitude',
            TxnType.expense => 'Expense $magnitude',
            TxnType.transfer => 'Transfer $magnitude',
            null => magnitude,
          };
        }();

    return Text(
      text,
      style: style,
      semanticsLabel: spoken,
      // Hero figures may wrap rather than clip when text is scaled up — a
      // truncated balance is worse than two lines (WCAG 1.4.4 / 1.4.10).
      maxLines: size == AmountSize.hero ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
