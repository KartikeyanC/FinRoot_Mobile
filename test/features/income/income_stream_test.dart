// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/features/income/domain/income_stream.dart';
import 'package:flutter_test/flutter_test.dart';

IncomeStream _s(
  String id, {
  double amount = 1000,
  String currency = 'INR',
  double? rate,
  String type = 'passive',
  String frequency = 'monthly',
  bool visible = true,
  int order = 1,
}) => IncomeStream(
  id: id,
  name: id,
  type: type,
  icon: 'Coins',
  amount: amount,
  currency: currency,
  rate: rate ?? kIncomeFx[currency]!,
  visible: visible,
  order: order,
  frequency: frequency,
);

void main() {
  test('reads a web row, with the web defaults', () {
    final s = IncomeStream.fromRow({
      'id': 'a',
      'name': 'Salary',
      'type': 'active',
      'icon': 'Briefcase',
      'amount': '5000',
      'currency': 'USD',
      'exchange_rate_to_inr': 83.5,
      'is_visible': true,
      'display_order': 3,
      'frequency': 'monthly',
    });
    expect(s.isActive, isTrue);
    expect(s.inr, 417500);
    expect(s.order, 3);
    // A row without a rate or frequency still adds up.
    final bare = IncomeStream.fromRow({
      'id': 'b',
      'name': 'Course',
      'amount': 100,
      'currency': 'EUR',
    });
    expect(bare.rate, 90);
    expect(bare.frequency, 'monthly');
    expect(bare.type, 'passive');
    expect(incomeIcon('Nope'), incomeIcon('Coins'));
  });

  test('a month counts weekly pay 52/12 times and leaves one-time out', () {
    expect(_s('w', amount: 1200, frequency: 'weekly').monthlyInr, 5200);
    expect(_s('o', amount: 50000, frequency: 'one-time').monthlyInr, 0);
    expect(_s('m', amount: 1000).monthlyInr, 1000);
  });

  test('the summary covers shown streams only', () {
    final sum = IncomeSummary.of([
      _s('salary', amount: 5000, currency: 'USD', type: 'active'),
      _s('rent', amount: 25000),
      _s('bonus', amount: 50000, frequency: 'one-time'),
      _s('hidden', amount: 99999, visible: false),
    ]);
    expect(sum.count, 3);
    expect(sum.monthly, 417500 + 25000);
    expect(sum.active, 417500);
    expect(sum.passive, 25000);
    expect(sum.oneTime, 50000);
    expect(sum.foreign, 1);
  });

  test('moving a stream renumbers like the web, writing only what changed', () {
    final shown = [_s('a', order: 1), _s('b', order: 2), _s('c', order: 3)];
    expect(reorderedPositions(shown, 2, 0), {'c': 1, 'a': 2, 'b': 3});
    expect(reorderedPositions(shown, 0, 1), {'b': 1, 'a': 2});
    expect(reorderedPositions(shown, 0, 5), isEmpty);
    // Gaps in the stored order are closed up.
    final gappy = [_s('a', order: 4), _s('b', order: 9)];
    expect(reorderedPositions(gappy, 1, 0), {'b': 1, 'a': 2});
    expect(
      shownInOrder([_s('x', order: 2), _s('y', order: 1, visible: false)])
          .map((s) => s.id),
      ['x'],
    );
  });

  test("the row matches the web's streamToRow", () {
    const d = IncomeStreamDraft(
      name: ' Salary ',
      type: 'active',
      amount: 5000,
      currency: 'USD',
      rate: 84,
      frequency: 'monthly',
      icon: 'Briefcase',
      notes: '',
    );
    expect(d.toRow(), {
      'name': 'Salary',
      'type': 'active',
      'icon': 'Briefcase',
      'amount': 5000,
      'currency': 'USD',
      'exchange_rate_to_inr': 84,
      'frequency': 'monthly',
      'notes': null,
    });
    expect(
      const IncomeStreamDraft(
        name: '',
        type: 'passive',
        amount: 1,
        currency: 'EUR',
        rate: 0,
      ).toRow()['exchange_rate_to_inr'],
      90,
    );
  });

  test('validation', () {
    expect(IncomeValidators.amount('0'), isNotNull);
    expect(IncomeValidators.amount('85,000'), isNull);
    expect(IncomeValidators.rate(''), isNotNull);
    expect(IncomeValidators.rate('83.5'), isNull);
  });
}
