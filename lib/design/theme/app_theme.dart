import 'package:flutter/material.dart';

import '../components/button_styles.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'finance_colors.dart';

/// The FinRoot Mobile design system, expressed as two [ThemeData]s.
///
/// Rules encoded here (restyle spec "NineFlow look, FinRoot green"):
/// - Material 3 throughout (`useMaterial3: true`).
/// - Soft light surfaces: white cards with a hairline border and a warm, low
///   shadow on a #F5F7F4 page. Dark keeps its surfaces, takes the same shapes
///   and black shadows.
/// - Corners from [AppRadius]: 12 inputs, 20 cards/dialogs, 24 sheet tops,
///   fully round buttons, chips, tabs and segmented controls.
/// - One gradient, on the primary [FilledButton] and the active tab
///   ([AppButtonStyles]).
/// - Large touch targets: buttons are min 52dp tall, list rows honour
///   [AppSpacing.minTouchTarget].
/// - Financial hierarchy survives dark mode — semantic colors are redefined,
///   not inverted (brief §33), via the [FinanceColors] extension.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: brightness,
        ).copyWith(
          // fromSeed tones the seed (dark mode gets a pale tint); pin the brand
          // green itself as the primary action color on both themes.
          primary: AppColors.seed,
          onPrimary: Colors.white,
          surface: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
          onSurface: isLight ? AppColors.inkLight : AppColors.inkDark,
          onSurfaceVariant: isLight
              ? AppColors.inkMutedLight
              : AppColors.inkMutedDark,
          outline: isLight ? AppColors.outlineLight : AppColors.outlineDark,
          outlineVariant: isLight
              ? AppColors.surfaceMutedLight
              : AppColors.surfaceMutedDark,
          error: isLight ? AppColors.dangerLight : AppColors.dangerDark,
          // Selection / active-nav fill = the accent tint, green text on it.
          secondaryContainer: isLight
              ? AppColors.accentTintLight
              : AppColors.accentTintDark,
          onSecondaryContainer: isLight
              ? AppColors.brandTextLight
              : AppColors.brandTextDark,
          // Light: menus and popovers are card-white, quiet fills are subtle.
          // Dark keeps the seeded containers.
          surfaceContainerLowest: isLight ? AppColors.surfaceLight : null,
          surfaceContainerLow: isLight ? AppColors.surfaceLight : null,
          surfaceContainer: isLight ? AppColors.surfaceLight : null,
          surfaceContainerHigh: isLight ? AppColors.surfaceMutedLight : null,
          surfaceContainerHighest: isLight
              ? AppColors.surfaceMutedLight
              : null,
        );

    final canvas = isLight ? AppColors.canvasLight : AppColors.canvasDark;
    // Green text/icons; see AppColors.brandTextDark.
    final brandText = isLight ? AppColors.brandTextLight : AppColors.brandTextDark;
    final faint = isLight ? AppColors.inkFaintLight : AppColors.inkFaintDark;
    final inputBorder = isLight
        ? AppColors.inputBorderLight
        : AppColors.outlineDark;
    final accentTint = isLight
        ? AppColors.accentTintLight
        : AppColors.accentTintDark;
    // Shadow tint: warm ink on light, black on dark (same alphas).
    final shadowTint = isLight ? AppColors.inkLight : Colors.black;
    final scrim = AppColors.inkLight.withValues(alpha: 0.3);
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: color, width: width),
        );

    final base = ThemeData(brightness: brightness, fontFamily: AppTypography.fontFamily);
    final text = AppTypography.applyTo(base.textTheme);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      extensions: [isLight ? FinanceColors.light : FinanceColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        // shadow-soft, approximated with a low elevation in a faint tint.
        // AppCard paints the exact two-layer shadow.
        elevation: 1,
        shadowColor: shadowTint.withValues(alpha: 0.2),
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surface,
        selectedColor: accentTint,
        checkmarkColor: brandText,
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Inputs sit on the page tone, a step below the card around them.
        fillColor: canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: faint),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: brandText),
        border: field(inputBorder),
        enabledBorder: field(inputBorder),
        disabledBorder: field(scheme.outline),
        // Spec: primary border at 60% plus a 2px primary glow at 20%.
        // OutlineInputBorder can't paint an outer glow, so a 2px border at
        // 60% stands in for the pair.
        focusedBorder: field(scheme.primary.withValues(alpha: 0.6), 2),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: const StadiumBorder(),
              textStyle: text.labelLarge?.copyWith(
                fontFamily: AppTypography.displayFamily,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              // The brand gradient; see AppButtonStyles for the opt-outs
              // (tonal, destructive).
              backgroundBuilder: AppButtonStyles.gradientBackground,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const StadiumBorder(),
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          foregroundColor: brandText,
          textStyle: text.labelLarge,
        ),
      ),
      // Track = subtle, fully round; the active segment is solid primary with
      // white text. (SegmentedButton drops ButtonStyle.backgroundBuilder, so
      // the gradient can't reach it.)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.outlineVariant,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : states.contains(WidgetState.selected)
                ? Colors.white
                : scheme.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : scheme.onSurfaceVariant,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      // Active tab = a gradient pill inset 4dp in its slot; no underline.
      tabBarTheme: TabBarThemeData(
        indicator: const _PillIndicator(
          gradient: AppButtonStyles.brandGradient,
          inset: EdgeInsets.all(AppSpacing.xs),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        splashBorderRadius: AppRadius.chip,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // shadow-modal (0 24 64 at 22%) approximated with elevation.
        elevation: 24,
        shadowColor: shadowTint.withValues(alpha: 0.22),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        barrierColor: scrim,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: shadowTint.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: accentTint,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        modalBarrierColor: scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        clipBehavior: Clip.antiAlias,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: brandText),
      // Material's default FAB is primaryContainer (a pale mint on light);
      // FABs are primary actions, so they carry the brand green itself.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // Stadium = a circle on the square "+" buttons (it also fills the
        // bottom bar's circular notch) and pill ends on "+ Tracker"-style ones.
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),
    );
  }
}

/// Tab indicator: a fully round gradient pill, inset inside the tab's slot so
/// neighbouring tabs' pills never touch.
class _PillIndicator extends Decoration {
  const _PillIndicator({required this.gradient, required this.inset});

  final Gradient gradient;
  final EdgeInsets inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _PillPainter(this, onChanged);
}

class _PillPainter extends BoxPainter {
  _PillPainter(this.decoration, super.onChanged);

  final _PillIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = decoration.inset.deflateRect(offset & size);
    if (rect.isEmpty) return;
    final paint = Paint()..shader = decoration.gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      paint,
    );
  }
}
