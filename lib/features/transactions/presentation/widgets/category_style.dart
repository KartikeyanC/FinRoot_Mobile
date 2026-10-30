import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../domain/constants.dart';

/// Icon + pastel tint pair for a category, so the same category reads the same
/// everywhere (ledger rows, detail sheet, quick add). Unknown / custom
/// categories fall back to a stable pair picked from the name.
class CategoryStyle {
  const CategoryStyle(this.icon, this.tint, this.color);

  final IconData icon;
  final Color tint;
  final Color color;

  static CategoryStyle of(BuildContext context, String category, TxnType type) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (type == TxnType.transfer) {
      return CategoryStyle(
        Icons.swap_horiz_rounded,
        dark ? AppColors.skyDark : AppColors.skyLight,
        dark ? AppColors.skyFgDark : AppColors.skyFgLight,
      );
    }
    final pairs = <(Color, Color)>[
      (
        dark ? AppColors.mintDark : AppColors.mintLight,
        dark ? AppColors.mintFgDark : AppColors.mintFgLight,
      ),
      (
        dark ? AppColors.coralDark : AppColors.coralLight,
        dark ? AppColors.coralFgDark : AppColors.coralFgLight,
      ),
      (
        dark ? AppColors.skyDark : AppColors.skyLight,
        dark ? AppColors.skyFgDark : AppColors.skyFgLight,
      ),
      (
        dark ? AppColors.butterDark : AppColors.butterLight,
        dark ? AppColors.butterFgDark : AppColors.butterFgLight,
      ),
      (
        dark ? AppColors.violetDark : AppColors.violetLight,
        dark ? AppColors.violetFgDark : AppColors.violetFgLight,
      ),
      (
        dark ? AppColors.roseDark : AppColors.roseLight,
        dark ? AppColors.roseFgDark : AppColors.roseFgLight,
      ),
      (
        dark ? AppColors.tealDark : AppColors.tealLight,
        dark ? AppColors.tealFgDark : AppColors.tealFgLight,
      ),
    ];
    var h = 0;
    for (final c in category.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final pair = pairs[h % pairs.length];
    return CategoryStyle(_icon(category, type), pair.$1, pair.$2);
  }

  static IconData _icon(String category, TxnType type) {
    final c = category.toLowerCase();
    bool has(String s) => c.contains(s);
    if (has('food') || has('dining') || has('grocer')) {
      return Icons.restaurant_rounded;
    }
    if (has('transport') || has('fuel')) return Icons.directions_car_rounded;
    if (has('shop')) return Icons.shopping_bag_rounded;
    if (has('health') || has('medic')) return Icons.favorite_rounded;
    if (has('educat') || has('school')) return Icons.school_rounded;
    if (has('travel') || has('trip')) return Icons.flight_takeoff_rounded;
    if (has('subscri') || has('entertain')) return Icons.movie_rounded;
    if (has('utilit') || has('bill')) return Icons.bolt_rounded;
    if (has('rent') || has('home') || has('house')) return Icons.home_rounded;
    if (has('personal')) return Icons.spa_rounded;
    if (has('salary') || has('freelance') || has('business')) {
      return Icons.payments_rounded;
    }
    if (has('invest') || has('dividend') || has('interest')) {
      return Icons.trending_up_rounded;
    }
    return type == TxnType.income
        ? Icons.south_west_rounded
        : Icons.receipt_long_rounded;
  }
}

/// The category [IconTile] used by ledger rows and the detail sheet.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.type,
    this.size = 44,
  });

  final String category;
  final TxnType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = CategoryStyle.of(context, category, type);
    return IconTile(icon: s.icon, tint: s.tint, color: s.color, size: size);
  }
}
