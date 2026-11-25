import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/home_screen_widget/domain/widget_figures.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
TransactionEntity _t(
  String amount,
  DateTime at, {
  TxnType type = TxnType.expense,
  String currency = 'INR',
}) => TransactionEntity(
  id: 't${_n++}',
  type: type,
  amount: Money.parse(amount, currency),
  category: 'Food',
  occurredAt: at,
);

void main() {
  final now = DateTime(2026, 11, 25, 14, 30);

  test('today and this month, expenses only', () {
    final f = widgetFigures(
      [
        _t('240', DateTime(2026, 11, 25, 9)),
        _t('1000', DateTime(2026, 11, 25, 13, 59)),
        _t('17360', DateTime(2026, 11, 3)),
        _t('50000', DateTime(2026, 11, 2), type: TxnType.income),
        _t('5000', DateTime(2026, 11, 25), type: TxnType.transfer),
        _t('999', DateTime(2026, 10, 31, 23, 59)), // last month
      ],
      now: now,
      masked: false,
    );
    expect(f.today, '₹1,240');
    expect(f.month, '₹18,600');
    expect(f.masked, isFalse);
    expect(f.day, '2026-11-25');
    expect(f.monthKey, '2026-11');
  });

  test('other currencies fold to INR, as on the dashboard', () {
    final f = widgetFigures(
      [_t('10', DateTime(2026, 11, 25, 10), currency: 'USD')],
      now: now,
      masked: false,
    );
    expect(f.today, '₹835');
  });

  test('nothing yet is ₹0, and the map carries a matching zero', () {
    final f = widgetFigures(const [], now: now, masked: true);
    expect(f.today, '₹0');
    expect(f.month, '₹0');
    final m = f.toMap();
    expect(m['zero'], '₹0');
    expect(m['masked'], true);
  });

  test('Indian grouping, and the short form from a crore', () {
    expect(formatWidgetAmount(Decimal.parse('124000')), '₹1,24,000');
    expect(formatWidgetAmount(Decimal.parse('99.6')), '₹100');
    expect(formatWidgetAmount(Decimal.parse('25000000')), '₹2.50Cr');
  });

  test('equal figures compare equal, so the widget is not re-sent', () {
    WidgetFigures make() => widgetFigures(
      [_t('5', DateTime(2026, 11, 25, 8))],
      now: now,
      masked: false,
    );
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
  });

  test('monthStart', () {
    expect(monthStart(now), DateTime(2026, 11));
  });
}
