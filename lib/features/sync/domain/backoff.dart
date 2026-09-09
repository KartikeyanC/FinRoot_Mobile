import 'dart:math';

/// Exponential backoff with full jitter, bounded.
///
/// Used two ways: to space out automatic sync runs after a retryable failure,
/// and (later) to decide the periodic background interval. Pure — tested
/// directly.
class Backoff {
  const Backoff({
    this.base = const Duration(seconds: 4),
    this.max = const Duration(minutes: 30),
    this.factor = 2.0,
  });

  final Duration base;
  final Duration max;
  final double factor;

  /// Delay before attempt number [attempt] (1 = the first retry). Full jitter:
  /// a uniform value in `[0, capped]` so many clients do not retry in lock-step.
  Duration delayFor(int attempt, {Random? random}) {
    if (attempt <= 0) return Duration.zero;
    final raw = base.inMilliseconds * pow(factor, attempt - 1);
    final capped = min(raw, max.inMilliseconds.toDouble());
    final jittered = (random ?? Random()).nextDouble() * capped;
    return Duration(milliseconds: jittered.round());
  }

  /// Ceiling delay for [attempt] with no jitter — for display and for the
  /// "don't run again before" guard.
  Duration ceilingFor(int attempt) {
    if (attempt <= 0) return Duration.zero;
    final raw = base.inMilliseconds * pow(factor, attempt - 1);
    return Duration(
      milliseconds: min(raw, max.inMilliseconds.toDouble()).round(),
    );
  }
}
