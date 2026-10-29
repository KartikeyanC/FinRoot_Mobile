import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../investments/data/live_price_gateway.dart';
import '../../investments/domain/live_price.dart';
import '../../notifications/data/notification_service.dart';
import '../../workspace/application/workspace_providers.dart';
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

/// One check: price the active alerts, mark the ones that were hit as
/// triggered (merged into the server's latest list), and post a phone
/// notification for each. Used by the in-app timer and by the background
/// task, so both behave the same. Returns the alerts that fired.
Future<List<PriceAlert>> runPriceAlertCheck({
  required String tenantId,
  required String? userId,
  required PriceAlertsGateway alerts,
  required LivePriceGateway prices,
  required NotificationService notifications,
  DateTime? now,
}) async {
  final log = AppLog.of('price-alerts');
  final current = await alerts.load(tenantId);
  final symbols = activeSymbols(current);
  if (symbols.isEmpty) return const [];

  final quoted = await prices.fetch([
    for (final s in symbols) LiveWant(LiveProvider.yahoo, s),
  ]);
  final round = evaluateAlerts(current, quoted, (now ?? DateTime.now()).toUtc());
  if (round.fired.isEmpty) return const [];

  // Merge by id into a fresh read, and only where the alert is still
  // watching — another device may have fired (or deleted) it meanwhile.
  final firedById = {for (final a in round.fired) a.id: a};
  final latest = await alerts.load(tenantId);
  final reallyFired = <PriceAlert>[];
  final merged = [
    for (final a in latest)
      if (a.isActive && firedById.containsKey(a.id))
        () {
          reallyFired.add(firedById[a.id]!);
          return firedById[a.id]!;
        }()
      else
        a,
  ];
  if (reallyFired.isEmpty) return const [];
  await alerts.save(tenantId, userId, merged);

  for (final a in reallyFired) {
    final m = firedMessage(a);
    await notifications.showNow(id: notificationIdFor(a.id), title: m.title, body: m.body);
  }
  log.info('${reallyFired.length} price alert(s) fired');
  return reallyFired;
}

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
    );
    ref.invalidate(alertPricesProvider);
    if (fired.isNotEmpty) ref.invalidate(priceAlertsProvider);
    return fired;
  };
}, name: 'priceAlertCheck');
