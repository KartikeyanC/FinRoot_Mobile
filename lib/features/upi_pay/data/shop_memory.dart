import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/device_prefs.dart';

/// Which category each shop was paid under, so Scan & pay picks it again
/// the next time that UPI ID is scanned ("srisai@okaxis" → Groceries).
///
/// Per device and per workspace (a shop can be Business in one workspace and
/// Food in another). Kept in SharedPreferences; nothing leaves the phone.
class ShopMemory {
  ShopMemory([this._prefs]);

  final SharedPreferences? _prefs;
  final Map<String, String> _session = {};

  static const prefsKey = 'finroot.upi.shop_categories';

  /// The most shops kept; the oldest are forgotten first.
  static const keep = 300;

  static String key(String tenantId, String vpa) =>
      '$tenantId|${vpa.trim().toLowerCase()}';

  Map<String, String> _all() {
    final raw = _prefs?.getString(prefsKey);
    if (raw == null) return Map.of(_session);
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } on Object {
      return {};
    }
  }

  String? categoryFor(String tenantId, String vpa) =>
      _all()[key(tenantId, vpa)];

  Future<void> remember(String tenantId, String vpa, String category) async {
    final all = _all()..remove(key(tenantId, vpa));
    all[key(tenantId, vpa)] = category; // newest last
    while (all.length > keep) {
      all.remove(all.keys.first);
    }
    final prefs = _prefs;
    if (prefs == null) {
      _session
        ..clear()
        ..addAll(all);
      return;
    }
    await prefs.setString(prefsKey, jsonEncode(all));
  }
}

final shopMemoryProvider = Provider<ShopMemory>((ref) {
  try {
    return ShopMemory(ref.watch(sharedPreferencesProvider));
  } on Object {
    // No device prefs (widget tests): remember for this run only.
    return ShopMemory();
  }
}, name: 'shopMemory');
