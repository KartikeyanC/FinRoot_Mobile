# M6 — Mobile navigation + Home feed · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M7
**Repo:** `F:\Movie\AK\Finroot App` · builds on `00d4821` (M5)

---

## 1. Scope

The first phase with a real UI opinion: the **Home financial feed** — the
mobile design language the brief insists on, *not* a shrunk web dashboard. It
reads entirely from the M4 local cache (instant paint, works offline) and
surfaces M5 sync state so a person can trust what they're looking at.

The navigation shell (bottom bar / rail, Quick Add seam) already existed from
M2; M6 adds the app-wide **sync banner** to it and builds the feed and its
read layer.

No backend change. No web impact (every read is local; no new Supabase calls).

---

## 2. What M6 built

### Read layer (cache → UI, no money maths)

| File | Purpose |
|---|---|
| `features/transactions/domain/transaction.dart` | `TransactionEntity` — plain value type, `Money` amount verbatim, `syncState` |
| `features/transactions/data/transactions_repository.dart` | `watchRecent(tenant, {limit})`, `watchCountSince(tenant, since)` — Drift streams, `pendingDelete` excluded |
| `features/trackers/domain/tracker.dart` | `TrackerEntity` — name, dates, server-set `budget` only |
| `features/trackers/data/trackers_repository.dart` | `watchActive(tenant)` |
| `features/home/application/home_providers.dart` | `recentTransactionsProvider`, `recentActivityCountProvider`, `activeTrackersProvider` — all tenant-scoped, empty when no workspace |
| `core/time/relative_time.dart` | `RelativeTime.short` / `.dayLabel` — testable date phrasing |

Repositories take `AppDatabase` and own no aggregation. Callers get rows and
record counts, never totals — **ADR-0006** (money is server-derived) and
**ADR-0008** (one implementation per rule) both hold: nothing here re-derives a
balance or a sum.

### Sync status surfacing (M5 → UI)

| File | Purpose |
|---|---|
| `features/sync/application/sync_status.dart` | `SyncStatusView` + `syncStatusProvider` — collapses `SyncEngine` state + connectivity + live unsynced count into one of five tones (`synced` · `working` · `waiting` · `offline` · `problem`) |
| `features/sync/presentation/sync_status_widgets.dart` | `SyncStatusBanner` (app-wide; only renders for `offline` / `problem`, with a Retry on `problem`) and `SyncStatusChip` (compact, always-on, in the Home header) |

`SyncStatusBanner` is mounted once in `AppShell` (both the bottom-bar and rail
layouts), above the branch content.

### The feed

| File | Purpose |
|---|---|
| `features/home/presentation/home_screen.dart` | `RefreshIndicator` + `ListView`; pull-to-refresh → `syncNow(force: true)` |
| `…/widgets/home_greeting.dart` | Time-of-day greeting, first name (profile → email local part), workspace name, `SyncStatusChip` |
| `…/widgets/home_snapshot_card.dart` | Headline card — **count** of transactions recorded in the last 30 days (a record count, not money) + an honest "balances and spending totals arrive with Accounts" note |
| `…/widgets/home_quick_actions.dart` | Expense / Income / Transfer — one tap into the shared Quick Add surface (M7 builds the capture behind it) |
| `…/widgets/home_recent_activity.dart` | Last 6 cached transactions, newest first; skeleton while loading; a useful empty state; "See all" → Transactions tab |
| `…/widgets/home_trackers_section.dart` | Active trackers (name, type, server-set budget). Hidden entirely when the trackers menu is locked or there are none |
| `…/widgets/home_placeholders.dart` | "Upcoming" (→ M12) and "Insights" (→ M15) — quiet, honest coming-soon cards |
| `features/transactions/presentation/widgets/transaction_tile.dart` | Reusable row — type avatar, title/subtitle, `AmountText`, pending / not-synced marker. **M8 reuses this.** |

---

## 3. The snapshot decision (why there is no hero money figure)

The brief and the M5 hand-off both list a Home "snapshot". A finance app's
first screen wants a big trustworthy number — but on device we do not have one
yet, and faking it is exactly what the architecture forbids:

- **ADR-0006** — balances, spend, tracker totals, net worth and goal maths are
  **server-derived**. The cache stores what the server sent, nothing recomputes.
- The cache is a **180-day, partial** mirror (M5 `DeltaPuller`) plus unsynced
  local rows — summing it client-side would be wrong *and* a second
  implementation of money maths (**ADR-0008**).

So the snapshot card leads with a **count of records** (accurate — the 180-day
window covers any 30-day range) and explicitly defers the money figure to
**M8**, when server-derived account balances get cached. The old placeholder
already said as much ("Balances appear once accounts sync"); M6 keeps that
honesty rather than inventing a number.

---

## 4. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **119 passing** (95 from M1–M5 + 24 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). The feed is covered by widget tests against overridden providers; the repositories by in-memory Drift tests. |

New test files:

- `test/features/transactions/transactions_repository_test.dart` — ordering, limit, tenant scope, `pendingDelete` exclusion, exact-amount / sync-state mapping, liveness, `watchCountSince`
- `test/features/trackers/trackers_repository_test.dart` — active-only filter, ordering, budget → `Money?`
- `test/features/sync/sync_status_test.dart` — tone resolution (offline wins, failure = problem, busy, waiting, synced), pending/failed split
- `test/features/home/home_screen_test.dart` — greeting, snapshot count (no money), empty vs populated recent, pending marker, trackers section show/hide + menu lock

---

## 5. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-17 | The feed is unrun on a device (no Android SDK — M2 I-1). Layout, `RefreshIndicator` behaviour, safe-area with the sync banner are analyzer + widget-test verified only. | Visual polish unconfirmed | First device run |
| I-18 | `recentActivityCountProvider` computes its 30-day cutoff at provider build time; it does not roll at midnight while the app is foregrounded. | A stale-by-hours cutoff at most | Acceptable; revisit if it matters |
| I-19 | `SyncSnapshot.lastSyncedAt` is in-memory — "Synced 5m ago" resets to "Up to date" after an app restart until the first sync completes. | Cosmetic | Persist in `kv_cache` in a later sync pass if wanted |
| I-20 | Quick actions and the centre FAB both open the same Quick Add sheet — the pre-selected kind is ignored until M7 wires it. | None (M7 owns capture) | M7 |

None block M7.

---

## 6. Phase status

| Phase | | Status |
|---|---|---|
| M1 · M2 · M3 · M4 · M5 | audit · foundation · auth · local DB · sync engine | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M6** | **Mobile navigation + Home feed** | ✅ **complete** (this report) |
| M7 | Quick Add — Expense / Income / Transfer (uses `MutationEnqueuer`) | ⬜ **next** |
| M8 | Transactions + Accounts (reuses `TransactionTile`, `TransactionsRepository`) | ⬜ |
| M9–M20 | trackers · budget/goals · investments/net-worth · recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 6 of 20** (M1–M6).

---

## 7. Next — M7 (Quick Add)

Amount-first Expense / Income / Transfer capture behind the Quick Add seam,
writing through `MutationEnqueuer` (cache + outbox in one transaction, M5) with
a client-supplied `transaction_id`. The optimistic row lands in the cache and
appears in the Home feed immediately with its "Pending" marker — the plumbing
for that is already in place (`TransactionEntity.syncState`, `TransactionTile`).

**Stopping here for approval, per the phase-gate rule.**
