import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Theme-aware semantic colors that Material's [ColorScheme] does not cover:
/// the direction of money and the status tones. Consumed via
/// `Theme.of(context).extension<FinanceColors>()!` or the
/// `context.finance` helper.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.success,
    required this.warning,
    required this.danger,
    required this.positiveContainer,
    required this.warningContainer,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color success;
  final Color warning;
  final Color danger;
  final Color positiveContainer;
  final Color warningContainer;

  static const light = FinanceColors(
    income: AppColors.incomeLight,
    expense: AppColors.expenseLight,
    transfer: AppColors.transferLight,
    success: AppColors.successLight,
    warning: AppColors.warningLight,
    danger: AppColors.dangerLight,
    positiveContainer: AppColors.forest100,
    warningContainer: Color(0xFFF7ECD3),
  );

  static const dark = FinanceColors(
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    transfer: AppColors.transferDark,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    positiveContainer: Color(0xFF163A2B),
    warningContainer: Color(0xFF3A3120),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? success,
    Color? warning,
    Color? danger,
    Color? positiveContainer,
    Color? warningContainer,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      warningContainer: warningContainer ?? this.warningContainer,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}

extension FinanceColorsX on BuildContext {
  /// Shorthand for the [FinanceColors] extension on the active theme.
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
