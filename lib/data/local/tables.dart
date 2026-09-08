import 'package:drift/drift.dart';

import 'converters.dart';
import 'sync_enums.dart';

// ===========================================================================
// The cached subset of the workspace (M1 audit §12).
//
// These tables are NOT the source of truth — the Supabase project is. They
// hold the minimum recent data needed for offline reads and instant UI, plus
// per-row sync metadata. Balances, budget spend, tracker totals, net worth and
// goal maths stay server-derived (ADR-0006); nothing here recomputes money.
//
// `id` is a text column: for a synced row it is the server UUID; for a row
// created offline it is a locally-generated UUID that the sync engine (M5)
// carries through `apply_transaction_mutation` so the server and client agree
// on it (backend/M1.5_CLIENT_CONTRACT.md).
// ===========================================================================

/// Columns every cached-entity table carries.
mixin _SyncMeta on Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// Where this row stands relative to the server.
  TextColumn get syncStatus =>
      textEnum<LocalSyncStatus>().withDefault(const Constant('synced'))();

  /// The outbox `mutationId` that owns the pending local change, if any.
  TextColumn get pendingMutationId => text().nullable()();

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  /// When this cache row was last written locally.
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('LocalTransactionRow')
class LocalTransactions extends Table with _SyncMeta {
  TextColumn get userId => text().nullable()();
  TextColumn get type => text()(); // income | expense | transfer
  TextColumn get amount => text().map(const DecimalConverter())();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get accountId => text().nullable()();
  TextColumn get paymentMode => text().nullable()();
  TextColumn get transferToAccountId => text().nullable()();
  TextColumn get trackerId => text().nullable()();
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalAccountRow')
class LocalAccounts extends Table with _SyncMeta {
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get openingBalance =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalTrackerRow')
class LocalTrackers extends Table with _SyncMeta {
  TextColumn get name => text()();
  TextColumn get type => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// INR-anchored (web keeps tracker budgets in the workspace currency).
  TextColumn get budget => text().map(const DecimalConverter()).nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // active|completed|archived

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalBudgetRow')
class LocalBudgets extends Table with _SyncMeta {
  TextColumn get bucket => text()();
  TextColumn get allocated => text().map(const DecimalConverter())();
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  DateTimeColumn get periodStart => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalGoalRow')
class LocalGoals extends Table with _SyncMeta {
  TextColumn get title => text()();
  TextColumn get category => text().nullable()();
  TextColumn get targetAmount => text().map(const DecimalConverter())();
  TextColumn get currentAmount => text().map(const DecimalConverter())();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Sync infrastructure
// ---------------------------------------------------------------------------

/// The offline mutation queue. One row per local change awaiting the server.
/// The sync engine (M5) drains this; M4 only defines and exercises the store.
@DataClassName('OutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Client-generated UUID. Sent verbatim to `apply_transaction_mutation` on
  /// every retry so a lost response cannot double-apply (M1.5).
  TextColumn get mutationId => text().unique()();

  TextColumn get tenantId => text()();
  TextColumn get entity => text().withDefault(const Constant('transaction'))();
  TextColumn get operation => textEnum<OutboxOperation>()();

  /// The `id` of the cached row this entry affects.
  TextColumn get entityLocalId => text()();

  /// The mutation envelope's `payload` object, as JSON. Null for a delete.
  TextColumn get payload => text().nullable()();

  TextColumn get status =>
      textEnum<OutboxStatus>().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-(entity, workspace) delta-pull bookmark.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  /// `<entity>:<tenantId>`, e.g. `transaction:6f1e…`.
  TextColumn get key => text()();
  TextColumn get entity => text()();
  TextColumn get tenantId => text()();

  /// Highest `updated_at` pulled so far (ISO) — the `gt` bound for the next
  /// delta pull.
  DateTimeColumn get cursor => dateTime().nullable()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  DateTimeColumn get lastFullSyncAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Small JSON blobs that are not worth a typed table: `tenant_settings`
/// (custom categories), the effective-menus set, etc. Keyed by a scope
/// (usually a tenant id) and a name.
@DataClassName('KvCacheRow')
class KvCache extends Table {
  TextColumn get scope => text()();
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {scope, key};
}
