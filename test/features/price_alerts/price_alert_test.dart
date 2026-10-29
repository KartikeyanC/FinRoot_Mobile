import 'package:finroot_mobile/features/investments/data/live_price_gateway.dart';
import 'package:finroot_mobile/features/investments/domain/live_price.dart';
import 'package:finroot_mobile/features/notifications/data/notification_service.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/price_alerts/application/price_alerts_providers.dart';
import 'package:finroot_mobile/features/price_alerts/data/price_alerts_gateway.dart';
import 'package:finroot_mobile/features/price_alerts/domain/price_alert.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 29, 6);

PriceAlert _itc({
  String id = 'a1',
  double target = 260,
  AlertDirection direction = AlertDirection.below,
  DateTime? triggeredAt,
  double? triggeredPrice,
}) => PriceAlert(
  id: id,
  symbol: 'ITC.NS',
  name: 'ITC Limited',
  target: target,
  direction: direction,
  createdAt: DateTime.utc(2026, 10, 28),
  triggeredAt: triggeredAt,
  triggeredPrice: triggeredPrice,
);

class _FakeAlerts implements PriceAlertsGateway {
  _FakeAlerts(this.stored);
  List<PriceAlert> stored;
  final saves = <List<PriceAlert>>[];

  @override
  Future<List<PriceAlert>> load(String tenantId) async => stored;

  @override
  Future<void> save(String tenantId, String? userId, List<PriceAlert> alerts) async {
    saves.add(alerts);
    stored = alerts;
  }
}

class _FakePrices implements LivePriceGateway {
  _FakePrices(this.prices);
  final Map<String, double> prices;
  final asked = <List<LiveWant>>[];

  @override
  Future<Map<String, double>> fetch(List<LiveWant> wants) async {
    asked.add(wants);
    return prices;
  }
}

class _FakeNotifications implements NotificationService {
  final shown = <({int id, String title, String body})>[];

  @override
  Future<void> showNow({required int id, required String title, required String body}) async =>
      shown.add((id: id, title: title, body: body));

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> reconcile(List<PlannedNotification> plan) async {}
  @override
  Future<void> cancelAll() async {}
}

void main() {
  group('the rules match the web (src/lib/priceAlerts.ts)', () {
    test('a buy level fires at or below the target only', () {
      expect(isHit(AlertDirection.below, 260, 265), isFalse);
      expect(isHit(AlertDirection.below, 260, 260), isTrue);
      expect(isHit(AlertDirection.below, 260, 259.8), isTrue);
      expect(isHit(AlertDirection.above, 300, 299.99), isFalse);
      expect(isHit(AlertDirection.above, 300, 300), isTrue);
      expect(isHit(AlertDirection.below, 260, 0), isFalse);
      expect(isHit(AlertDirection.below, 260, double.nan), isFalse);
    });

    test('a round fires a hit alert once and leaves the rest alone', () {
      final first = evaluateAlerts([_itc()], {'yahoo:ITC.NS': 259.8}, _now);
      expect(first.fired, hasLength(1));
      expect(first.next.single.triggeredPrice, 259.8);
      expect(first.next.single.triggeredAt, _now);

      final second = evaluateAlerts(first.next, {'yahoo:ITC.NS': 250}, _now);
      expect(second.fired, isEmpty);
      expect(second.next.single.triggeredPrice, 259.8);

      final quiet = evaluateAlerts([_itc()], {'yahoo:ITC.NS': 265}, _now);
      expect(quiet.fired, isEmpty);
      final missing = evaluateAlerts([_itc()], const {}, _now);
      expect(missing.fired, isEmpty);
    });

    test('validation explains what is missing and refuses duplicates', () {
      expect(validateAlert(symbol: 'itc.ns', target: '260', direction: AlertDirection.below), isNull);
      expect(validateAlert(symbol: '', target: '260', direction: AlertDirection.below), contains('ticker'));
      expect(validateAlert(symbol: 'tata motors!', target: '260', direction: AlertDirection.below), contains('ticker'));
      expect(validateAlert(symbol: 'ITC.NS', target: '-1', direction: AlertDirection.below), contains('price'));
      expect(
        validateAlert(symbol: 'ITC.NS', target: '260', direction: AlertDirection.below, existing: [_itc()]),
        contains('already'),
      );
    });

    test('messages and prices read the same as on the web', () {
      expect(describeAlert(_itc()), 'ITC Limited falls to ₹260 or below');
      expect(formatPrice('RELIANCE.NS', 1174.5), '₹1,174.5');
      expect(formatPrice('AAPL', 343.83), r'$343.83');
      final m = firedMessage(_itc(triggeredAt: _now, triggeredPrice: 259.8));
      expect(m.title, 'Price alert: ITC Limited');
      expect(m.body, 'ITC.NS is at ₹259.8, at or below your ₹260 buy price.');
      expect(distanceToTarget(_itc(), 265), closeTo(1.887, 0.01));
    });
  });

  group('stored JSON', () {
    test('round-trips through the web shape', () {
      final a = _itc(triggeredAt: _now, triggeredPrice: 259.8);
      final back = PriceAlert.fromJson(a.toJson())!;
      expect(back.toJson(), a.toJson());
      expect(a.toJson()['direction'], 'below');
      expect(a.toJson()['triggeredAt'], '2026-10-29T06:00:00.000Z');
    });

    test('reads what the web writes, and drops broken rows', () {
      final parsed = parseStoredAlerts([
        {
          'id': 'w1',
          'symbol': 'reliance.ns',
          'name': 'Reliance Industries Limited',
          'target': 1100,
          'direction': 'below',
          'createdAt': '2026-10-29T05:00:00.000Z',
          'triggeredAt': null,
          'triggeredPrice': null,
        },
        {'id': 'bad', 'symbol': 'X', 'target': 'nope', 'direction': 'below'},
        {'id': 'bad2', 'symbol': 'X', 'target': 5, 'direction': 'sideways'},
        null,
      ]);
      expect(parsed.map((a) => a.id), ['w1']);
      expect(parsed.single.symbol, 'RELIANCE.NS');
      expect(parsed.single.isActive, isTrue);
      expect(parseStoredAlerts({'not': 'a list'}), isEmpty);
    });
  });

  group('runPriceAlertCheck', () {
    test('prices active alerts, records the trigger and notifies once', () async {
      final alerts = _FakeAlerts([
        _itc(),
        _itc(id: 'done', triggeredAt: _now, triggeredPrice: 250),
      ]);
      final prices = _FakePrices({'yahoo:ITC.NS': 259.5});
      final notes = _FakeNotifications();

      final fired = await runPriceAlertCheck(
        tenantId: 't1',
        userId: 'u1',
        alerts: alerts,
        prices: prices,
        notifications: notes,
        now: _now,
      );

      expect(fired.map((a) => a.id), ['a1']);
      expect(prices.asked.single.map((w) => w.key), ['yahoo:ITC.NS']);
      expect(alerts.saves, hasLength(1));
      expect(alerts.stored.firstWhere((a) => a.id == 'a1').triggeredPrice, 259.5);
      expect(notes.shown.single.title, 'Price alert: ITC Limited');
      expect(notes.shown.single.id, notificationIdFor('a1'));

      // The next run finds nothing left to fire.
      final again = await runPriceAlertCheck(
        tenantId: 't1',
        userId: 'u1',
        alerts: alerts,
        prices: prices,
        notifications: notes,
        now: _now,
      );
      expect(again, isEmpty);
      expect(notes.shown, hasLength(1));
    });

    test('does not ask for prices when nothing is being watched', () async {
      final prices = _FakePrices(const {});
      final fired = await runPriceAlertCheck(
        tenantId: 't1',
        userId: null,
        alerts: _FakeAlerts([_itc(triggeredAt: _now, triggeredPrice: 1)]),
        prices: prices,
        notifications: _FakeNotifications(),
      );
      expect(fired, isEmpty);
      expect(prices.asked, isEmpty);
    });

    test('writes nothing while the price has not reached the target', () async {
      final alerts = _FakeAlerts([_itc()]);
      final notes = _FakeNotifications();
      await runPriceAlertCheck(
        tenantId: 't1',
        userId: 'u1',
        alerts: alerts,
        prices: _FakePrices({'yahoo:ITC.NS': 270}),
        notifications: notes,
      );
      expect(alerts.saves, isEmpty);
      expect(notes.shown, isEmpty);
    });
  });

  test('parseLivePrices keeps only usable numbers', () {
    expect(
      parseLivePrices({
        'prices': {'yahoo:ITC.NS': 265.5, 'yahoo:X': null, 'mf:1': '106.5', 'yahoo:Z': 0},
      }),
      {'yahoo:ITC.NS': 265.5, 'mf:1': 106.5},
    );
    expect(parseLivePrices('junk'), isEmpty);
  });
}
