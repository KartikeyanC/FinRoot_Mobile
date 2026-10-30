import 'package:finroot_mobile/features/calculator/domain/calculations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIP', () {
    test('0% return just adds the instalments', () {
      final r = calculateSip(monthly: 1000, annualRatePct: 0, years: 2)!;
      expect(r.invested, 24000);
      expect(r.future, closeTo(24000, 1e-6));
      expect(r.gain, closeTo(0, 1e-6));
    });

    test('matches the standard annuity-due value at 12% for 10 years', () {
      final r = calculateSip(monthly: 10000, annualRatePct: 12, years: 10)!;
      expect(r.invested, 1200000);
      expect(r.future, closeTo(2323391, 5));
    });

    test('step-up raises each year\'s instalment', () {
      final r = calculateSip(
        monthly: 1000,
        annualRatePct: 0,
        years: 2,
        stepUpPct: 10,
      )!;
      expect(r.invested, closeTo(12000 + 13200, 1e-6));
    });

    test('rejects invalid input', () {
      expect(calculateSip(monthly: 0, annualRatePct: 12, years: 5), isNull);
      expect(calculateSip(monthly: 100, annualRatePct: 12, years: 0), isNull);
      expect(calculateSip(monthly: 100, annualRatePct: -1, years: 5), isNull);
    });
  });

  group('Lump sum', () {
    test('compounds annually', () {
      final r = calculateLumpSum(
        principal: 100000,
        annualRatePct: 10,
        years: 2,
      )!;
      expect(r.future, closeTo(121000, 1e-6));
      expect(r.gain, closeTo(21000, 1e-6));
    });

    test('rejects invalid input', () {
      expect(
        calculateLumpSum(principal: -5, annualRatePct: 8, years: 1),
        isNull,
      );
      expect(
        calculateLumpSum(principal: 5, annualRatePct: 8, years: 0),
        isNull,
      );
    });
  });

  group('EMI', () {
    test('standard home-loan figure', () {
      final r = calculateEmi(
        principal: 1000000,
        annualRatePct: 12,
        months: 12,
      )!;
      expect(r.emi, closeTo(88848.79, 0.01));
      expect(r.totalPayment, closeTo(88848.79 * 12, 0.2));
      expect(r.totalInterest, closeTo(66185.5, 0.5));
    });

    test('0% loan divides evenly', () {
      final r = calculateEmi(principal: 120000, annualRatePct: 0, months: 12)!;
      expect(r.emi, 10000);
      expect(r.totalInterest, 0);
    });

    test('rejects invalid input', () {
      expect(calculateEmi(principal: 0, annualRatePct: 9, months: 12), isNull);
      expect(calculateEmi(principal: 1, annualRatePct: 9, months: 0), isNull);
    });
  });
}
