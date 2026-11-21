// Dates are spelled out in full (2025, 1, 1) to read like the deal sheet.
// ignore_for_file: avoid_redundant_argument_values

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
    expect(t.couponDates(), [
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
      'rating_agency': '',
      'price': '',
      'last_ip_date': '',
      'stamp_duty': '',
      'maturity_value': '',
      'tds_rate': '',
      'bond_type': '',
      'call_date': '',
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

  group('RM deal sheet: 10.75% Navi Finserv, monthly', () {
    final navi = BondTerms(
      faceValue: 10000,
      units: 1,
      couponRate: 10.75,
      frequency: BondFrequency.monthly,
      purchaseDate: DateTime(2026, 6, 9),
      maturityDate: DateTime(2028, 12, 31),
      price: 102,
      lastInterestDate: DateTime(2026, 6, 20),
      stampDuty: 0,
      maturityValue: 10000,
      tdsRate: 10,
      issuer: 'INE342T07668',
      rating: 'A',
      ratingAgency: 'CRISIL',
      bondType: 'Secured',
    );
    final onTradeDay = BondFigures.of(
      navi,
      invested: 10167.6,
      asOf: DateTime(2026, 6, 9),
    );

    test('purchase breakdown matches the sheet', () {
      expect(onTradeDay.consideration, 10200);
      expect(onTradeDay.accruedDaysAtPurchase, -11);
      expect(onTradeDay.accruedAtPurchase, -32.4);
      expect(onTradeDay.costToClient, 10167.6);
      // On the trade day the holding is worth what was paid.
      expect(onTradeDay.estimatedValue, 10167.6);
    });

    test('yield to maturity matches the sheet', () {
      expect(onTradeDay.yieldToMaturity, 10.32);
    });

    test('the seller keeps the 20 Jun coupon; ours start 20 Jul', () {
      expect(onTradeDay.nextPayout, DateTime(2026, 7, 20));
      // 20 Jun to 20 Jul: 30 days.
      expect(onTradeDay.nextPayoutAmount, 88.36);
      expect(onTradeDay.payoutPerPeriod, 89.58);
      expect(onTradeDay.net(89.58), 80.62);
      final dates = navi.couponDates();
      expect(dates.first, DateTime(2026, 7, 20));
      expect(dates[dates.length - 2], DateTime(2028, 12, 20));
      expect(dates.last, DateTime(2028, 12, 31));
    });

    test('maturity pays the redemption plus an 11-day stub coupon', () {
      expect(onTradeDay.maturityAmount, closeTo(10000 + 32.40, 0.01));
    });

    test('later: interest received and accrued since the last payout', () {
      final f = BondFigures.of(
        navi,
        invested: 10167.6,
        asOf: DateTime(2026, 11, 21),
      );
      // Jul, Aug, Sep, Oct and Nov 20th paid.
      // 153 days of interest, 20 Jun to 20 Nov.
      expect(f.interestReceived, closeTo(10000 * 0.1075 * 153 / 365, 0.01));
      expect(f.accruedInterest, closeTo(10000 * 0.1075 * 1 / 365, 0.01));
      expect(f.nextPayout, DateTime(2026, 12, 20));
    });

    test('rating label and round trip of the new keys', () {
      expect(navi.ratingLabel, 'CRISIL A');
      final back = BondTerms.fromFields(navi.toFields());
      expect(back.price, 102);
      expect(back.lastInterestDate, DateTime(2026, 6, 20));
      expect(back.tdsRate, 10);
      expect(back.bondType, 'Secured');
      expect(back.ratingAgency, 'CRISIL');
    });

    test('yield to call when a call date is set', () {
      final called = BondTerms.fromFields({
        ...navi.toFields(),
        'call_date': '2027-12-20',
      });
      final f = BondFigures.of(
        called,
        invested: 10167.6,
        asOf: DateTime(2026, 6, 9),
      );
      expect(f.yieldToCall, isNotNull);
      // A premium bond called early yields less than held to maturity.
      expect(f.yieldToCall!, lessThan(f.yieldToMaturity!));
    });

    test('last IP date must be the one nearest the purchase', () {
      String? check(DateTime d) => BondValidators.lastInterestDate(
        d,
        purchase: DateTime(2026, 6, 9),
        maturity: DateTime(2028, 12, 31),
        frequency: BondFrequency.monthly,
      );
      expect(check(DateTime(2026, 6, 20)), isNull);
      expect(check(DateTime(2026, 5, 20)), isNull);
      expect(check(DateTime(2026, 3, 20)), isNotNull);
    });
  });
}
