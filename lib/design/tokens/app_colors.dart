import 'package:flutter/material.dart';

/// Raw palette — the only place literal colors are allowed to live.
///
/// Nothing in the app reads these directly. They feed [AppTheme]'s
/// [ColorScheme]s and the [FinanceColors] theme extension, which is what
/// widgets consume. Keeping the palette in one file is the "one implementation
/// per rule" idea (web ADR-0008) applied to color.
///
/// The neutrals are the web dashboard's own tokens (`src/index.css` there):
/// dark = the default "Obsidian" theme, light = its light theme. HSL values
/// are noted next to each so the two stay easy to compare.
abstract final class AppColors {
  // ---- Brand ----------------------------------------------------------------
  /// FinRoot green (#0D7A5F, web `--primary` 165 81% 26.5%). Seeds the
  /// Material 3 scheme and is the primary action color on both themes.
  static const seed = Color(0xFF0D7A5F);

  /// Brand green for TEXT and icons on dark surfaces. [seed] is only
  /// 3.4–3.8:1 there, so dark mode lifts the same hue/saturation to 40%
  /// lightness (#13B98F, 5.6:1+). Fills and buttons keep [seed].
  static const brandTextDark = Color(0xFF13B98F);

  /// Web `--primary-text` (165 81% 25%): green text on light surfaces.
  static const brandTextLight = Color(0xFF0C735A);

  /// Web `--chart-6` (190 70% 50%): the far end of the net-worth gradient.
  static const gradientEnd = Color(0xFF26B5D9);

  // ---- Neutrals (light) — web light theme ---------------------------------
  static const canvasLight = Color(0xFFF4F7FA); // --background 210 40% 97%
  static const surfaceLight = Color(0xFFFFFFFF); // --card
  static const surfaceMutedLight = Color(0xFFE7ECF3); // --muted 214 32% 93%
  static const inkLight = Color(0xFF0F1729); // --foreground 222 47% 11%
  static const inkMutedLight = Color(0xFF5A687C); // --muted-foreground 215 16% 42%
  static const outlineLight = Color(0xFFDDE2E9); // --border 215 20% 89%

  // ---- Neutrals (dark) — web "Obsidian" -----------------------------------
  static const canvasDark = Color(0xFF08090D); // --background 222 24% 4%
  static const surfaceDark = Color(0xFF15181E); // --card 220 18% 10%
  static const surfaceMutedDark = Color(0xFF1F2229); // --muted 220 14% 14%
  static const inkDark = Color(0xFFE7EBEF); // --foreground 210 20% 92%
  static const inkMutedDark = Color(0xFF818D9C); // --muted-foreground 215 12% 56%
  static const outlineDark = Color(0xFF23272F); // --border 220 14% 16%

  // ---- Semantic finance (theme-aware pairs) ------------------------------
  // Direction of money, not "good/bad": income is inflow, expense is outflow,
  // transfer is neither. Never encode meaning in color alone (WCAG 2.2) — the
  // sign and the label always carry it too. The web uses Tailwind emerald-500
  // and rose-500; on the light theme those miss 4.5:1, so light mode takes the
  // next shade down (emerald-700, rose-600).
  static const incomeLight = Color(0xFF047857);
  static const incomeDark = Color(0xFF10B981);
  static const expenseLight = Color(0xFFE11D48);
  static const expenseDark = Color(0xFFF43F5E);
  static const transferLight = Color(0xFF2563EB);
  static const transferDark = Color(0xFF60A5FA);

  static const warningLight = Color(0xFF9A6700);
  static const warningDark = Color(0xFFE0B15C);
  static const dangerLight = Color(0xFFE11D48);
  static const dangerDark = Color(0xFFF43F5E);
  static const successLight = Color(0xFF047857);
  static const successDark = Color(0xFF10B981);

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
