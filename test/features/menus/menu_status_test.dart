import 'dart:async';

import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a menu in the effective set is available', () async {
    final container = ProviderContainer(
      overrides: [
        effectiveMenusProvider.overrideWith(
          (ref) async => {'trackers', 'budget'},
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(effectiveMenusProvider.future);

    expect(
      container.read(menuStatusProvider(FeatureMenu.trackers)),
      MenuStatus.available,
    );
    expect(container.read(menuAvailableProvider(FeatureMenu.trackers)), isTrue);
  });

  test('a menu absent from the effective set is locked', () async {
    final container = ProviderContainer(
      overrides: [
        effectiveMenusProvider.overrideWith((ref) async => {'budget'}),
      ],
    );
    addTearDown(container.dispose);
    await container.read(effectiveMenusProvider.future);

    expect(
      container.read(menuStatusProvider(FeatureMenu.trackers)),
      MenuStatus.locked,
    );
    expect(
      container.read(menuAvailableProvider(FeatureMenu.trackers)),
      isFalse,
    );
  });

  test('an error resolves to unknown, never a lock we are unsure of', () async {
    final container = ProviderContainer(
      // No auto-retry — let the error state settle for the assertion.
      retry: (_, _) => null,
      overrides: [
        effectiveMenusProvider.overrideWith(
          (ref) async => throw Exception('rpc down'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(effectiveMenusProvider.future),
      throwsA(isA<Exception>()),
    );

    expect(
      container.read(menuStatusProvider(FeatureMenu.trackers)),
      MenuStatus.unknown,
    );
    // unknown counts as usable — RLS is the real gate.
    expect(container.read(menuAvailableProvider(FeatureMenu.trackers)), isTrue);
  });

  test('while the check is loading, status is unknown (no premature lock)', () {
    final container = ProviderContainer(
      overrides: [
        // Never completes within the test — stays in loading.
        effectiveMenusProvider.overrideWith(
          (ref) => Completer<Set<String>>().future,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(menuStatusProvider(FeatureMenu.trackers)),
      MenuStatus.unknown,
    );
  });
}
