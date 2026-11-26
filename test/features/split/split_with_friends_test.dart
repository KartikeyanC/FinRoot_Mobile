import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/split/application/split_providers.dart';
import 'package:finroot_mobile/features/split/data/split_dues_gateway.dart';
import 'package:finroot_mobile/features/split/domain/split_dues.dart';
import 'package:finroot_mobile/features/split/presentation/split_with_friends_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'split_fakes.dart';

void main() {
  late FakeSplitDuesGateway gateway;
  late FakeQuickAddController quickAdd;

  List<Override> overrides({WorkspaceRole role = WorkspaceRole.owner}) => [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(role),
    isOnlineProvider.overrideWithValue(true),
    splitDuesGatewayProvider.overrideWithValue(gateway),
    quickAddControllerProvider.overrideWith(
      (ref) => quickAdd = FakeQuickAddController(ref),
    ),
  ];

  setUp(() => gateway = FakeSplitDuesGateway());

  const people = [
    Allocation(
      id: 'mine',
      label: 'Your amount',
      kind: AllocationKind.mine,
      amount: '333.34',
    ),
    Allocation(
      id: 'f0',
      label: 'Asha',
      kind: AllocationKind.shared,
      amount: '333.33',
    ),
    Allocation(
      id: 'f1',
      label: 'Ravi',
      kind: AllocationKind.shared,
      amount: '333.33',
    ),
  ];

  Future<SplitSaveOutcome> save(ProviderContainer c, String paidBy) => c
      .read(splitWithFriendsControllerProvider)
      .save(
        allocations: people,
        mode: SplitMode.amount,
        total: 1000,
        currency: 'INR',
        paidBy: paidBy,
        category: 'Food & Dining',
        occurredAt: DateTime(2026, 11, 26),
        name: 'Dinner',
        editingId: 'tx9',
      );

  group('split mapping', () {
    test('your share posts as the expense; friends owe you theirs', () async {
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      c.read(quickAddControllerProvider);

      expect(await save(c, kPaidByMe), SplitSaveOutcome.saved);
      expect(quickAdd.calls.single.amount.toStorageString(), '333.34');
      expect(quickAdd.calls.single.editingId, 'tx9');
      expect(quickAdd.calls.single.note, startsWith('Dinner • bill'));
      expect(gateway.inserted.map((d) => (d.person, d.amount, d.direction)), [
        ('Asha', 333.33, DueDirection.owedToMe),
        ('Ravi', 333.33, DueDirection.owedToMe),
      ]);
      expect(gateway.inserted.every((d) => d.sourceId == 'tx9'), isTrue);
      expect(
        gateway.inserted.every((d) => d.source == DueSource.split),
        isTrue,
      );
    });

    test('a friend paid: you owe them your share', () async {
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      await save(c, 'f1');
      expect(gateway.inserted.single.person, 'Ravi');
      expect(gateway.inserted.single.amount, 333.34);
      expect(gateway.inserted.single.direction, DueDirection.iOwe);
    });

    test('missing table: the share still saves, dues are skipped', () async {
      gateway.missing = true;
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      expect(await save(c, kPaidByMe), SplitSaveOutcome.savedWithoutDues);
      expect(quickAdd.calls, hasLength(1));
    });

    test('viewer cannot split', () async {
      final c = ProviderContainer(
        overrides: overrides(role: WorkspaceRole.viewer),
      );
      addTearDown(c.dispose);
      await expectLater(save(c, kPaidByMe), throwsA(isA<PermissionFailure>()));
      expect(gateway.inserted, isEmpty);
    });

    test('insert body matches the web shape', () {
      const d = NewSplitDue(
        person: 'Asha',
        amount: 300,
        currency: 'INR',
        direction: DueDirection.owedToMe,
        source: DueSource.trip,
        sourceId: 'trip1',
        note: 'Trip: Goa',
        settled: true,
      );
      final body = d.toInsert('t1', DateTime.utc(2026, 11, 26));
      expect(body, {
        'person': 'Asha',
        'amount': 300.0,
        'currency': 'INR',
        'direction': 'owed_to_me',
        'source': 'trip',
        'note': 'Trip: Goa',
        'source_id': 'trip1',
        'tenant_id': 't1',
        'settled_amount': 300.0,
        'settled_at': '2026-11-26T00:00:00.000Z',
      });
    });
  });

  testWidgets('screen: equal split of 1000 between you and two friends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SplitWithFriendsScreen(),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('split-total')), '1000');
    await tester.enterText(find.byKey(const Key('split-friend-0')), 'Asha');
    await tester.tap(find.text('Add friend'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('split-friend-1')), 'Ravi');
    await tester.pump();

    expect(find.textContaining('333.34'), findsWidgets);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();

    expect(quickAdd.calls.single.amount.toStorageString(), '333.34');
    expect(gateway.inserted.map((d) => d.person), ['Asha', 'Ravi']);
    expect(gateway.inserted.map((d) => d.amount), [333.33, 333.33]);
  });

  testWidgets('screen: viewer sees view-only and cannot save', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(role: WorkspaceRole.viewer),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SplitWithFriendsScreen(),
        ),
      ),
    );
    expect(find.textContaining('view-only'), findsOneWidget);
    await tester.tap(find.text('Save split'));
    await tester.pump();
    expect(gateway.inserted, isEmpty);
  });
}
