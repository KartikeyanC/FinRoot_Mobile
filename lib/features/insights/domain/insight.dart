import 'package:flutter/material.dart';

/// The tone of an [Insight] — drives its icon and accent colour.
enum InsightKind {
  /// Something is going well.
  positive,

  /// Neutral observation / pattern.
  neutral,

  /// Worth keeping an eye on.
  watch,

  /// Needs attention now.
  alert,
}

/// One derived observation about the workspace's money, shown on Home and the
/// Insights screen.
///
/// M15 generates these **on device** from the `dashboard_summary` roll-up plus
/// budgets / goals / recurring items — a deterministic rule engine, not an LLM
/// (see the M15 report; a Gemini-backed version needs a new Edge Function and
/// web-owner coordination).
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.route,
    this.priority = 0,
  });

  /// Stable key — the same situation produces the same id across rebuilds.
  final String id;
  final InsightKind kind;

  /// One short line — the headline.
  final String title;

  /// A sentence of context.
  final String detail;

  /// Optional deep link (e.g. `/budget`).
  final String? route;

  /// Higher shows first. Alerts outrank watches outrank the rest.
  final int priority;

  IconData get icon => switch (kind) {
    InsightKind.positive => Icons.trending_up_rounded,
    InsightKind.neutral => Icons.insights_rounded,
    InsightKind.watch => Icons.visibility_outlined,
    InsightKind.alert => Icons.warning_amber_rounded,
  };
}
