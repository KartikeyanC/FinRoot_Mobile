import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'finance_colors.dart';

/// The FinRoot Mobile design system, expressed as two [ThemeData]s.
///
/// Rules encoded here:
/// - Material 3 throughout (`useMaterial3: true`).
/// - Flat surfaces: cards have no elevation, they sit on a tinted canvas.
/// - Soft corners ([AppRadius]).
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
        );

    final canvas = isLight ? AppColors.canvasLight : AppColors.canvasDark;
    // Green text/icons; see AppColors.brandTextDark.
    final brandText = isLight ? AppColors.seed : AppColors.brandTextDark;
    final base = ThemeData(brightness: brightness);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: AppTypography.applyTo(base.textTheme)
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      extensions: [isLight ? FinanceColors.light : FinanceColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
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
        selectedColor: scheme.secondaryContainer,
        labelStyle: base.textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: brandText),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
          side: BorderSide(color: scheme.outline),
          foregroundColor: brandText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: brandText,
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
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
