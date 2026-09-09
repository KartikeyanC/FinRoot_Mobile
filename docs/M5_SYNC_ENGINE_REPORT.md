# M5 — Sync engine · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M6
**Repo:** `F:\Movie\AK\Finroot App` · builds on `022435e` (M4)

---

## 1. Scope

The engine that fills and drains the M4 local database: **push** the outbox
through `apply_transaction_mutation` (M1.5), **pull** server changes by cursor,
reconcile into the cache, and decide *when* to run. No feature screens — those
are M6+.

The M1.5 backend package was **revised (rev 2)** as part of this phase — see §6.

---

## 2. What M5 built

### Push — `OutboxProcessor`
Drains `sync_outbox` oldest-first through `MutationGateway`
(`SupabaseMutationGateway` → the RPC). Per entry:

| Outcome | Action |
|---|---|
| `applied` / `replayed` | reconcile the returned row into the cache (`syncStatus = synced`), delete the outbox entry |
| network / timeout / expired token | leave `pending`, **stop the run** (no point trying the next while offline); park as `failed` only after `maxAttempts` (6) |
| `PGRST202` (RPC not deployed) | **hold the whole queue** — no attempt counted; snapshot says "waiting for a backend update" |
| permission / validation / reused id | `failed` + flag the cache row; continue with the next entry |
| `P0002` (row already gone) | drop the local row, clear the entry — the intent is achieved |

### Pull — `DeltaPuller`
Per entity (`account`, `tracker`, `budget`, `goal`, `transaction` — in that
order so a pulled transaction's account/tracker already exist):

- **delta**: `updated_at > cursor`, cursor from `sync_states`, paginated.
- **full**: no cursor + a **prune** of `synced` cache rows the server no longer
  lists (a web-side hard delete). Transactions bounded to a 180-day window so
  the cache stays small.
- A row with an **unsynced local change is never overwritten** — only its
  `serverUpdatedAt` is recorded, so the push (which sends full state) stays
  last-write-wins.
- A tombstoned tracker (`deleted_at != null`) is removed from the cache.

### Orchestration — `SyncEngine` (`Notifier<SyncSnapshot>`)
`syncNow({full, force})` = push → pull, updating a `SyncSnapshot`
(phase / pendingCount / failedCount / lastSyncedAt / lastError) the UI watches.
Guards: one run at a time; a self-imposed exponential-backoff cool-off after a
retryable failure so connectivity flapping can't spin it. `flushBeforeSignOut()`
(5 s best-effort) and `retryFailed()`.

### Triggers — `SyncCoordinator`
Runs the engine on: signed-in + workspace resolved (full the first time per
session per workspace), connectivity returning, app resume
(`AppLifecycleListener`), and Supabase Realtime `postgres_changes` on the five
tables (debounced 2 s). Mounted via `SyncScope` in `app.dart`.

### Write side — `MutationEnqueuer`
`create` / `update` / `delete` write the cache row **and** the outbox entry in
one DB transaction, so the UI updates instantly and the change can't be lost.
The transaction id is client-generated and is the row's PK locally and (rev 2)
on the server — no re-keying. This is the primitive M7 (Quick Add) calls.

### Background — `background_sync.dart` (`workmanager`)
A periodic (1 h) `WorkManager` task that re-inits Supabase + the container in
its isolate and runs one sync. **Device-unverified** (§7).

### Sign-out — `SignOutController`
`flushBeforeSignOut` → `authRepository.signOut` → `wipeLocalData` (DB file +
key). Wired into Settings and the "no workspace" screen.

---

## 3. Dependencies added

```yaml
dependencies:
  workmanager: ^0.10.10   # OS-scheduled background sync
```

---

## 4. Files

### New (16)

```
lib/features/sync/domain/backoff.dart
lib/features/sync/domain/sync_types.dart
lib/features/sync/domain/failure_disposition.dart
lib/features/sync/data/mutation_gateway.dart
lib/features/sync/data/pull_gateway.dart
lib/features/sync/data/row_mappers.dart
lib/features/sync/application/outbox_processor.dart
lib/features/sync/application/delta_puller.dart
lib/features/sync/application/sync_engine.dart
lib/features/sync/application/sync_coordinator.dart
lib/features/sync/application/mutation_enqueuer.dart
lib/features/sync/application/background_sync.dart
lib/features/auth/application/sign_out.dart
test/features/sync/_fakes.dart
test/features/sync/{backoff,failure_disposition,outbox_processor,delta_puller,mutation_enqueuer,sync_engine}_test.dart
```

### Modified (8)

```
lib/app/app.dart                       SyncScope wraps the router
lib/bootstrap.dart                     initBackgroundSync() (fire-and-forget)
lib/data/local/daos/sync_outbox_dao.dart  countFailed(), watchUnsyncedCount()
lib/features/settings/presentation/settings_screen.dart   sign-out → SignOutController
lib/features/workspace/presentation/no_workspace_screen.dart  same
android/app/src/main/AndroidManifest.xml  INTERNET permission (all build types)
ios/Runner/Info.plist                  BGTaskScheduler identifier + UIBackgroundModes
pubspec.yaml / pubspec.lock            + workmanager
backend/*                              M1.5 rev 2 (see §6)
```

---

## 5. Gates

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **95 passing** (69 + 26 new). The sync engine, outbox, puller, enqueuer and backoff are all covered against fake gateways + a real in-memory DB. |
| `dart format` | ✅ applied |
| Regression risk to web | ✅ none from the client. The M1.5 rev-2 SQL is still additive (§6). |
| Device / emulator run | ⚠️ **not performed** (no Android SDK — M2 I-1). The end-to-end round-trip also needs M1.5 **applied**. |

---

## 6. M1.5 revised to rev 2 (client-supplied transaction id)

`create_transaction` now takes an optional `transaction_id` and inserts the row
with it. Reason: offline-first needs the local row's id and the server's id to
be the same from creation — otherwise every synced create has to re-key the
local PK. Still strictly additive: the web omits it and
`transactions.id`'s `gen_random_uuid()` default fires exactly as before; a
reused id from a genuinely different mutation hits the PK and is rejected.

Updated in `backend/`: the SQL (`coalesce(v_txn_id, gen_random_uuid())` in the
create INSERT), `M1.5_WEB_IMPACT.md` (rev-2 note), `M1.5_CLIENT_CONTRACT.md`
(always send `transaction_id`). **No new web follow-up beyond the one already
documented** (§4 of the impact doc — the `dataExport.ts` line).

**Still awaiting web-owner review + apply.**

---

## 7. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-1 | Android SDK absent | The whole sync path is unrun on a device — verification is analyzer + unit tests against fakes | Install Android Studio + SDK |
| I-13 | **`workmanager` (background_sync.dart) is device-unverified** and needs native setup — WorkManager auto-registers on Android; iOS needs the `BGTaskSchedulerPermittedIdentifiers` entry (added) plus the plugin's Swift registration, and the background isolate re-doing Supabase init is the fragile part | Background (app-closed) sync may not fire until this is validated. **Foreground triggers (connectivity, resume, realtime, sign-in) are the primary path and are wired in `SyncCoordinator`.** | First device run; treat background as best-effort |
| I-14 | Conflict resolution is **last-write-wins** (the push sends full state; the server takes it). No merge, no user prompt. | A rare "edited on two devices while offline" case silently keeps the last push | Acceptable for V1 (matches the M1 audit); revisit if it bites |
| I-15 | Realtime subscribes to 5 tables per tenant. On a busy shared workspace that is chatter → debounced to one sync per 2 s, but still. | Minor battery/network | Fine for V1's "few users" profile; tune later |
| I-16 | `pull_gateway` reads via plain PostgREST `.select()` — works **today** without M1.5. Only the push half needs the RPC. | The app can pull and show data before M1.5 lands; it just can't sync local edits out yet (they hold in the queue) | None — this is the intended graceful degradation |

None block M6.

---

## 8. Phase status

| Phase | | Status |
|---|---|---|
| M1 · M2 · M3 · M4 | audit · foundation · auth · local DB | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, **rev 2**) | ⏳ awaiting web-owner review + apply |
| **M5** | **Sync engine** | ✅ **complete** (this report) |
| M6 | Mobile navigation + Home feed (the mobile design language) | ⬜ **next** |
| M7 | Quick Add — Expense / Income / Transfer (uses `MutationEnqueuer`) | ⬜ |
| M8 | Transactions + Accounts | ⬜ |
| M9–M20 | trackers · budget/goals · investments/net-worth · recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 5 of 20** (M1–M5).

---

## 9. Next — M6 (Mobile navigation + Home feed)

The first phase with real UI opinion: the Home financial feed (greeting,
snapshot, quick actions, recent activity from the cache, active trackers,
upcoming, insights placeholder), reading from `local_transactions` etc. via new
repositories, with the offline/pending/failed state from `SyncSnapshot` surfaced
(a pending badge, an offline banner). Establishes the mobile design language the
brief insists on — *not* a shrunk web dashboard.

**Stopping here for approval, per the phase-gate rule.**
