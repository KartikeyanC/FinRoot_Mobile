import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../investments/data/live_price_gateway.dart';
import '../../investments/domain/live_price.dart';
import '../../notifications/data/notification_service.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/notified_alerts_store.dart';
import '../data/price_alerts_gateway.dart';
import '../domain/price_alert.dart';

const _uuid = Uuid();

/// The workspace's alerts. Invalidate to refresh.
final priceAlertsProvider = FutureProvider<List<PriceAlert>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(priceAlertsGatewayProvider).load(tenantId);
}, name: 'priceAlerts');

/// Live prices for the alerts still watching, keyed `yahoo:SYMBOL`.
final alertPricesProvider = FutureProvider<Map<String, double>>((ref) async {
  final alerts = ref.watch(priceAlertsProvider).value ?? const [];
  final symbols = activeSymbols(alerts);
  if (symbols.isEmpty) return const {};
  return ref
      .watch(livePriceGatewayProvider)
      .fetch([for (final s in symbols) LiveWant(LiveProvider.yahoo, s)]);
}, name: 'alertPrices');

/// Every write sends the whole list (that is how a tenant setting works), so
/// each action re-reads the server's list first and changes only its own
/// alert — the web or another phone may have edited it in the meantime.
class PriceAlertsController {
  PriceAlertsController(this._ref);
  final Ref _ref;

  Future<void> _update(List<PriceAlert> Function(List<PriceAlert>) change) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    final gateway = _ref.read(priceAlertsGatewayProvider);
    final latest = await gateway.load(tenantId);
    await gateway.save(tenantId, _ref.read(currentUserIdProvider), change(latest));
    _ref.invalidate(priceAlertsProvider);
  }

  /// Returns why the alert was refused, or null once it is saved.
  Future<String?> add({
    required String symbol,
    required String name,
    required String target,
    required AlertDirection direction,
  }) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) return 'No workspace selected.';
    final latest = await _ref.read(priceAlertsGatewayProvider).load(tenantId);
    final problem = validateAlert(
      symbol: symbol,
      target: target,
      direction: direction,
      existing: latest,
    );
    if (problem != null) return problem;
    final sym = normaliseSymbol(symbol);
    final alert = PriceAlert(
      id: _uuid.v4(),
      symbol: sym,
      name: name.trim().isEmpty ? sym : name.trim(),
      target: double.parse(target.trim()),
      direction: direction,
      createdAt: DateTime.now().toUtc(),
    );
    await _update((list) => [alert, ...list]);
    return null;
  }

  Future<void> remove(String id) =>
      _update((list) => [for (final a in list) if (a.id != id) a]);

  Future<void> rearm(String id) => _update(
    (list) => [for (final a in list) a.id == id ? a.rearmed() : a],
  );
}

final priceAlertsControllerProvider = Provider<PriceAlertsController>(
  PriceAlertsController.new,
  name: 'priceAlertsController',
);

/// One check, used by the in-app timer and the background task alike:
///
/// 1. price the alerts still watching and mark the ones that were hit as
///    triggered (merged into the server's latest list);
/// 2. post a phone notification for every recent trigger this phone has not
///    announced yet — including triggers the web dashboard or the Windows
///    app recorded first, so the phone always tells its owner.
///
/// Returns the alerts announced on this phone.
Future<List<PriceAlert>> runPriceAlertCheck({
  required String tenantId,
  required String? userId,
  required PriceAlertsGateway alerts,
  required LivePriceGateway prices,
  required NotificationService notifications,
  required NotifiedAlertsStore notified,
  DateTime? now,
}) async {
  final log = AppLog.of('price-alerts');
  final at = (now ?? DateTime.now()).toUtc();
  var list = await alerts.load(tenantId);

  final symbols = activeSymbols(list);
  if (symbols.isNotEmpty) {
    final quoted = await prices.fetch([
      for (final s in symbols) LiveWant(LiveProvider.yahoo, s),
    ]);
    final round = evaluateAlerts(list, quoted, at);
    if (round.fired.isNotEmpty) {
      // Merge by id into a fresh read, only where the alert is still
      // watching — another device may have fired (or deleted) it meanwhile.
      final firedById = {for (final a in round.fired) a.id: a};
      final latest = await alerts.load(tenantId);
      var changed = false;
      list = [
        for (final a in latest)
          if (a.isActive && firedById.containsKey(a.id))
            () {
              changed = true;
              return firedById[a.id]!;
            }()
          else
            a,
      ];
      if (changed) await alerts.save(tenantId, userId, list);
    }
  }

  final due = alertsToNotify(list, notified.load(), at);
  if (due.isEmpty) return const [];
  for (final a in due) {
    final m = firedMessage(a);
    await notifications.showNow(
      id: notificationIdFor(a.id),
      title: m.title,
      body: m.body,
      payload: priceAlertsPayload,
    );
  }
  await notified.add(due.map(notifiedKey));
  log.info('${due.length} price alert notification(s) posted');
  return due;
}

/// Notification payload that opens the Price alerts screen when tapped.
const priceAlertsPayload = 'price-alerts';

/// A stable id per alert, kept clear of the schedule's ids (those are small).
int notificationIdFor(String alertId) =>
    0x40000000 | (alertId.hashCode & 0x3FFFFFFF);

/// The in-app check, bound to the signed-in workspace.
final priceAlertCheckProvider = Provider<Future<List<PriceAlert>> Function()>((ref) {
  return () async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return const [];
    final fired = await runPriceAlertCheck(
      tenantId: tenantId,
      userId: ref.read(currentUserIdProvider),
      alerts: ref.read(priceAlertsGatewayProvider),
      prices: ref.read(livePriceGatewayProvider),
      notifications: ref.read(notificationServiceProvider),
      notified: ref.read(notifiedAlertsStoreProvider),
    );
    ref.invalidate(alertPricesProvider);
    ref.invalidate(priceAlertsProvider);
    return fired;
  };
}, name: 'priceAlertCheck');
