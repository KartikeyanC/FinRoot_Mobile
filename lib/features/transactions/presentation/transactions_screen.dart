import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Transactions ledger. M8 builds the grouped list, detail sheet, search and
/// filters.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PlaceholderScreen(
        title: 'Transactions',
        milestone: 'M8',
        icon: Icons.receipt_long_outlined,
        showAppBar: false,
      ),
    );
  }
}
