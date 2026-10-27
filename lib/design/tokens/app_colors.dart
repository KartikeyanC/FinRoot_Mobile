import 'package:flutter/material.dart';

/// Raw palette — the only place literal colors are allowed to live.
///
/// Nothing in the app reads these directly. They feed [AppTheme]'s
/// [ColorScheme]s and the [FinanceColors] theme extension, which is what
/// widgets consume. Keeping the palette in one file is the "one implementation
/// per rule" idea (web ADR-0008) applied to color.
abstract final class AppColors {
  // ---- Brand ----------------------------------------------------------------
  /// FinRoot old brand green (#0D7A5F). Seeds the Material 3 scheme and is the primary
  /// action color on both themes.
  static const seed = Color(0xFF0D7A5F);

  /// Brand green for TEXT and icons on dark surfaces. [seed] is only
  /// 3.4–3.8:1 there, so dark mode lifts the same hue/saturation to 40%
  /// lightness (#13B98F, 5.6:1+). Fills and buttons keep [seed].
  static const brandTextDark = Color(0xFF13B98F);

  static const forest900 = Color(0xFF0C2A22);
  static const forest700 = Color(0xFF16604E);
  static const forest500 = Color(0xFF0D7A5F);
  static const forest300 = Color(0xFF6FBFAB);
  static const forest100 = Color(0xFFD9F4ED);

  // ---- Neutrals (light) ---------------------------------------------------
  static const canvasLight = Color(0xFFF6F8F5);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMutedLight = Color(0xFFEFF2EE);
  static const inkLight = Color(0xFF15211B);
  static const inkMutedLight = Color(0xFF5C6B63);
  static const outlineLight = Color(0xFFDCE3DD);

  // ---- Neutrals (dark) --------------------------------------------------
  static const canvasDark = Color(0xFF0E1512);
  static const surfaceDark = Color(0xFF161E1A);
  static const surfaceMutedDark = Color(0xFF1F2A24);
  static const inkDark = Color(0xFFECF1ED);
  static const inkMutedDark = Color(0xFF9BA8A0);
  static const outlineDark = Color(0xFF2C3A32);

  // ---- Semantic finance (theme-aware pairs) ------------------------------
  // Direction of money, not "good/bad": income is inflow, expense is outflow,
  // transfer is neither. Never encode meaning in color alone (WCAG 2.2) — the
  // sign and the label always carry it too.
  static const incomeLight = Color(0xFF0D7A5F);
  static const incomeDark = Color(0xFF5FD0B4);
  static const expenseLight = Color(0xFFB4331F);
  static const expenseDark = Color(0xFFF08A78);
  static const transferLight = Color(0xFF4C6B62);
  static const transferDark = Color(0xFF9BB8AE);

  static const warningLight = Color(0xFF9A6700);
  static const warningDark = Color(0xFFE0B15C);
  static const dangerLight = Color(0xFFB4331F);
  static const dangerDark = Color(0xFFF08A78);
  static const successLight = Color(0xFF0D7A5F);
  static const successDark = Color(0xFF5FD0B4);
}
