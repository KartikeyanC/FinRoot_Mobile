import 'package:finroot_mobile/features/sync/data/mutation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An in-memory `transactions` table with the one constraint that matters
/// here: the primary key.
class _Table implements DirectTransactionWriter {
  final rows = <String, Map<String, dynamic>>{};
  final inserts = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) async {
    inserts.add(row);
    final id = row['id'] as String;
    if (rows.containsKey(id)) {
      throw const PostgrestException(message: 'duplicate key', code: '23505');
    }
    return rows[id] = {...row};
  }

  @override
  Future<Map<String, dynamic>?> select(String tenantId, String id) async {
    final r = rows[id];
    return r != null && r['tenant_id'] == tenantId ? r : null;
  }

  @override
  Future<Map<String, dynamic>?> update(String tenantId, String id, Map<String, dynamic> fields) async {
    final r = await select(tenantId, id);
    if (r == null) return null;
    r.addAll(fields);
    return r;
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    if ((await select(tenantId, id)) != null) rows.remove(id);
  }

  @override
  String? currentUserId() => 'u1';
}

Map<String, dynamic> _envelope(String op, {Map<String, dynamic>? payload, String id = 'txn-1'}) => {
  'mutation_id': 'm-$op',
  'operation': op,
  'tenant_id': 't1',
  'transaction_id': id,
  'payload': ?payload,
};

const _tea = {
  'type': 'expense',
  'amount': '15.00',
  'currency': 'INR',
  'category': 'Food & Dining',
  'occurred_at': '2026-10-29T12:40:00.000Z',
  'description': 'Tea',
  'account_id': null,
  'payment_mode': 'UPI',
  'transfer_to_account_id': null,
  'tracker_id': '',
};

void main() {
  test('a create is stored under the phone\'s own id, with the signed-in user', () async {
    final db = _Table();
    final r = await applyDirect(db, _envelope('create_transaction', payload: _tea));
    expect(r.status, 'applied');
    expect(r.deleted, isFalse);
    expect(db.rows['txn-1'], containsPair('user_id', 'u1'));
    expect(db.rows['txn-1'], containsPair('tenant_id', 't1'));
    expect(db.rows['txn-1']!['amount'], '15.00');
    expect(db.rows['txn-1']!['tracker_id'], isNull, reason: 'blank ids become null');
    expect(r.transaction?['id'], 'txn-1');
  });

  test('retrying a create whose reply was lost never duplicates it', () async {
    final db = _Table();
    await applyDirect(db, _envelope('create_transaction', payload: _tea));
    final again = await applyDirect(db, _envelope('create_transaction', payload: _tea));
    expect(again.status, 'replayed');
    expect(again.transaction?['description'], 'Tea');
    expect(db.rows, hasLength(1));
  });

  test('an update changes the row; one for a missing row is P0002', () async {
    final db = _Table();
    await applyDirect(db, _envelope('create_transaction', payload: _tea));
    final r = await applyDirect(
      db,
      _envelope('update_transaction', payload: {..._tea, 'amount': '20.00', 'occurred_at': null}),
    );
    expect(r.transaction?['amount'], '20.00');
    expect(db.rows['txn-1']!['occurred_at'], '2026-10-29T12:40:00.000Z',
        reason: 'a missing date keeps the stored one, as the RPC does');

    expect(
      () => applyDirect(db, _envelope('update_transaction', payload: _tea, id: 'nope')),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'P0002')),
    );
  });

  test('a delete removes the row and can be repeated', () async {
    final db = _Table();
    await applyDirect(db, _envelope('create_transaction', payload: _tea));
    final r = await applyDirect(db, _envelope('delete_transaction'));
    expect(r.deleted, isTrue);
    expect(db.rows, isEmpty);
    expect((await applyDirect(db, _envelope('delete_transaction'))).deleted, isTrue);
  });

  test('the fields written match the RPC mapping', () {
    expect(transactionFields({'type': 'expense', 'amount': '1', 'currency': '', 'category': 'Other'}), {
      'type': 'expense',
      'amount': '1',
      'currency': 'INR',
      'category': 'Other',
      'description': null,
      'account_id': null,
      'payment_mode': null,
      'transfer_to_account_id': null,
      'tracker_id': null,
    });
  });
}
