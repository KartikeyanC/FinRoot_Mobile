import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which row is open in a two-pane list/detail screen at the expanded
/// breakpoint. Null = nothing selected (the detail pane shows its waiting
/// state). Ignored on a phone, where detail opens as a sheet or a pushed
/// route instead.
class PaneSelection extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
  void clear() => state = null;
}

/// The transaction open in the Transactions two-pane detail.
final selectedTransactionIdProvider = NotifierProvider<PaneSelection, String?>(
  PaneSelection.new,
);

/// The tracker open in the Trackers two-pane detail.
final selectedTrackerIdProvider = NotifierProvider<PaneSelection, String?>(
  PaneSelection.new,
);

/// The "More" feature route shown in the More two-pane detail. Defaults to
/// Accounts so the pane is never empty on a tablet.
class MorePaneSelection extends Notifier<String> {
  @override
  String build() => '/accounts';

  void select(String route) => state = route;
}

final selectedMoreRouteProvider = NotifierProvider<MorePaneSelection, String>(
  MorePaneSelection.new,
);
