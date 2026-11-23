import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/device_prefs.dart';
import '../domain/home_layout.dart';

const _kHomeLayout = 'finroot.home.layout';

/// The order and visibility of the Home cards. Per device by design, like the
/// theme: one phone can open on bills, another on the spending chart. Changes
/// write through at once, so there is no Save step.
class HomeLayoutController extends Notifier<HomeLayout> {
  @override
  HomeLayout build() => HomeLayout.decode(_prefs()?.getString(_kHomeLayout));

  /// Device prefs, or null where none were provided (widget tests): the
  /// layout then lasts for this run only.
  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }

  Future<void> move(int from, int to) => _save(state.move(from, to));

  Future<void> setShown(HomeBlock block, bool shown) =>
      _save(state.withShown(block, shown));

  Future<void> reset() => _save(HomeLayout.defaults);

  /// Puts back a layout, e.g. "Undo" after a reset.
  Future<void> restore(HomeLayout layout) => _save(layout);

  Future<void> _save(HomeLayout next) async {
    if (next == state) return;
    state = next;
    final prefs = _prefs();
    if (prefs == null) return;
    if (next.isDefault) {
      await prefs.remove(_kHomeLayout);
    } else {
      await prefs.setString(_kHomeLayout, next.encode());
    }
  }
}

final homeLayoutProvider = NotifierProvider<HomeLayoutController, HomeLayout>(
  HomeLayoutController.new,
  name: 'homeLayout',
);
