import 'package:flutter/material.dart';

/// Raw palette — the only place literal colors are allowed to live.
///
/// Nothing in the app reads these directly. They feed [AppTheme]'s
/// [ColorScheme]s and the [FinanceColors] theme extension, which is what
/// widgets consume. Keeping the palette in one file is the "one implementation
/// per rule" idea (web ADR-0008) applied to color.
///
/// Light neutrals follow the restyle spec (`design-system/RESTYLE-SPEC.md`,
/// "NineFlow look, FinRoot green"); dark = the web's default "Obsidian"
/// theme, whose surfaces the restyle keeps (HSL noted next to each).
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

  /// The one action gradient (restyle spec "brand-a → brand-b"), painted left
  /// to right on the primary button and the active tab. White text on it
  /// clears 4.66:1. Dark themes use the same pair.
  static const brandA = Color(0xFF0E8466);
  static const brandB = Color(0xFF0A5E48);

  // ---- Neutrals (light) — restyle spec "Crisp Light" -----------------------
  static const canvasLight = Color(0xFFF5F7F4); // page
  static const surfaceLight = Color(0xFFFFFFFF); // card
  static const surfaceMutedLight = Color(0xFFEEF2EE); // subtle
  static const inkLight = Color(0xFF111A15); // ink
  static const inkMutedLight = Color(0xFF56625B); // muted text, 5.6:1 on subtle
  static const inkFaintLight = Color(0xFF626D66); // faint text, 4.76:1 on subtle
  static const outlineLight = Color(0xFFE3E8E3); // line — every 1px border
  static const inputBorderLight = Color(0xFFD5DDD6); // inputs, selects

  /// Accent tint: active nav item, selection, empty-state icon tile.
  /// [brandTextLight] on it is 5.06:1.
  static const accentTintLight = Color(0xFFE3F3EC);

  // ---- Neutrals (dark) — web "Obsidian" -----------------------------------
  static const canvasDark = Color(0xFF08090D); // --background 222 24% 4%
  static const surfaceDark = Color(0xFF15181E); // --card 220 18% 10%
  static const surfaceMutedDark = Color(0xFF1F2229); // --muted 220 14% 14%
  static const inkDark = Color(0xFFE7EBEF); // --foreground 210 20% 92%
  static const inkMutedDark = Color(0xFF818D9C); // --muted-foreground 215 12% 56%
  static const outlineDark = Color(0xFF23272F); // --border 220 14% 16%
  static const inkFaintDark = Color(0xFF818D9C); // same as muted on dark
  static const accentTintDark = Color(0xFF163A31); // selection / active nav

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
  static const dangerLight = Color(0xFFDB2424); // spec danger
  static const dangerDark = Color(0xFFF43F5E);
  static const successLight = Color(0xFF047857);
  static const successDark = Color(0xFF10B981);

  /// Fill of a destructive (confirm-delete) button on every theme: white text
  /// on it is 5:1, which the brighter dark-mode [dangerDark] would miss.
  static const dangerFill = Color(0xFFDB2424);

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
