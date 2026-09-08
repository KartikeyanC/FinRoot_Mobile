import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Trackers — an optional contextual dimension on a transaction, never a
/// ledger (web ADR-0010). M9 builds list, detail, spend, assign, review.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PlaceholderScreen(
        title: 'Trackers',
        milestone: 'M9',
        icon: Icons.donut_large_outlined,
        showAppBar: false,
      ),
    );
  }
}
