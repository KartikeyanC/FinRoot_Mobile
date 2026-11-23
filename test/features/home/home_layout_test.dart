import 'dart:convert';

import 'package:finroot_mobile/features/home/domain/home_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeLayout', () {
    test('the default is every card once, in the order they ship', () {
      expect(HomeLayout.defaults.order, HomeBlock.values);
      expect(HomeLayout.defaults.visible, HomeBlock.values);
      expect(HomeLayout.defaults.isDefault, isTrue);
    });

    test('move puts the card at the index it ends up at', () {
      final l = HomeLayout.defaults.move(
        HomeBlock.bills.index,
        0,
      );
      expect(l.order.first, HomeBlock.bills);
      expect(l.order[1], HomeBlock.nudge);
      expect(l.order.toSet(), HomeBlock.values.toSet());
      expect(l.isDefault, isFalse);

      final back = l.move(0, HomeBlock.bills.index);
      expect(back.order, HomeBlock.values);
      expect(back.isDefault, isTrue);
    });

    test('move to the end, and out-of-range moves, stay whole', () {
      final last = HomeBlock.values.length - 1;
      final l = HomeLayout.defaults.move(0, last);
      expect(l.order.last, HomeBlock.nudge);
      expect(l.order.length, HomeBlock.values.length);
      expect(HomeLayout.defaults.move(99, 0), HomeLayout.defaults);
      expect(HomeLayout.defaults.move(0, 99).order.last, HomeBlock.nudge);
    });

    test('hiding keeps the card in the order but out of the visible list', () {
      final l = HomeLayout.defaults.withShown(HomeBlock.cashFlow, false);
      expect(l.order, HomeBlock.values);
      expect(l.visible, isNot(contains(HomeBlock.cashFlow)));
      expect(l.isShown(HomeBlock.cashFlow), isFalse);
      expect(l.withShown(HomeBlock.cashFlow, true).isDefault, isTrue);
    });

    test('encode and decode round-trip', () {
      final l = HomeLayout.defaults
          .move(HomeBlock.spending.index, 0)
          .withShown(HomeBlock.health, false)
          .withShown(HomeBlock.nudge, false);
      expect(HomeLayout.decode(l.encode()), l);
    });

    test('nothing stored, or anything unreadable, is the default', () {
      for (final raw in [null, '', 'not json', '[]', '{"order": 3}', '42']) {
        expect(HomeLayout.decode(raw), HomeLayout.defaults, reason: '$raw');
      }
    });

    test('unknown ids and repeats are dropped', () {
      final l = HomeLayout.decode(
        jsonEncode({
          'v': 1,
          'order': [
            'bills',
            'aRemovedCard',
            'bills',
            ...HomeBlock.values.map((b) => b.name),
          ],
          'hidden': ['aRemovedCard', 'recent', 7],
        }),
      );
      expect(l.order.first, HomeBlock.bills);
      expect(l.order.length, HomeBlock.values.length);
      expect(l.order.toSet(), HomeBlock.values.toSet());
      expect(l.hidden, {HomeBlock.recent});
    });

    test('a card the stored layout does not know yet goes back in after the '
        'card it follows by default', () {
      // Stored before "insights" and "health" existed, with bills moved first.
      final stored = [
        for (final b in HomeBlock.values)
          if (b != HomeBlock.insights && b != HomeBlock.health) b.name,
      ];
      stored
        ..remove('bills')
        ..insert(0, 'bills');
      final l = HomeLayout.decode(jsonEncode({'order': stored}));

      expect(l.order.first, HomeBlock.bills);
      expect(
        l.order.indexOf(HomeBlock.health),
        l.order.indexOf(HomeBlock.cashFlow) + 1,
      );
      expect(
        l.order.indexOf(HomeBlock.insights),
        l.order.indexOf(HomeBlock.trackers) + 1,
      );
      expect(l.order.length, HomeBlock.values.length);
    });

    test('a new first card goes back at the top', () {
      final stored = [
        for (final b in HomeBlock.values.reversed)
          if (b != HomeBlock.nudge) b.name,
      ];
      final l = HomeLayout.decode(jsonEncode({'order': stored}));
      expect(l.order.first, HomeBlock.nudge);
      expect(l.order[1], HomeBlock.insights);
    });

    test('stored ids are the enum names, never renamed', () {
      // The web dashboard uses the same ids for the cards both have
      // (src/lib/dashboardCards.ts).
      expect(HomeBlock.values.map((b) => b.name), [
        'nudge',
        'netWorth',
        'monthStats',
        'cashFlow',
        'health',
        'spending',
        'bills',
        'investments',
        'recent',
        'trackers',
        'insights',
      ]);
    });
  });
}
