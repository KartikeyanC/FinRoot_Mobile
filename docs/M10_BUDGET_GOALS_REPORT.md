# M10 — Budget + Goals · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M11
**Repo:** `F:\Movie\AK\Finroot App` · builds on `7e78309` (M9)

---

## 1. Scope

The monthly **7-jar budget** system (allocations + server-derived spend) and
**savings goals** (targets + contributions through the `goal_contribute` RPC).
Both are menu-gated plan features (ADR-0002) and follow the M8/M9 shape: a
ported pure fold with a parity test, a server roll-up cached in `kv_cache`,
online-only writes. No backend change, no web impact.

---

## 2. What M10 built

### Budget

| File | Purpose |
|---|---|
| `features/budget/domain/budget_buckets.dart` | `kCategoryToBucket` / `bucketForCategory` / `isNonExpenseBucket` / `periodWindow` / `deriveSpent` — ported **verbatim** from web `src/lib/budgetBuckets.ts` |
| `features/budget/domain/budget_spend.dart` | `foldBudgetSpend` (ported from `useBudgetSpend.ts`) — per-category `budget_spend` rows → one number per jar |
| `features/budget/data/budgets_repository.dart` | `watchForPeriod`, `cacheServerRow`, `removeFromCache` |
| `features/budget/data/budget_gateways.dart` | `BudgetSpendGateway` (`budget_spend` RPC); `BudgetWriteGateway` — `budget_set_allocation` RPC (upserts on tenant+bucket+period, web BUG-040) + direct delete |
| `features/budget/application/budget_providers.dart` | `budgetPeriodProvider` (this month), `budgetsForPeriodProvider`, `budgetSpendRowsProvider` (kv_cache + refetch-on-sync), `budgetsWithSpendProvider` — **synthesises every jar** so the whole 7-jar system is always visible |
| `features/budget/application/budget_editor_controller.dart` | setAllocation / delete — session + role + **menu(`budget`)** + online gate |
| `features/budget/presentation/budget_screen.dart` | `/budget` — total allocated / spent, a card per jar with a spend bar, non-expense jars called out |
| `.../allocation_sheet.dart` | set / clear a jar's monthly amount |

### Goals

| File | Purpose |
|---|---|
| `features/goals/domain/goal.dart` | `GoalEntity` — progress / remaining / completion arithmetic |
| `features/goals/domain/goal_draft.dart` | `GoalDraft`, `GoalContribution` (RPC result), `GoalValidators` |
| `features/goals/data/goals_repository.dart` | `watchAll`, `watchById`, `cacheServerRow`, `removeFromCache`, `applyContribution` |
| `features/goals/data/goal_write_gateway.dart` | create / update / delete (direct); **contribute** via `goal_contribute` — the RPC locks the row and owns the invariants (never < 0, never past target, status flips itself) |
| `features/goals/application/goals_providers.dart` · `goal_editor_controller.dart` | `goalsProvider` / `goalByIdProvider`; create / update / delete / contribute — menu(`goals`) gated |
| `features/goals/presentation/goals_screen.dart` | `/goals` — progress bar per goal, Add funds / Adjust, edit / delete |
| `.../goal_form_sheet.dart` · `contribute_sheet.dart` | create / edit; add or take back funds (Add / Take back toggle) |

### Shared fix

`RowMappers` now parses Postgres `date` columns (`period_start`, `start_date`,
`end_date`, `target_date`) as **UTC calendar dates** rather than local midnight
— `.toUtc()` on a locally-parsed bare date shifts it across a day boundary in
any non-UTC zone. This also tightens M9's tracker window by a day.

### Routing

`/budget` and `/goals` are real screens now (were milestone placeholders);
their "M10" tags are removed from the More list.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **246 passing** (204 from M1–M9 + 42 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Screens are widget-tested against overridden providers; folds, repositories and both editor controllers against in-memory Drift / fakes. |

New test files: `budget_buckets_parity_test`, `budget_spend_test`,
`budgets_repository_test`, `budget_editor_test`, `budget_screen_test`,
`goal_draft_test`, `goals_repository_test`, `goal_editor_test`,
`goals_screen_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-39 | Budget + goal writes are **online-only** (no offline queue — like accounts M8, trackers M9). | Can't edit on a plane | Acceptable for V1 |
| I-40 | Budget is **month-only** in V1 (`budgetPeriodProvider` = current month, no picker). Weekly / yearly periods and past months are not browsable on mobile. | Reduced vs web | Add a period picker later |
| I-41 | The category → bucket map is fixed (`kCategoryToBucket`), same as the web today. Per-tenant custom mapping (`tenant_settings`) is not wired. | Custom categories fall to `Needs` | Later phase (also pending on web) |
| I-42 | An unbudgeted jar shows spend = ₹0 even if that bucket's categories had spending — `budget_spend` only returns rows for existing budget rows, matching the web. | Set an allocation to see the number | Matches web |
| I-43 | `budget_spend` / `tracker_spend` / `dashboard_summary` all bucket months in **UTC** (I-31); a budget's `period_start` is now also UTC-pinned, so the client and server windows line up — but both are UTC, not the user's zone. | Edge-of-month spend can land in the neighbouring month | Timezone plugin, later |
| I-44 | Goal contributions do not create a transaction or move an account balance (matches web — a goal is a separate ledger). A user expecting the money to leave an account will not see that. | Expectation mismatch, not a bug | Copy already says "does not touch any account balance" |

None block M11.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M9 | audit · foundation · auth · local DB · sync · Home · Quick Add · ledger + accounts · trackers | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M10** | **Budget + Goals** | ✅ **complete** (this report) |
| M11 | Investments + Net worth (`investments`, `demat_*`, `net_worth_*`; menu-gated) | ⬜ **next** |
| M12–M20 | recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 10 of 20** (M1–M10).

---

## 6. Next — M11 (Investments + Net worth)

The investments list (class-specific fields in `fields jsonb`), demat holdings /
ledger, and the net-worth view (`net_worth_entries` / `net_worth_snapshots`).
Investments is menu-gated; net worth composes accounts (M8) + investments +
manual entries. Same ported-fold + roll-up + online-write shape.

**Stopping here for approval, per the phase-gate rule.**
