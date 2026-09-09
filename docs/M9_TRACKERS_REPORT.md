# M9 — Trackers · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M10
**Repo:** `F:\Movie\AK\Finroot App` · builds on `e9724c4` (M8)

---

## 1. Scope

Trackers — the optional contextual dimension on a transaction (ADR-0010): the
list with spend-against-budget, tracker detail, create / edit / lifecycle /
delete, and **assigning** transactions (one at a time from a transaction, or in
bulk from a tracker's date window).

The `trackers` menu is a real plan paywall (ADR-0002); the tab shows a locked
state and every write re-checks the menu before the request. Tracker spend is
server-derived (`tracker_spend()` — ADR-0006, there is no `spent` column).
Tracker and assignment writes are **online-only direct PostgREST** (RLS-gated),
like accounts (M8) and matching the web. No backend change, no web impact.

---

## 2. What M9 built

### The arithmetic, ported (M1 audit §"derived offline")

| File | Purpose |
|---|---|
| `features/trackers/domain/tracker_spend.dart` | `foldTrackerSpend` / `TrackerSpendRow` / `TrackerWithSpend` / `isWithinTrackerWindow` — ported **verbatim** from web `src/lib/trackers.ts` |
| `test/features/trackers/tracker_spend_parity_test.dart` | Pins it against `trackers.test.ts` — money conservation, unknown-tracker drop, income kept separate, transfers in neither, FX fold, zero-budget = no-budget, utilization / negative-remaining, half-open window |

Expenses and income are kept separate (a refund must not make a build look
cheaper); transfers count in neither.

### Reads

| File | Purpose |
|---|---|
| `features/trackers/data/trackers_repository.dart` | `+ watchAll(statuses)`, `watchById`, `cacheServerRow`, `removeFromCache` |
| `features/trackers/data/tracker_gateways.dart` | `SupabaseTrackerSpendGateway` (`tracker_spend` RPC) |
| `features/trackers/application/trackers_providers.dart` | `trackerStatusFilterProvider`, `trackersListProvider`, `trackerByIdProvider`, `trackerSpendRowsProvider` (online fetch + `kv_cache`, offline fallback, refetch on sync), `trackersWithSpendProvider`, `trackerWithSpendProvider`, `trackerTransactionsProvider`, `untaggedForTrackerProvider` |
| `features/transactions/data/transactions_repository.dart` | `+ trackerId` filter on `watchLedger`, `watchUntaggedInWindow`, `setTrackerIdLocally` |

### Writes (online-only, direct PostgREST)

| File | Purpose |
|---|---|
| `features/trackers/domain/tracker_draft.dart` | `TrackerDraft`, `TrackerStatus`, `trackerTypeIcon`, `TrackerValidators` |
| `features/trackers/data/tracker_gateways.dart` | `SupabaseTrackerWriteGateway` — create / update / setStatus / **softDelete** (`deleted_at`, so `transactions.tracker_id` survives) / **assign** (bulk, `tracker_id IS NULL` guard — replay-safe) / unassign |
| `features/trackers/application/tracker_editor_controller.dart` | all of the above — session + role + **menu** + online gate, write, fold into cache, invalidate the spend roll-up |

### Screens

| File | Purpose |
|---|---|
| `features/trackers/presentation/trackers_screen.dart` | rewritten — locked → `MenuLockedView`; else the list with status chips, spend bars, FAB |
| `.../tracker_detail_screen.dart` | header (spent / budget / remaining / inflow), its transactions, actions menu (edit · complete · archive · reopen · delete), Assign FAB. Route `/tracker/:id`. |
| `.../tracker_form_sheet.dart` | create / edit (name, type, start / end date, budget, description) |
| `.../assign_transactions_sheet.dart` | multi-select untagged transactions in the tracker's window → bulk assign |
| `.../tracker_picker_sheet.dart` | pick an active tracker (used from a transaction) |
| `.../widgets/tracker_progress.dart` | the spend-vs-budget bar — list, detail, Home |

### Transaction detail + Home

- `transaction_detail_sheet.dart` — the Tracker row is now interactive: assign
  to a tracker, open the tracker, or remove the tag.
- `home_trackers_section.dart` — the Home trackers card now shows a real
  spend-against-budget bar (was budget only), tapping through to the tracker.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **204 passing** (172 from M1–M8 + 32 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Screens are widget-tested against overridden providers; the fold, repository, filters and the editor controller against in-memory Drift / fakes. |

New test files: `tracker_spend_parity_test`, `tracker_draft_test`,
`tracker_editor_test`, `trackers_screen_test`; plus `watchAll` / `watchById` /
`cacheServerRow` on `trackers_repository_test` and the tracker filters on
`ledger_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-34 | Tracker + assign writes are **online-only** (no offline queue, like accounts — M8 I-26). Offline → `NetworkFailure`. | Can't tag on a plane | Acceptable for V1 |
| I-35 | Assign goes through the `.is('tracker_id', null)` guard, not the M1.5 outbox. A pending-create transaction (not yet on the server) can't be assigned until it syncs — the guard has nothing to match. | Rare; the row shows unassigned until synced | Assign after it syncs |
| I-36 | The mobile tracker form omits `currency` (INR, V1) and `reviewed_at`. The web's historical-review *prompt* (nagging on unreviewed historical trackers) is not ported — only the manual "Assign" flow. | No proactive review prompt | Later phase if wanted |
| I-37 | `tracker_spend` and `trackerSpendRowsProvider` share the "refetch on sync / write" model of `dashboard_summary` (M8). Before the first fetch (or from `kv_cache` offline) trackers show spent = ₹0. | Bars read empty until the first roll-up | By design |
| I-38 | Soft-deleting a tracker removes it from the cache immediately; its transactions keep the stale `tracker_id` locally until the next pull tombstones nothing (the tracker row is gone, txns just point at a missing id → no badge). | Brief: a detail link to a gone tracker | Self-heals; the picker/detail already handle "missing" |

None block M10.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M8 | audit · foundation · auth · local DB · sync · Home · Quick Add · ledger + accounts | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M9** | **Trackers** | ✅ **complete** (this report) |
| M10 | Budget + Goals (`budget_spend` / `goal_contribute`; both menu-gated) | ⬜ **next** |
| M11–M20 | investments/net-worth · recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 9 of 20** (M1–M9).

---

## 6. Next — M10 (Budget + Goals)

Monthly budget buckets with `budget_spend` roll-up and `budget_set_allocation`;
goals with `goal_contribute` (a `SECURITY DEFINER` RPC, like `tracker_spend`).
Both are menu-gated (ADR-0002) and follow the M8/M9 shape: a ported fold with a
parity test, a server roll-up cached in `kv_cache`, online-only writes.

**Stopping here for approval, per the phase-gate rule.**
