import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/device_prefs.dart';

/// Which alert triggers this phone has already announced. Device-local on
/// purpose: every phone (and the person's tablet) should announce a trigger
/// once, regardless of which device spotted the price first.
abstract interface class NotifiedAlertsStore {
  Set<String> load();
  Future<void> add(Iterable<String> keys);
}

class PrefsNotifiedAlertsStore implements NotifiedAlertsStore {
  PrefsNotifiedAlertsStore(this._prefs);
  final SharedPreferences _prefs;

  static const key = 'finroot.price_alerts.notified';

  /// Enough for months of alerts; the oldest entries drop off first.
  static const keep = 200;

  @override
  Set<String> load() => (_prefs.getStringList(key) ?? const []).toSet();

  @override
  Future<void> add(Iterable<String> keys) async {
    final list = [...?_prefs.getStringList(key)];
    for (final k in keys) {
      if (!list.contains(k)) list.add(k);
    }
    final trimmed = list.length > keep ? list.sublist(list.length - keep) : list;
    await _prefs.setStringList(key, trimmed);
  }
}

final notifiedAlertsStoreProvider = Provider<NotifiedAlertsStore>(
  (ref) => PrefsNotifiedAlertsStore(ref.watch(sharedPreferencesProvider)),
  name: 'notifiedAlertsStore',
);
