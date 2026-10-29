/// The web dashboard's "Wealth" arithmetic (`DashboardWealth.tsx`), kept
/// pure so it can be tested and stays line-for-line comparable with the web.
/// Inputs are server-derived figures (dashboard_summary, investments, debts);
/// nothing here re-reduces the ledger (ADR-0006).
library;

/// Month-on-month change in percent from a monthly series, oldest first.
/// Null when there is no previous month or it was zero (web `mom`).
double? monthOnMonth(List<double> series) {
  if (series.length < 2) return null;
  final prev = series[series.length - 2];
  final cur = series.last;
  if (prev == 0) return null;
  return (cur - prev) / prev * 100;
}

/// Savings rate in whole percent, as the web rounds it.
int savingsRate(double income, double expense) =>
    income > 0 ? ((income - expense) / income * 100).round() : 0;

class HealthCheck {
  const HealthCheck(this.label, this.ok);
  final String label;
  final bool ok;
}

class HealthScore {
  const HealthScore(this.score, this.checks);
  final int score; // 0–100
  final List<HealthCheck> checks;

  String get verdict => score >= 75 ? 'on track' : score >= 50 ? 'steady' : 'needs work';
}

/// The web's financial-health score: up to 40 for the savings rate (30%+ is
/// full marks), 30 for goal progress (0.5 when there are no goals), 30 for a
/// low debt-to-assets ratio.
HealthScore healthScore({
  required double savings,
  required int savingsRate,
  required List<double> goalProgress, // each 0..1
  required double assets,
  required double liabilities,
}) {
  final rateScore = savingsRate.clamp(0, 30) / 30 * 40;
  final goalAvg = goalProgress.isEmpty
      ? 0.0
      : goalProgress.reduce((a, b) => a + b) / goalProgress.length;
  final goalScore = (goalProgress.isEmpty ? 0.5 : goalAvg) * 30;
  final debtRatio = assets > 0 ? liabilities / assets : (liabilities > 0 ? 1.0 : 0.0);
  final debtScore = (1 - debtRatio).clamp(0, 1) * 30;
  final score = (rateScore + goalScore + debtScore).clamp(0, 100).round();
  return HealthScore(score, [
    HealthCheck('Saved money this month', savings > 0),
    HealthCheck('Healthy savings rate (20%+)', savingsRate >= 20),
    HealthCheck('Low debt load', liabilities <= assets * 0.5),
    HealthCheck('Goals on track', goalAvg >= 0.3 && goalProgress.isNotEmpty),
  ]);
}

/// Running total of holdings' current values, largest first — the web's
/// "investment performance" area series.
List<double> cumulativeHoldings(Iterable<double> currentValues) {
  final sorted = currentValues.where((v) => v > 0).toList()..sort((a, b) => b.compareTo(a));
  var acc = 0.0;
  return [for (final v in sorted) acc += v];
}
