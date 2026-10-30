import 'dart:math' as math;

/// Pure calculator maths (no Flutter). Display-only estimates, so `double` is
/// fine here (these never touch stored money). The SIP formula mirrors the
/// web Calculator's Step-Up SIP: monthly deposits at the start of each month,
/// compounded monthly, with the instalment stepped up once a year.

class SipResult {
  const SipResult({required this.invested, required this.future});
  final double invested;
  final double future;
  double get gain => future - invested;
}

/// Returns null when the inputs are not a valid SIP (non-positive amount or
/// period, negative rate / step-up).
SipResult? calculateSip({
  required double monthly,
  required double annualRatePct,
  required int years,
  double stepUpPct = 0,
}) {
  if (!monthly.isFinite || monthly <= 0 || years <= 0) return null;
  if (!annualRatePct.isFinite || annualRatePct < 0) return null;
  if (!stepUpPct.isFinite || stepUpPct < 0) return null;
  final i = annualRatePct / 100 / 12;
  final step = stepUpPct / 100;
  var instalment = monthly;
  var future = 0.0;
  var invested = 0.0;
  for (var y = 0; y < years; y++) {
    for (var m = 0; m < 12; m++) {
      future = (future + instalment) * (1 + i);
      invested += instalment;
    }
    instalment *= 1 + step;
  }
  return SipResult(invested: invested, future: future);
}

class LumpSumResult {
  const LumpSumResult({required this.invested, required this.future});
  final double invested;
  final double future;
  double get gain => future - invested;
}

/// Annual compounding: `P x (1 + r)^years`.
LumpSumResult? calculateLumpSum({
  required double principal,
  required double annualRatePct,
  required double years,
}) {
  if (!principal.isFinite || principal <= 0) return null;
  if (!years.isFinite || years <= 0) return null;
  if (!annualRatePct.isFinite || annualRatePct < 0) return null;
  final future = principal * math.pow(1 + annualRatePct / 100, years);
  return LumpSumResult(invested: principal, future: future.toDouble());
}

class EmiResult {
  const EmiResult({
    required this.emi,
    required this.totalPayment,
    required this.principal,
  });
  final double emi;
  final double totalPayment;
  final double principal;
  double get totalInterest => totalPayment - principal;
}

/// Reducing-balance loan EMI: `P r (1+r)^n / ((1+r)^n - 1)` with a monthly
/// rate `r`; a 0% loan is simply `P / n`.
EmiResult? calculateEmi({
  required double principal,
  required double annualRatePct,
  required int months,
}) {
  if (!principal.isFinite || principal <= 0 || months <= 0) return null;
  if (!annualRatePct.isFinite || annualRatePct < 0) return null;
  final r = annualRatePct / 100 / 12;
  final double emi;
  if (r == 0) {
    emi = principal / months;
  } else {
    final growth = math.pow(1 + r, months).toDouble();
    emi = principal * r * growth / (growth - 1);
  }
  return EmiResult(
    emi: emi,
    totalPayment: emi * months,
    principal: principal,
  );
}
