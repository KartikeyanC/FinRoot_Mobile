import 'dart:math' as math;

import 'package:finroot_mobile/features/investments/domain/bond.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/presentation/holding_row.dart'
    show bondCardLine;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 21);
  final yearly = BondTerms(
    faceValue: 1000,
    units: 10,
    couponRate: 8,
    purchaseDate: DateTime(2025, 1, 1),
    maturityDate: DateTime(2030, 1, 1),
  );

  group('BondFigures, yearly coupon bought at par', () {
    final f = BondFigures.of(yearly, invested: 10000, asOf: today);

    test('accrues since the last payout, not since purchase', () {
      // 1 Jan 2026 to 21 Nov 2026 = 324 days.
      expect(f.accruedInterest, closeTo(10000 * 0.08 * 324 / 365, 0.01));
      expect(f.estimatedValue, closeTo(10000 + f.accruedInterest, 0.001));
    });

    test('next payout, maturity amount and days left', () {
      expect(f.nextPayout, DateTime(2027, 1, 1));
      expect(f.maturityAmount, 10800); // principal + the last coupon
      expect(f.daysToMaturity, 1137);
    });

    test('yield to maturity equals the coupon at par', () {
      expect(f.yieldToMaturity, closeTo(8, 0.05));
    });

    test('a premium price yields less, a discount more', () {
      final premium = BondFigures.of(yearly, invested: 10500, asOf: today);
      final discount = BondFigures.of(yearly, invested: 9500, asOf: today);
      expect(premium.yieldToMaturity, lessThan(8));
      expect(discount.yieldToMaturity, greaterThan(8));
    });
  });

  test('cumulative bond compounds and pays everything at maturity', () {
    final t = BondTerms(
      faceValue: 1000,
      units: 10,
      couponRate: 8,
      frequency: BondFrequency.atMaturity,
      purchaseDate: DateTime(2025, 1, 1),
      maturityDate: DateTime(2030, 1, 1),
    );
    final f = BondFigures.of(t, invested: 10000, asOf: today);
    expect(f.nextPayout, DateTime(2030, 1, 1));
    expect(f.maturityAmount, closeTo(10000 * math.pow(1.08, 1826 / 365), 0.01));
    expect(f.yieldToMaturity, closeTo(8, 0.01));
    // Accrued since purchase: 689 days.
    expect(
      f.accruedInterest,
      closeTo(10000 * (math.pow(1.08, 689 / 365) - 1), 0.01),
    );
  });

  test(
    'without face value and units, the amount invested is the principal',
    () {
      final t = BondTerms(
        couponRate: 8,
        purchaseDate: DateTime(2025, 1, 1),
        maturityDate: DateTime(2030, 1, 1),
      );
      final f = BondFigures.of(t, invested: 5000, asOf: today);
      expect(f.maturityAmount, 5400);
    },
  );

  test('payout dates run back from maturity and clamp month ends', () {
    final t = BondTerms(
      couponRate: 7,
      frequency: BondFrequency.halfYearly,
      purchaseDate: DateTime(2029, 1, 10),
      maturityDate: DateTime(2030, 8, 31),
    );
    expect(t.payoutDates(), [
      DateTime(2029, 2, 28),
      DateTime(2029, 8, 31),
      DateTime(2030, 2, 28),
      DateTime(2030, 8, 31),
    ]);
  });

  test('a matured bond has no next payout and no accrued interest', () {
    final f = BondFigures.of(
      yearly,
      invested: 10000,
      asOf: DateTime(2030, 6, 1),
    );
    expect(f.nextPayout, isNull);
    expect(f.daysToMaturity, 0);
    expect(f.accruedInterest, 0);
  });

  test('fields round-trip under the web keys, legacy xirr is read', () {
    final t = BondTerms(
      faceValue: 1000,
      units: 5,
      couponRate: 7.35,
      frequency: BondFrequency.quarterly,
      purchaseDate: DateTime(2025, 3, 4),
      maturityDate: DateTime(2031, 3, 4),
      issuer: 'NHAI',
      rating: 'AAA',
    );
    final fields = t.toFields();
    expect(fields, {
      'face_value': '1000',
      'bond_units': '5',
      'coupon_rate': '7.35',
      'bond_freq': 'Quarterly',
      'purchase_date': '2025-03-04',
      'maturity_date': '2031-03-04',
      'issuer': 'NHAI',
      'rating': 'AAA',
    });
    final back = BondTerms.fromFields(fields);
    expect(back.couponRate, 7.35);
    expect(back.frequency, BondFrequency.quarterly);
    expect(back.maturityDate, DateTime(2031, 3, 4));

    expect(BondTerms.fromFields({'xirr': '7.5'}).couponRate, 7.5);
    expect(BondFrequency.parse('Half-yearly'), BondFrequency.halfYearly);
  });

  test('a bond record exposes its terms; other assets do not', () {
    const r = InvestmentRecord(
      id: '1',
      asset: 'bonds',
      currency: 'INR',
      fields: {'coupon_rate': '8'},
      derived: {},
    );
    expect(r.bond?.couponRate, 8);
    const s = InvestmentRecord(
      id: '2',
      asset: 'stocks',
      currency: 'INR',
      fields: {},
      derived: {},
    );
    expect(s.bond, isNull);
  });

  group('validators', () {
    test('coupon rate is 0 to 30', () {
      expect(BondValidators.couponRate('7.5'), isNull);
      expect(BondValidators.couponRate('0'), isNull);
      expect(BondValidators.couponRate('30'), isNull);
      expect(BondValidators.couponRate('30.1'), isNotNull);
      expect(BondValidators.couponRate('-1'), isNotNull);
      expect(BondValidators.couponRate(''), isNotNull);
    });

    test('maturity must follow purchase and be in the future', () {
      final p = DateTime(2025, 1, 1);
      expect(
        BondValidators.maturityDate(
          DateTime(2030, 1, 1),
          purchase: p,
          today: today,
        ),
        isNull,
      );
      expect(
        BondValidators.maturityDate(p, purchase: p, today: today),
        'Must be after the purchase date',
      );
      expect(
        BondValidators.maturityDate(
          DateTime(2026, 1, 1),
          purchase: p,
          today: today,
        ),
        'Must be in the future',
      );
      expect(
        BondValidators.maturityDate(null, purchase: p, today: today),
        isNotNull,
      );
    });
  });

  test('card line shows maturity and the next payout', () {
    expect(bondCardLine(yearly, invested: 10000, asOf: today), [
      'Matures 1 Jan 2030',
      'Next payout 1 Jan 2027',
    ]);
    expect(bondCardLine(yearly, invested: 10000, asOf: DateTime(2031, 1, 1)), [
      'Matured 1 Jan 2030',
    ]);
  });
}
