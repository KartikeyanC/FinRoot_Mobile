import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import '../domain/sync_types.dart';

/// Server rows (snake_case JSON from PostgREST) → cache companions.
///
/// Every companion is a *synced* row: `syncStatus` synced, `serverUpdatedAt`
/// set, `pendingMutationId` cleared. The delta puller decides whether to apply
/// it (only over a synced or absent local row — never over a pending edit).
abstract final class RowMappers {
  static DateTime updatedAt(Map<String, dynamic> row) =>
      DateTime.parse(row['updated_at'] as String).toUtc();

  static String id(Map<String, dynamic> row) => row['id'] as String;

  /// `trackers` rows carry a soft-delete; a non-null `deleted_at` means "gone".
  static bool isTombstoned(SyncEntity entity, Map<String, dynamic> row) =>
      entity == SyncEntity.tracker && row['deleted_at'] != null;

  static LocalTransactionsCompanion transaction(Map<String, dynamic> r) {
    return LocalTransactionsCompanion(
      id: Value(r['id'] as String),
      tenantId: Value(r['tenant_id'] as String),
      userId: Value(r['user_id'] as String?),
      type: Value(r['type'] as String),
      amount: Value(_dec(r['amount'])),
      currency: Value((r['currency'] as String?) ?? 'INR'),
      category: Value(r['category'] as String),
      description: Value(r['description'] as String?),
      occurredAt: Value(_dt(r['occurred_at'])),
      accountId: Value(r['account_id'] as String?),
      paymentMode: Value(r['payment_mode'] as String?),
      transferToAccountId: Value(r['transfer_to_account_id'] as String?),
      trackerId: Value(r['tracker_id'] as String?),
      serverCreatedAt: Value(_dtn(r['created_at'])),
      serverUpdatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value(LocalSyncStatus.synced),
      pendingMutationId: const Value(null),
      cachedAt: Value(DateTime.now().toUtc()),
    );
  }

  static LocalAccountsCompanion account(Map<String, dynamic> r) {
    return LocalAccountsCompanion(
      id: Value(r['id'] as String),
      tenantId: Value(r['tenant_id'] as String),
      name: Value(r['name'] as String),
      type: Value(r['type'] as String),
      openingBalance: Value(_decn(r['opening_balance'])),
      color: Value(r['color'] as String?),
      icon: Value(r['icon'] as String?),
      serverUpdatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value(LocalSyncStatus.synced),
      pendingMutationId: const Value(null),
      cachedAt: Value(DateTime.now().toUtc()),
    );
  }

  static LocalTrackersCompanion tracker(Map<String, dynamic> r) {
    return LocalTrackersCompanion(
      id: Value(r['id'] as String),
      tenantId: Value(r['tenant_id'] as String),
      name: Value(r['name'] as String),
      type: Value(r['type'] as String),
      startDate: Value(_dt(r['start_date'])),
      endDate: Value(_dtn(r['end_date'])),
      budget: Value(_decn(r['budget'])),
      description: Value(r['description'] as String?),
      status: Value((r['status'] as String?) ?? 'active'),
      serverUpdatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value(LocalSyncStatus.synced),
      pendingMutationId: const Value(null),
      cachedAt: Value(DateTime.now().toUtc()),
    );
  }

  static LocalBudgetsCompanion budget(Map<String, dynamic> r) {
    return LocalBudgetsCompanion(
      id: Value(r['id'] as String),
      tenantId: Value(r['tenant_id'] as String),
      bucket: Value(r['bucket'] as String),
      allocated: Value(_dec(r['allocated'])),
      period: Value((r['period'] as String?) ?? 'monthly'),
      periodStart: Value(_dt(r['period_start'])),
      serverUpdatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value(LocalSyncStatus.synced),
      pendingMutationId: const Value(null),
      cachedAt: Value(DateTime.now().toUtc()),
    );
  }

  static LocalGoalsCompanion goal(Map<String, dynamic> r) {
    return LocalGoalsCompanion(
      id: Value(r['id'] as String),
      tenantId: Value(r['tenant_id'] as String),
      title: Value(r['title'] as String),
      category: Value(r['category'] as String?),
      targetAmount: Value(_dec(r['target_amount'])),
      currentAmount: Value(_dec(r['current_amount'])),
      currency: Value((r['currency'] as String?) ?? 'INR'),
      targetDate: Value(_dtn(r['target_date'])),
      status: Value((r['status'] as String?) ?? 'active'),
      serverUpdatedAt: Value(_dt(r['updated_at'])),
      syncStatus: const Value(LocalSyncStatus.synced),
      pendingMutationId: const Value(null),
      cachedAt: Value(DateTime.now().toUtc()),
    );
  }

  static Decimal _dec(Object? v) => Decimal.parse((v ?? 0).toString());
  static Decimal? _decn(Object? v) =>
      v == null ? null : Decimal.parse(v.toString());
  static DateTime _dt(Object? v) => DateTime.parse(v! as String).toUtc();
  static DateTime? _dtn(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();
}
