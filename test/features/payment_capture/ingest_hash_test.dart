import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/payment_capture/domain/ingest_hash.dart';
import 'package:flutter_test/flutter_test.dart';

// The same user and vectors as the web repo's
// supabase/functions/_shared/ingest/normalize.test.ts. If one side changes,
// every ingested row is re-keyed and duplicates get through.
const user = '22222222-2222-2222-2222-222222222222';

void main() {
  test('buckets to the UTC minute, whatever the device zone', () {
    expect(
      utcMinute(DateTime.parse('2026-10-31T14:05:59.999+05:30')),
      '2026-10-31T08:35Z',
    );
  });

  test('vector 1: with an account', () {
    final args = (
      amount: Decimal.parse('1234.5'),
      at: DateTime.parse('2026-10-31T08:35:42Z'),
    );
    expect(
      canonicalDedupKey(
        userId: user,
        amount: args.amount,
        type: IngestType.expense,
        occurredAt: args.at,
        accountLast4: '5678',
      ),
      '$user|1234.50|expense|2026-10-31T08:35Z|5678',
    );
    expect(
      rawPayloadHash(
        userId: user,
        amount: args.amount,
        type: IngestType.expense,
        occurredAt: args.at,
        accountLast4: '5678',
      ),
      '8122132376b4f00cb39781ee7617a5dcfb7971a74b5959fb6b532f906447ddf3',
    );
  });

  test("vector 2: no account is an empty field, not 'null'", () {
    expect(
      rawPayloadHash(
        userId: user,
        amount: Decimal.fromInt(500),
        type: IngestType.income,
        occurredAt: DateTime.parse('2026-10-31T08:35:00Z'),
      ),
      'a3f238c645f1152e3d80a3f752f35d265abb91aaf560f2385f3706b805287142',
    );
  });

  test('an upper-case user id hashes like the lower-case one', () {
    String h(String u) => rawPayloadHash(
      userId: u,
      amount: Decimal.fromInt(1),
      type: IngestType.expense,
      occurredAt: DateTime.utc(2026),
    );
    expect(h(user.toUpperCase()), h(user));
  });
}
