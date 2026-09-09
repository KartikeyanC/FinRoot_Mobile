import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../domain/constants.dart';

/// The structured receipt the `scan-receipt` Edge Function returns (Gemini
/// vision). Shape mirrors the web `ScanResult` (`src/lib/billScan.ts`).
class ScanResult {
  const ScanResult({
    required this.merchant,
    required this.currency,
    required this.items,
    required this.taxLines,
    required this.total,
    this.date,
    this.subtotal,
  });

  final String merchant;
  final String currency;
  final List<ScanItem> items;
  final List<ScanTaxLine> taxLines;
  final Money total;

  /// `YYYY-MM-DD` if the receipt printed one, else null.
  final DateTime? date;
  final Money? subtotal;

  factory ScanResult.fromJson(Map<String, dynamic> j) {
    final currency = (j['currency'] as String?)?.trim();
    final cur = (currency == null || currency.isEmpty) ? 'INR' : currency;
    return ScanResult(
      merchant: (j['merchant'] as String?)?.trim() ?? '',
      currency: cur,
      date: _date(j['date']),
      subtotal: _money(j['subtotal'], cur),
      total: _money(j['total'], cur) ?? Money.zero(cur),
      items: [
        for (final it in (j['items'] as List? ?? const []))
          if (it is Map) ScanItem.fromJson(Map<String, dynamic>.from(it), cur),
      ],
      taxLines: [
        for (final t in (j['taxLines'] as List? ?? const []))
          if (t is Map)
            ScanTaxLine.fromJson(Map<String, dynamic>.from(t), cur),
      ],
    );
  }

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v);
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static Money? _money(Object? v, String currency) {
    if (v == null) return null;
    final d = Decimal.tryParse(v.toString());
    return d == null ? null : Money(d, currency);
  }
}

class ScanItem {
  const ScanItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.amount,
    required this.category,
  });

  final String name;
  final double qty;
  final String unit;
  final Money amount;
  final String category;

  factory ScanItem.fromJson(Map<String, dynamic> j, String currency) => ScanItem(
    name: (j['name'] as String?)?.trim().isNotEmpty == true
        ? (j['name'] as String).trim()
        : 'Item',
    qty: () {
      final q = (j['qty'] as num?)?.toDouble() ?? 1;
      return q > 0 ? q : 1.0;
    }(),
    unit: kScanUnits.contains(j['unit']) ? j['unit'] as String : 'pc',
    amount: ScanResult._money(j['amount'], currency) ?? Money.zero(currency),
    category: normalizeScanCategory(j['category'] as String?),
  );
}

class ScanTaxLine {
  const ScanTaxLine({required this.label, required this.amount});

  final String label;
  final Money amount;

  factory ScanTaxLine.fromJson(Map<String, dynamic> j, String currency) =>
      ScanTaxLine(
        label: (j['label'] as String?)?.trim().isNotEmpty == true
            ? (j['label'] as String).trim()
            : 'Tax',
        amount:
            ScanResult._money(j['amount'], currency) ?? Money.zero(currency),
      );
}

/// Units the Edge Function is allowed to return (web `UNITS`).
const List<String> kScanUnits = ['pc', 'pk', 'kg', 'g', 'L', 'ml'];

/// The `scan-receipt` function's category enum is slightly wider than the
/// mobile expense list — snap anything unrecognised to a real
/// [kExpenseCategories] value so a scanned transaction never renders as an
/// unknown category (web BR: category is a free string, but mobile keeps to
/// the seed list). The only genuine alias is "Travel & Transport".
String normalizeScanCategory(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return 'Other';
  if (kExpenseCategories.contains(v)) return v;
  return switch (v) {
    'Travel & Transport' => 'Transport',
    'Groceries' => 'Food & Dining',
    'Dining' || 'Restaurant' || 'Food' => 'Food & Dining',
    'Medical' || 'Pharmacy' => 'Healthcare',
    _ => 'Other',
  };
}
