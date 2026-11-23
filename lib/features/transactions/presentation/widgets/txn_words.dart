import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../domain/transaction.dart';
import 'category_style.dart';

/// "Paid by UPI", "Received in cash", "Moved by net banking"; null without a
/// mode. Mirrors the web's `paidVia` (`src/lib/transactionDisplay.ts`).
String? paidViaLabel(String? mode, TxnType type) {
  if (mode == null || mode.trim().isEmpty) return null;
  final verb = switch (type) {
    TxnType.income => 'Received',
    TxnType.expense => 'Paid',
    TxnType.transfer => 'Moved',
  };
  const how = {
    'UPI': 'by UPI',
    'Cash': 'in cash',
    'Card': 'by card',
    'Net Banking': 'by net banking',
    'Wallet': 'from a wallet',
    'Cheque': 'by cheque',
  };
  return '$verb ${how[mode] ?? 'by $mode'}';
}

/// The extra facts a row shows under its title, in reading order: category
/// (when the title is a note), how it was paid, the account, a split.
List<String> txnFacts(TransactionEntity t) {
  final n = t.note;
  return [
    if (t.title != t.category) t.category,
    ?paidViaLabel(t.paymentMode, t.type),
    if (n.account != null) n.account!,
    if (n.splitMode == 'owe') '${n.splitFriend} owes you',
    if (n.splitMode != null && n.splitMode != 'owe')
      'Split with ${n.splitFriend}',
  ];
}

/// The category tile with a small corner badge saying which way the money
/// went: ↙ in (income), ↗ out (expense), ⇄ transfer.
class TxnLeading extends StatelessWidget {
  const TxnLeading(this.txn, {super.key, this.size = 40});
  final TransactionEntity txn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final (icon, color) = switch (txn.type) {
      TxnType.income => (Icons.south_west_rounded, finance.income),
      TxnType.expense => (Icons.north_east_rounded, finance.expense),
      TxnType.transfer => (Icons.swap_horiz_rounded, finance.transfer),
    };
    final badge = size * 0.42;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size + 3,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CategoryTile(category: txn.category, type: txn.type, size: size),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: badge * 0.62, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
