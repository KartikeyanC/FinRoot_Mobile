/// FinRoot Mobile design system — single import surface.
///
/// Tokens (colors, spacing, radius, typography, breakpoints) → theme
/// (`AppTheme`, `FinanceColors`) → components. Screens import this, never the
/// individual token files.
library;

export 'components/amount_text.dart';
export 'components/app_card.dart';
export 'components/badges.dart';
export 'components/bulk_select.dart';
export 'components/button_styles.dart';
export 'components/content_bounds.dart';
export 'components/gradient_fab.dart';
export 'components/ledger_kit.dart';
export 'components/nineflow_kit.dart';
export 'components/placeholder_screen.dart';
export 'components/section_header.dart';
export 'components/state_views.dart';
export 'components/swipe_tabs.dart';
export 'theme/app_theme.dart';
export 'theme/finance_colors.dart';
export 'tokens/app_breakpoints.dart';
export 'tokens/app_colors.dart';
export 'tokens/app_palette.dart';
export 'tokens/app_radius.dart';
export 'tokens/app_shadows.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_typography.dart';
