import 'package:flutter/material.dart';

/// Raw colour values. Together with `app_palette.dart` this is the only place
/// literal colours live.
///
/// Source of truth: `design-system/finroot-nineflow-tokens.css`, NineFlow's
/// token set with its orange swapped for FinRoot green. Surface colours vary by
/// colour theme and are in `AppPalette`. This file holds what every theme
/// shares: the pastel tint pairs, the danger fill and the chart decks.
abstract final class AppColors {
  // ---- Brand ----------------------------------------------------------------
  /// FinRoot green (#0D7A5F). Seeds the Material 3 scheme.
  static const seed = Color(0xFF0D7A5F);

  /// The far end of the net-worth figure's gradient text (web `--chart-6`).
  static const gradientEnd = Color(0xFF26B5D9);

  /// Destructive buttons in every theme and mode (`--danger`).
  static const dangerFill = Color(0xFFD7373D);

  // ---- Pastel tint pairs: background tint + its matching darker text --------
  // Light values first, then dark. Every `*Fg` reaches 4.5:1 on its tint, the
  // card and the page.
  static const mintLight = Color(0xFFDDF3E6);
  static const mintFgLight = Color(0xFF1A7951);
  static const mintDark = Color(0xFF1E4430);
  static const mintFgDark = Color(0xFF56D496);

  static const coralLight = Color(0xFFFBE0DE);
  static const coralFgLight = Color(0xFFC71C22);
  static const coralDark = Color(0xFF542828);
  static const coralFgDark = Color(0xFFFF7A7D);

  static const skyLight = Color(0xFFDCE9FB);
  static const skyFgLight = Color(0xFF0A5DE3);
  static const skyDark = Color(0xFF243754);
  static const skyFgDark = Color(0xFF7DACFF);

  static const butterLight = Color(0xFFFBEFC4);
  static const butterFgLight = Color(0xFF87660F);
  static const butterDark = Color(0xFF4E421A);
  static const butterFgDark = Color(0xFFF0C44A);

  static const violetLight = Color(0xFFE4DDFB);
  static const violetFgLight = Color(0xFF6243E4);
  static const violetDark = Color(0xFF3A3160);
  static const violetFgDark = Color(0xFFB09EFF);

  static const roseLight = Color(0xFFFBE0EE);
  static const roseFgLight = Color(0xFFC0275C);
  static const roseDark = Color(0xFF54243A);
  static const roseFgDark = Color(0xFFFF80AA);

  static const tealLight = Color(0xFFD6F1F0);
  static const tealFgLight = Color(0xFF0D7577);
  static const tealDark = Color(0xFF184242);
  static const tealFgDark = Color(0xFF4ED0D2);

  /// The web's chart decks (`src/lib/chartColors.ts`), first eight.
  static const chartLight = [
    Color(0xFF27AE6E), Color(0xFF3B82D9), Color(0xFF3AA640), Color(0xFFDDA516),
    Color(0xFF2BA192), Color(0xFFE2603C), Color(0xFF6BA63A), Color(0xFF9466D6),
  ];
  static const chartDark = [
    Color(0xFF5AD69B), Color(0xFF6BA8EE), Color(0xFF6ED472), Color(0xFFEBC759),
    Color(0xFF55D3C3), Color(0xFFF28A6B), Color(0xFF9AD266), Color(0xFFC1A3F2),
  ];
}
