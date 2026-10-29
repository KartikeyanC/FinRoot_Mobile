import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../budget/application/budget_providers.dart';
import '../../investments/application/investments_providers.dart';
import '../../net_worth/application/net_worth_providers.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../reminders/application/reminders_providers.dart';
import '../../summary/application/summary_providers.dart';
import '../../trackers/application/trackers_providers.dart';
import '../application/sync_engine.dart';

/// Keeps the phone in step with changes made on the web dashboard or the
/// Windows app while this app is open: every [interval] it pulls the synced
/// tables (accounts, trackers and the rest of the offline cache — realtime
/// only reaches transactions, budgets and goals) and refreshes the screens
/// that read the server directly. A refresh only costs a request for a
/// screen that is actually showing. Pauses while the app is in the
/// background; refreshes at once on return.
class LiveDataRefresher extends ConsumerStatefulWidget {
  const LiveDataRefresher({super.key, required this.child});
  final Widget child;

  static const interval = Duration(seconds: 60);

  @override
  ConsumerState<LiveDataRefresher> createState() => _LiveDataRefresherState();
}

class _LiveDataRefresherState extends ConsumerState<LiveDataRefresher>
    with WidgetsBindingObserver {
  final _log = AppLog.of('live-refresh');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(LiveDataRefresher.interval, (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = Timer.periodic(LiveDataRefresher.interval, (_) => _refresh());
      _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _refresh() {
    if (!mounted) return;
    try {
      if (!ref.read(isSignedInProvider)) return;
      unawaited(ref.read(syncEngineProvider.notifier).syncNow());
      // Server-read (not cached) data another device can change. Price
      // alerts refresh through their own watcher.
      ref
        ..invalidate(investmentsProvider)
        ..invalidate(holdingPricesProvider)
        ..invalidate(netWorthEntriesProvider)
        ..invalidate(netWorthHistoryProvider)
        ..invalidate(recurringItemsProvider)
        ..invalidate(remindersProvider)
        ..invalidate(workspaceSummaryProvider)
        ..invalidate(budgetSpendRowsProvider)
        ..invalidate(trackerSpendRowsProvider);
    } on Object catch (e) {
      _log.warning('live refresh failed: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
