import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/constants.dart';
import '../../budget/application/budget_providers.dart';
import '../../calendar/calendar_events.dart';
import '../../privacy/income_privacy.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/home_widget_gateway.dart';
import '../domain/widget_figures.dart';

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>(
  (ref) => MethodChannelHomeWidgetGateway(),
  name: 'homeWidgetGateway',
);

/// This month's expenses in the active workspace, live from the cache —
/// offline adds included, so the widget moves the moment one is saved.
final monthExpensesProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <TransactionEntity>[]);
  return ref
      .watch(transactionsRepositoryProvider)
      .watchSince(tenantId, monthStart(DateTime.now()), type: TxnType.expense);
}, name: 'monthExpenses');

/// What the home-screen widget should show; null until the month has loaded,
/// so the widget never flashes ₹0 on the way.
final widgetFiguresProvider = Provider.autoDispose<WidgetFigures?>((ref) {
  final rows = ref.watch(monthExpensesProvider).value;
  if (rows == null) return null;
  final hidden = ref.watch(incomePrivacyProvider.select((p) => p.hidden));
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  return widgetFigures(
    rows,
    now: now,
    masked: hidden,
    budgets: ref.watch(budgetsWithSpendProvider).value ?? const [],
    // This month and next, so a bill early next month still shows at the
    // end of this one.
    events: [
      ...ref.watch(calendarEventsProvider(month)),
      ...ref.watch(
        calendarEventsProvider(DateTime(month.year, month.month + 1)),
      ),
    ],
  );
}, name: 'widgetFigures');
