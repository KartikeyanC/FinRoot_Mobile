import 'package:flutter/material.dart';

/// The five colour themes (NineFlow's model). Mode (light / dark / system) is
/// chosen separately; every theme has a light and a dark [AppPalette].
enum AppColorTheme {
  finroot('FinRoot'),
  ocean('Ocean'),
  forest('Forest'),
  berry('Berry'),
  graphite('Graphite');

  const AppColorTheme(this.label);

  /// Shown under the swatch in Settings → Appearance.
  final String label;

  AppPalette palette(Brightness b) => switch ((this, b)) {
    (AppColorTheme.finroot, Brightness.light) => AppPalette.finrootLight,
    (AppColorTheme.finroot, Brightness.dark) => AppPalette.finrootDark,
    (AppColorTheme.ocean, Brightness.light) => AppPalette.oceanLight,
    (AppColorTheme.ocean, Brightness.dark) => AppPalette.oceanDark,
    (AppColorTheme.forest, Brightness.light) => AppPalette.forestLight,
    (AppColorTheme.forest, Brightness.dark) => AppPalette.forestDark,
    (AppColorTheme.berry, Brightness.light) => AppPalette.berryLight,
    (AppColorTheme.berry, Brightness.dark) => AppPalette.berryDark,
    (AppColorTheme.graphite, Brightness.light) => AppPalette.graphiteLight,
    (AppColorTheme.graphite, Brightness.dark) => AppPalette.graphiteDark,
  };

  /// Parses a stored name; anything unknown (or missing) is FinRoot.
  static AppColorTheme fromName(String? name) => AppColorTheme.values
      .firstWhere((t) => t.name == name, orElse: () => AppColorTheme.finroot);
}

/// One theme × mode's surfaces and accent, straight from
/// `design-system/finroot-nineflow-tokens.css`. Installed on [ThemeData] as an
/// extension; read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.page,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.subtle,
    required this.shell,
    required this.shadow,
    required this.tint,
    required this.accent,
    required this.accentText,
    required this.brandA,
    required this.brandB,
  });

  final Brightness brightness;

  /// App background behind every card (`--page`).
  final Color page;

  /// Cards, sheets, dialogs, menus, the bottom bar (`--card`).
  final Color card;

  /// Every 1px border (`--line`).
  final Color line;

  /// Headings and body text (`--ink`).
  final Color ink;

  /// Descriptions, field labels (`--muted`).
  final Color muted;

  /// Placeholders, hints, captions, inactive nav (`--faint`).
  final Color faint;

  /// Quiet fills inside a card, progress tracks (`--subtle`).
  final Color subtle;

  /// The frame around content (`--shell`).
  final Color shell;

  /// Shadow tint: warm brown on light, black on dark (`--shadow`).
  final Color shadow;

  /// Accent tint: active nav pill, selection, icon tiles (`--lav`).
  final Color tint;

  /// Accent for fills, dots, borders, focus, charts (`--lav-fg`).
  final Color accent;

  /// Accent as text, 4.5:1+ on tint, card and page (`--lav-text`).
  final Color accentText;

  /// The one gradient, left to right (`--brand-a` → `--brand-b`).
  final Color brandA;
  final Color brandB;

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get gradient => LinearGradient(colors: [brandA, brandB]);

  /// Text/icon colour on a solid [accent] fill.
  Color get onAccent =>
      accent.computeLuminance() > 0.25 ? const Color(0xFF111111) : Colors.white;

  // ---- FinRoot (default): NineFlow surfaces, FinRoot green ------------------
  static const finrootLight = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFFAF7F0),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFECE7DD),
    ink: Color(0xFF111111),
    muted: Color(0xFF656058),
    faint: Color(0xFF776F64),
    subtle: Color(0xFFF6F2EA),
    shell: Color(0xFFF0EBE2),
    shadow: Color(0xFF3C321E),
    tint: Color(0xFFE3F3EC),
    accent: Color(0xFF0D7A5F),
    accentText: Color(0xFF0C735A),
    brandA: Color(0xFF0E8466),
    brandB: Color(0xFF0A5E48),
  );
  static const finrootDark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF161513),
    card: Color(0xFF201F1C),
    line: Color(0xFF34322D),
    ink: Color(0xFFF5F2EC),
    muted: Color(0xFFA0998F),
    faint: Color(0xFF8E877D),
    subtle: Color(0xFF262521),
    shell: Color(0xFF1C1B18),
    shadow: Color(0xFF000000),
    tint: Color(0xFF173A2F),
    accent: Color(0xFF2FBF8F),
    accentText: Color(0xFF2FBF8F),
    brandA: Color(0xFF0E8466),
    brandB: Color(0xFF0A5E48),
  );

  // ---- Ocean ----------------------------------------------------------------
  static const oceanLight = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFF3F7FC),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFDEE6F1),
    ink: Color(0xFF111111),
    muted: Color(0xFF556171),
    faint: Color(0xFF617187),
    subtle: Color(0xFFECF2FA),
    shell: Color(0xFFE5ECF6),
    shadow: Color(0xFF142850),
    tint: Color(0xFFDEEAFF),
    accent: Color(0xFF1A5BEA),
    accentText: Color(0xFF1A5BEA),
    brandA: Color(0xFF38BDF8),
    brandB: Color(0xFF2563EB),
  );
  static const oceanDark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF0F141C),
    card: Color(0xFF161D28),
    line: Color(0xFF283446),
    ink: Color(0xFFF5F2EC),
    muted: Color(0xFF94A3B8),
    faint: Color(0xFF79879B),
    subtle: Color(0xFF1C2431),
    shell: Color(0xFF131923),
    shadow: Color(0xFF000000),
    tint: Color(0xFF1C305C),
    accent: Color(0xFF60A5FA),
    accentText: Color(0xFF60A5FA),
    brandA: Color(0xFF38BDF8),
    brandB: Color(0xFF2563EB),
  );

  // ---- Forest ---------------------------------------------------------------
  static const forestLight = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFF4F8F3),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE0E9DE),
    ink: Color(0xFF111111),
    muted: Color(0xFF586358),
    faint: Color(0xFF657463),
    subtle: Color(0xFFEDF4EB),
    shell: Color(0xFFE6EFE4),
    shadow: Color(0xFF1E3C1E),
    tint: Color(0xFFDAF2E4),
    accent: Color(0xFF157754),
    accentText: Color(0xFF157754),
    brandA: Color(0xFF34D399),
    brandB: Color(0xFF16805A),
  );
  static const forestDark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF111612),
    card: Color(0xFF181F1A),
    line: Color(0xFF2C382E),
    ink: Color(0xFFF5F2EC),
    muted: Color(0xFF96A596),
    faint: Color(0xFF7B8A7B),
    subtle: Color(0xFF1E2720),
    shell: Color(0xFF151B16),
    shadow: Color(0xFF000000),
    tint: Color(0xFF1A3E2C),
    accent: Color(0xFF56D496),
    accentText: Color(0xFF56D496),
    brandA: Color(0xFF34D399),
    brandB: Color(0xFF16805A),
  );

  // ---- Berry ----------------------------------------------------------------
  static const berryLight = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFFCF5F8),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFF0E0E9),
    ink: Color(0xFF111111),
    muted: Color(0xFF6C5C66),
    faint: Color(0xFF826876),
    subtle: Color(0xFFF8EEF3),
    shell: Color(0xFFF3E6EE),
    shadow: Color(0xFF501E37),
    tint: Color(0xFFFCE0EE),
    accent: Color(0xFFBE2469),
    accentText: Color(0xFFBE2469),
    brandA: Color(0xFFF472B6),
    brandB: Color(0xFFBE2469),
  );
  static const berryDark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF191216),
    card: Color(0xFF231A1F),
    line: Color(0xFF3A2C34),
    ink: Color(0xFFF5F2EC),
    muted: Color(0xFFA896A0),
    faint: Color(0xFF93818C),
    subtle: Color(0xFF2A1F25),
    shell: Color(0xFF1E161B),
    shadow: Color(0xFF000000),
    tint: Color(0xFF541E38),
    accent: Color(0xFFFF80AA),
    accentText: Color(0xFFFF80AA),
    brandA: Color(0xFFF472B6),
    brandB: Color(0xFFBE2469),
  );

  // ---- Graphite -------------------------------------------------------------
  static const graphiteLight = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFF4F4F5),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE2E2E5),
    ink: Color(0xFF111111),
    muted: Color(0xFF5E5E65),
    faint: Color(0xFF6D6D77),
    subtle: Color(0xFFEEEEF0),
    shell: Color(0xFFE7E7EA),
    shadow: Color(0xFF1E1E28),
    tint: Color(0xFFE8E4FC),
    accent: Color(0xFF6348DC),
    accentText: Color(0xFF6348DC),
    brandA: Color(0xFFA78BFA),
    brandB: Color(0xFF6348DC),
  );
  static const graphiteDark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF121214),
    card: Color(0xFF1B1B1E),
    line: Color(0xFF2E2E33),
    ink: Color(0xFFF5F2EC),
    muted: Color(0xFF9898A0),
    faint: Color(0xFF84848D),
    subtle: Color(0xFF212125),
    shell: Color(0xFF161619),
    shadow: Color(0xFF000000),
    tint: Color(0xFF342C60),
    accent: Color(0xFFB09EFF),
    accentText: Color(0xFFB09EFF),
    brandA: Color(0xFFA78BFA),
    brandB: Color(0xFF6348DC),
  );

  @override
  AppPalette copyWith({
    Color? page,
    Color? card,
    Color? line,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? subtle,
    Color? shell,
    Color? shadow,
    Color? tint,
    Color? accent,
    Color? accentText,
    Color? brandA,
    Color? brandB,
  }) => AppPalette(
    brightness: brightness,
    page: page ?? this.page,
    card: card ?? this.card,
    line: line ?? this.line,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    subtle: subtle ?? this.subtle,
    shell: shell ?? this.shell,
    shadow: shadow ?? this.shadow,
    tint: tint ?? this.tint,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    brandA: brandA ?? this.brandA,
    brandB: brandB ?? this.brandB,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: l(page, other.page),
      card: l(card, other.card),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      subtle: l(subtle, other.subtle),
      shell: l(shell, other.shell),
      shadow: l(shadow, other.shadow),
      tint: l(tint, other.tint),
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      brandA: l(brandA, other.brandA),
      brandB: l(brandB, other.brandB),
    );
  }
}

extension AppPaletteX on BuildContext {
  /// The active theme × mode palette. Falls back to FinRoot for widgets built
  /// under a bare [ThemeData] (tests, previews).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppPalette.finrootDark
          : AppPalette.finrootLight);
}
