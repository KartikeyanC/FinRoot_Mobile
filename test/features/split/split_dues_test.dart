// Dart port of the web's src/lib/splitDues.test.ts and
// splitDues.tripPayer.test.ts — same cases, same expected numbers.
import 'package:finroot_mobile/features/split/domain/split_dues.dart';
import 'package:flutter_test/flutter_test.dart';

Allocation _alloc(
  String id,
  String label,
  AllocationKind kind, {
  String amount = '',
  String pct = '',
  String shares = '',
}) => Allocation(
  id: id,
  label: label,
  kind: kind,
  amount: amount,
  pct: pct,
  shares: shares,
);

Transfer _t(String from, String to, double amount, [String ccy = 'INR']) =>
    Transfer(from: from, to: to, amount: amount, currency: ccy);

List<SettleExpense> _trip(
  List<({double amount, String? paidBy, List<String>? splitWith})> items,
) => tripSettleExpenses(items);

void main() {
  group('splitPaise', () {
    test('parts always add back to the whole', () {
      expect(splitPaise(10000, 3), [3334, 3333, 3333]);
      expect(splitPaise(1, 3), [1, 0, 0]);
      expect(splitPaise(500, 0), isEmpty);
    });
  });

  group('splitToDues', () {
    final allocations = [
      _alloc('m', 'Your amount', AllocationKind.mine, amount: '400'),
      _alloc('o', 'Office', AllocationKind.office, amount: '100'),
      _alloc('a', ' Asha ', AllocationKind.shared, amount: '300'),
      _alloc('r', 'Ravi', AllocationKind.shared, amount: '200'),
      _alloc('z', 'Empty', AllocationKind.shared),
    ];
    List<NewSplitDue> run(String paidBy) => splitToDues(
      allocations: allocations,
      mode: SplitMode.amount,
      total: 1000,
      currency: 'INR',
      paidBy: paidBy,
      note: 'Dinner',
      sourceId: 'tx1',
    );

    test('I paid: every shared bucket with money owes me', () {
      expect(run(kPaidByMe), const [
        NewSplitDue(
          person: 'Asha',
          amount: 300,
          currency: 'INR',
          direction: DueDirection.owedToMe,
          source: DueSource.split,
          note: 'Dinner',
          sourceId: 'tx1',
        ),
        NewSplitDue(
          person: 'Ravi',
          amount: 200,
          currency: 'INR',
          direction: DueDirection.owedToMe,
          source: DueSource.split,
          note: 'Dinner',
          sourceId: 'tx1',
        ),
      ]);
    });

    test('a friend paid: I owe that friend my share, nothing else', () {
      final dues = run('r');
      expect(dues, hasLength(1));
      expect(dues.single.person, 'Ravi');
      expect(dues.single.amount, 400);
      expect(dues.single.direction, DueDirection.iOwe);
    });

    test('payer that is not a shared bucket records nothing', () {
      expect(run('o'), isEmpty);
      expect(run('missing'), isEmpty);
    });

    test('percent and shares modes round each due to paise', () {
      final dues = splitToDues(
        allocations: [
          _alloc('m', 'Me', AllocationKind.mine, shares: '1'),
          _alloc('a', 'A', AllocationKind.shared, shares: '1'),
          _alloc('b', 'B', AllocationKind.shared, shares: '1'),
        ],
        mode: SplitMode.shares,
        total: 100,
        currency: 'USD',
        paidBy: kPaidByMe,
      );
      expect(dues.map((d) => d.amount), [33.33, 33.33]);
      expect(dues.every((d) => d.currency == 'USD'), isTrue);
    });
  });

  group('settleUp', () {
    test('you paid everything: each companion pays you their share', () {
      final t = settleUp(const [
        SettleExpense(amount: 300, splitWith: ['A', 'B']),
        SettleExpense(amount: 100, splitWith: ['A']),
      ]);
      expect(t, [_t('A', kMe, 150), _t('B', kMe, 100)]);
    });

    test('nets mutual debts down to the minimum number of transfers', () {
      expect(
        settleUp(const [
          SettleExpense(amount: 300, paidBy: kMe, splitWith: ['A', 'B']),
          SettleExpense(amount: 300, paidBy: 'A', splitWith: ['A', 'B']),
          SettleExpense(amount: 300, paidBy: 'B', splitWith: ['A', 'B']),
        ]),
        isEmpty,
      );

      final chain = settleUp(const [
        SettleExpense(amount: 200, paidBy: kMe, splitWith: ['A']),
        SettleExpense(amount: 200, paidBy: 'A', splitWith: ['B']),
      ]);
      expect(chain.length, lessThanOrEqualTo(2));
      final payers = chain.map((x) => x.from).toSet();
      final payees = chain.map((x) => x.to).toSet();
      expect(payers.any(payees.contains), isFalse);
    });

    test('rounds to paise and conserves every paisa', () {
      final t = settleUp(const [
        SettleExpense(amount: 100, splitWith: ['A', 'B']),
      ]);
      expect(t, [_t('A', kMe, 33.33), _t('B', kMe, 33.33)]);
      for (final x in t) {
        expect(
          (x.amount * 100 - (x.amount * 100).round()).abs() < 1e-9,
          isTrue,
        );
      }
    });

    test('keeps currencies separate', () {
      final t = settleUp(const [
        SettleExpense(amount: 100, currency: 'INR', splitWith: ['A']),
        SettleExpense(
          amount: 40,
          currency: 'USD',
          paidBy: 'A',
          splitWith: ['A'],
        ),
      ]);
      expect(t, [_t('A', kMe, 50), _t(kMe, 'A', 20, 'USD')]);
    });

    test('solo expenses and zero amounts settle nothing', () {
      expect(
        settleUp(const [
          SettleExpense(amount: 500),
          SettleExpense(amount: 0, splitWith: ['A']),
          SettleExpense(amount: 50, splitWith: []),
        ]),
        isEmpty,
      );
    });

    test('only transfers involving you become dues', () {
      final dues = transfersToDues(
        [_t('A', kMe, 10), _t(kMe, 'B', 5), _t('C', 'B', 7)],
        'trip1',
        'Goa',
      );
      expect(dues, const [
        NewSplitDue(
          person: 'A',
          amount: 10,
          currency: 'INR',
          direction: DueDirection.owedToMe,
          source: DueSource.trip,
          sourceId: 'trip1',
          note: 'Trip: Goa',
        ),
        NewSplitDue(
          person: 'B',
          amount: 5,
          currency: 'INR',
          direction: DueDirection.iOwe,
          source: DueSource.trip,
          sourceId: 'trip1',
          note: 'Trip: Goa',
        ),
      ]);
    });
  });

  group('tripPayerName', () {
    test("reads missing / 'you' as ME and keeps a companion's name", () {
      expect(tripPayerName(null), kMe);
      expect(tripPayerName(''), kMe);
      expect(tripPayerName(kTripPayerYou), kMe);
      expect(tripPayerName(' You '), kMe);
      expect(tripPayerName('Asha'), 'Asha');
    });
  });

  group('tripSettleExpenses', () {
    test('treats old items without paidBy as paid by you', () {
      final e = _trip([
        (amount: 300, paidBy: null, splitWith: ['Asha', 'Ravi']),
      ]).single;
      expect(e.amount, 300);
      expect(e.paidBy, kMe);
      expect(e.splitWith, ['Asha', 'Ravi']);
    });

    test(
      'adds a paying companion to the split when the form left them out',
      () {
        expect(
          _trip([(amount: 200, paidBy: 'Asha', splitWith: [])])
              .single
              .splitWith,
          ['Asha'],
        );
        expect(
          _trip([
            (amount: 300, paidBy: 'Asha', splitWith: ['Asha', 'Ravi']),
          ]).single.splitWith,
          ['Asha', 'Ravi'],
        );
      },
    );
  });

  group('settle-up with a companion payer', () {
    test('you owe the companion who paid', () {
      expect(
        settleUp(_trip([(amount: 200, paidBy: 'Asha', splitWith: null)])),
        [_t(kMe, 'Asha', 100)],
      );
    });

    test("nets your payment against a companion's", () {
      expect(
        settleUp(
          _trip([
            (amount: 300, paidBy: null, splitWith: ['Asha']),
            (amount: 100, paidBy: 'Asha', splitWith: []),
          ]),
        ),
        [_t('Asha', kMe, 100)],
      );
    });

    test('settles three people when two of them paid', () {
      expect(
        settleUp(
          _trip([
            (amount: 900, paidBy: 'Asha', splitWith: ['Ravi']),
            (amount: 300, paidBy: kTripPayerYou, splitWith: ['Asha', 'Ravi']),
          ]),
        ),
        [_t('Ravi', 'Asha', 400), _t(kMe, 'Asha', 100)],
      );
    });
  });

  group('duesByPerson', () {
    var n = 0;
    SplitDue due({
      String person = 'A',
      double amount = 100,
      String currency = 'INR',
      DueDirection direction = DueDirection.owedToMe,
      String? settledAt,
      double settledAmount = 0,
    }) => SplitDue(
      id: 'd${n++}',
      person: person,
      amount: amount,
      currency: currency,
      direction: direction,
      source: DueSource.split,
      createdAt: '2026-11-26',
      settledAt: settledAt,
      settledAmount: settledAmount,
    );

    test('groups open dues per person and currency, net of what you owe', () {
      final rows = duesByPerson([
        due(person: 'Asha', amount: 300),
        due(person: 'asha ', amount: 50, direction: DueDirection.iOwe),
        due(person: 'Asha', settledAmount: 40),
        due(person: 'Asha', amount: 999, settledAt: '2026-11-26'),
        due(person: 'Asha', amount: 10, currency: 'USD'),
      ]);
      expect(
        [
          for (final r in rows)
            [r.person, r.currency, r.owedToMe, r.iOwe, r.net],
        ],
        [
          ['Asha', 'INR', 360, 50, 310],
          ['Asha', 'USD', 10, 0, 10],
        ],
      );
    });
  });

  group('isSplitDuesMissing', () {
    test('recognises an unapplied migration', () {
      expect(
        isSplitDuesMissing(
          code: 'PGRST205',
          message: "Could not find the table 'public.split_dues' in the schema cache",
        ),
        isTrue,
      );
      expect(
        isSplitDuesMissing(
          code: '42P01',
          message: 'relation "public.split_dues" does not exist',
        ),
        isTrue,
      );
      expect(
        isSplitDuesMissing(
          code: 'PGRST202',
          message: 'Could not find the function public.split_due_settle',
        ),
        isTrue,
      );
      expect(
        isSplitDuesMissing(code: '42501', message: 'permission denied'),
        isFalse,
      );
      expect(isSplitDuesMissing(), isFalse);
    });
  });
}
