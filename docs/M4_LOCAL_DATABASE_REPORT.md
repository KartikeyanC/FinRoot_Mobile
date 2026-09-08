# M4 — Local database · completion report

**Date:** 2026-09-08 · **Status:** complete, awaiting approval for M5
**Repo:** `F:\Movie\AK\Finroot App` · builds on `39c1787` (M1.5)

---

## 1. Scope

An encrypted on-device SQLite database (Drift) holding a **cache** of the
workspace plus the offline **sync outbox** and per-entity **delta cursors**.
This is the storage layer only — the sync engine that fills and drains it is M5.

No backend change. No web impact (nothing here touches Supabase).

---

## 2. What M4 established

| Piece | Detail |
|---|---|
| **`AppDatabase`** (Drift) | 8 tables, `schemaVersion = 1`, `MigrationStrategy` (createAll + `beforeOpen` foreign-keys pragma), dates stored as ISO text for clean `timestamptz` interop |
| **Cached-entity tables** | `local_transactions`, `local_accounts`, `local_trackers`, `local_budgets`, `local_goals` — each with a `_SyncMeta` mixin: `syncStatus`, `pendingMutationId`, `serverUpdatedAt`, `cachedAt`. Money columns are `Decimal` via `DecimalConverter` (stored `numeric(14,2)`-shaped, **never a float** — M1 audit R-9) |
| **`sync_outbox`** | one row per queued local mutation: `mutationId` (unique — the M1.5 idempotency key), `operation`, `entityLocalId`, `payload` (JSON), `status` (pending/inFlight/failed), `attempts`, `lastError` |
| **`sync_states`** | `<entity>:<tenant>` → `cursor` (highest `updated_at` pulled), `lastPulledAt`, `lastFullSyncAt` |
| **`kv_cache`** | small JSON blobs keyed `(scope, key)` — `tenant_settings` custom categories, effective-menus set, etc. |
| **Encryption** | SQLite3MultipleCiphers, compiled from source by the `hooks: user_defines: sqlite3: source: sqlite3mc` block in `pubspec.yaml` (drift's current path — `sqlcipher_flutter_libs` was dropped in drift 2.32). `PRAGMA key` in the connection setup; a `PRAGMA cipher` assert guards that the cipher build is actually loaded |
| **`DatabaseKey`** | 256-bit key from a CSPRNG, kept in the keystore/keychain — never derived from a password, never logged. Deleted by `purgeSecureStorage()` on sign-out (M3) |
| **Self-heal** | on sign-out the key is purged, so the old file can't be opened; `openEncryptedDatabase` detects that once and recreates rather than crash-looping (it's a cache — no data that matters is lost) |
| **DAOs** | `SyncOutboxDao` (enqueue, pendingBatch, markInFlight/markSynced/markRetry/markFailed, requeueFailed, countPending), `SyncStateDao` (forEntity, recordPull, reset) |
| **Providers** | `appDatabaseProvider` (lazy-open, disposed with the scope), `syncOutboxDaoProvider`, `syncStateDaoProvider`, `wipeLocalData(ref)` for sign-out (M5 wires it into the flow) |
| **Schema snapshot** | `drift_schemas/drift_schema_v1.json` — the baseline future migration tests verify against (see `drift_schemas/README.md`) |

---

## 3. Dependencies added

```yaml
dependencies:
  drift: ^2.34.4
  sqlite3: ^3.5.2
  path_provider: ^2.1.6
  path: ^1.9.1
dev_dependencies:
  drift_dev: ^2.34.6
  build_runner: ^2.16.1
```

Plus the `hooks:` block (top of `pubspec.yaml`) that compiles the encrypted
sqlite3 build.

**`sqlcipher_flutter_libs` was NOT added** — pub offered `0.7.0+eol` (the
package is end-of-life). Drift ≥ 2.32 + sqlite3 3.x uses SQLite3MultipleCiphers
via the build hook instead. This also resolved M2 issue I-4 (`drift_dev` ↔
`riverpod_lint` analyzer conflict): `riverpod_lint` was never in the project, so
there was no conflict once the modern encryption path removed the extra native
libs. `flutter_lints` + the strict analyzer settings stay the lint story.

---

## 4. Files

### New (13)

```
lib/data/local/app_database.dart            @DriftDatabase, migration strategy, factories
lib/data/local/app_database.g.dart          generated (committed — deterministic, ~270 KB)
lib/data/local/tables.dart                  8 table definitions + _SyncMeta mixin
lib/data/local/converters.dart              DecimalConverter (Decimal <-> numeric(14,2) string)
lib/data/local/sync_enums.dart              LocalSyncStatus, OutboxStatus, OutboxOperation(wire)
lib/data/local/encrypted_connection.dart    SQLite3MultipleCiphers open + self-heal + in-memory (tests)
lib/data/local/database_key.dart            256-bit key in the keystore
lib/data/local/database_providers.dart      providers + wipeLocalData()
lib/data/local/daos/sync_outbox_dao.dart    (+ .g.dart)
lib/data/local/daos/sync_state_dao.dart     (+ .g.dart)
drift_schemas/drift_schema_v1.json          baseline snapshot
drift_schemas/README.md
test/data/local/app_database_test.dart
test/data/local/sync_outbox_dao_test.dart
test/data/local/sync_state_dao_test.dart
```

### Modified (2)

```
pubspec.yaml / pubspec.lock    + drift/sqlite3/path*, dev drift_dev/build_runner, hooks block
```

---

## 5. Gates

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** (`*.g.dart` excluded, as configured in M2) |
| `flutter test` | ✅ **69 passing** (55 from M1–M3 + 14 new) — **including the Drift tests**: `NativeDatabase.memory()` runs on this Windows host because the sqlite3mc build hook compiles for the test host too |
| `dart run build_runner build` | ✅ clean (142 s first run) |
| `dart run drift_dev schema dump` | ✅ wrote `drift_schema_v1.json` |
| Regression risk to web | ✅ none — no Supabase/schema/RLS/migration/web-source change |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). The encrypted-file path and native cipher have not run on a real device; the schema + DAOs are fully covered by in-memory tests. |

---

## 6. Not built in M4 (deliberate)

- **The sync engine** — pull, push, retry, conflict, realtime, background
  worker. That is M5; M4 only defines the outbox/cursor stores it uses.
- **Repositories / feature reads** — `local_transactions` has no read API yet;
  M8 adds the transaction repository over it.
- **`wipeLocalData` wiring into sign-out** — the function exists; M5 hooks it
  into the flow so the outbox can flush or be abandoned cleanly first. (Today
  sign-out purges the key, and the DB self-heals on next launch — not broken,
  just not tidy.)
- **Migration-test helpers** (`drift_dev schema generate` + `SchemaVerifier`) —
  set up when v2 lands; with only v1 there is nothing to migrate.

---

## 7. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-1 | Android SDK still absent | The encrypted file path / native cipher unrun on device | Install Android Studio + SDK |
| I-10 | The `hooks`/native-assets build path is newer Flutter tooling; iOS/Android release builds must run the sqlite3mc C compile | Could surface build-config work (min deployment target, toolchain) on first device build | First device build will tell; the hook already runs for `flutter test` and `drift_dev` on this machine |
| I-11 | `app_database.g.dart` (~270 KB) is committed | Large diff noise on schema changes | Standard for drift; keeps CI/other clones from needing build_runner |
| I-12 | `Decimal` normalises (`18600.00` → `18600`) — `DecimalConverter` forces `.toStringAsFixed(2)` on write so the stored value stays `numeric(14,2)`-shaped | none now — pinned by a test | keep the converter's `toStringAsFixed(2)` |

None block M5.

---

## 8. Phase status

| Phase | | Status |
|---|---|---|
| M1 | Architecture audit | ✅ |
| M2 | Flutter foundation | ✅ |
| M3 | Authentication | ✅ |
| M1.5 | `apply_transaction_mutation` RPC + `client_mutations` (backend package) | ⏳ **awaiting web-owner review + apply** (`backend/`, commit `39c1787`) |
| **M4** | **Local database** | ✅ **complete** (this report) |
| M5 | Sync engine — outbox drain via M1.5 RPC, delta pull via cursors, retry/backoff, conflict, realtime, background worker, sign-out wipe | ⬜ **next** |
| M6 | Mobile navigation + Home feed | ⬜ |
| M7 | Quick Add — Expense / Income / Transfer | ⬜ |
| M8 | Transactions + Accounts | ⬜ |
| M9 | Trackers | ⬜ |
| M10 | Budget + Goals | ⬜ |
| M11 | Investments + Net Worth | ⬜ |
| M12 | Recurring + Reminders + Notifications | ⬜ |
| M13 | Bill Scan / OCR | ⬜ |
| M14 | Voice-to-ledger | ⬜ |
| M15 | AI insights | ⬜ |
| M16 | Tablet adaptive experience | ⬜ |
| M17 | Accessibility + UX polish | ⬜ |
| M18 | Security + performance audit | ⬜ |
| M19 | Full testing | ⬜ |
| M20 | Production release | ⬜ |

**Completed: 4 of 20** (M1–M4). M1.5 backend package delivered, pending apply.

---

## 9. Next — M5 (Sync engine)

Drain `sync_outbox` through `apply_transaction_mutation` (M1.5) with
exponential backoff and the `Failure`-based retry rules from
`backend/M1.5_CLIENT_CONTRACT.md`; delta-pull each entity using `sync_states`
cursors; reconcile server rows into the cache; Supabase Realtime to invalidate;
a `workmanager` background task; and the sign-out `wipeLocalData` wiring.

**M5 needs the M1.5 migration applied to work end-to-end** — it can be built and
unit-tested against a fake backend first, but a real device/round-trip test
waits on the apply.

**Stopping here for approval, per the phase-gate rule.**
