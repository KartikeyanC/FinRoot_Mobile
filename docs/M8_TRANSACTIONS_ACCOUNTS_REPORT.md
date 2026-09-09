# M8 — Transactions ledger + Accounts · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M9
**Repo:** `F:\Movie\AK\Finroot App` · builds on `c583f58` (M7)

---

## 1. Scope

The full **transactions ledger** (grouped list, search, filters, detail sheet,
edit, delete) and **account management** (list with live balances, create /
edit / delete). Server-derived balances get cached here — which is what lets
the Home snapshot show a real money figure at last (M6 §3).

No backend change. No web impact. Reads are the local cache; transaction writes
go through the existing outbox; **account** writes are online-only direct
PostgREST (`accounts` is RLS-gated, never menu-gated — M1 audit §14), exactly
like the web (`src/lib/accountsStore.ts`). `apply_transaction_mutation` (M1.5)
is still unapplied server-side, so transaction pushes hold in the outbox until
it lands (M5 I-16) — the ledger, edit and delete all work locally regardless.

---

## 2. What M8 built

### Balances — the money rules, ported (M1 audit §4)

| File | Purpose |
|---|---|
| `features/accounts/domain/account_balances.dart` | `computeLiveBalances` / `deriveAccountDeltas` / `applyAccountDeltas` / `accountOf` — ported **verbatim** from web `src/lib/accountBalances.ts` |
| `test/features/accounts/account_balances_parity_test.dart` | Pins it against `accountBalances.test.ts` (the worked example, the delta/fold equality, the legacy `[Mode\|id]` prefix, the "a tracker can't move money" invariant) |

`live balance = opening_balance + Σ delta`, where the deltas come from
`dashboard_summary` (server-computed, ADR-0006). The client only adds two
numbers; it never re-reduces the ledger for a total.

### Roll-ups — `dashboard_summary`

| File | Purpose |
|---|---|
| `features/summary/domain/workspace_summary.dart` | `WorkspaceSummary.fromRpc` — account deltas, current-month income/expense folded to INR (`toInr`), lifetime count; `toCache`/`fromCache` |
| `features/summary/data/summary_gateway.dart` | Calls `dashboard_summary(p_tenant_id, p_months, p_tz='UTC')` |
| `features/summary/application/summary_providers.dart` | `workspaceSummaryProvider` — online: fetch + write `kv_cache`; offline / error: last cached copy. Refetches whenever a sync completes. |
| `data/local/kv_cache_store.dart` | Typed access to the `kv_cache` table (M4) for the cached roll-up |

### Accounts

| File | Purpose |
|---|---|
| `features/accounts/domain/account_draft.dart` | `AccountDraft` (name, type, opening balance), `kAccountTypes`, `AccountValidators` |
| `features/accounts/data/account_write_gateway.dart` | `SupabaseAccountWriteGateway` — `insert` / `update` (PATCHes only the columns mobile manages, so web-only fields survive) / `delete` |
| `features/accounts/data/accounts_repository.dart` | `+ cacheServerRow` / `removeFromCache` (fold the returned row into the cache) |
| `features/accounts/application/account_editor_controller.dart` | create / update / delete — role + session + **online** gate, then write, then cache, then invalidate the roll-up |
| `features/accounts/application/accounts_providers.dart` | `+ accountByIdProvider`, `accountBalancesProvider` (opening + delta per account), `totalBalanceProvider` |
| `features/accounts/presentation/accounts_screen.dart` | list with balances + total card, add/edit/delete, "View transactions" → ledger filtered by account |
| `features/accounts/presentation/account_form_sheet.dart` | create / edit sheet |

Route `/accounts` is now a real screen (was a milestone placeholder); wired in
`router.dart` alongside `/settings`.

### Transactions ledger

| File | Purpose |
|---|---|
| `features/transactions/data/transactions_repository.dart` | `+ watchLedger` (type / text / account filters, capped) and `watchById` |
| `features/transactions/domain/day_group.dart` | `groupByDay` — newest-first day groups |
| `features/transactions/application/transactions_providers.dart` | `ledgerFilterProvider` (Notifier), `ledgerProvider`, `transactionByIdProvider` |
| `features/transactions/presentation/transactions_screen.dart` | search field, type chips, account-filter banner, grouped list, pull-to-refresh |
| `features/transactions/presentation/transaction_detail_sheet.dart` | all fields (account names resolved), Edit → Quick Add in edit mode, Delete → confirm → `MutationEnqueuer.delete` |
| `features/transactions/presentation/widgets/day_group_header.dart` | the date label per day block |

### Quick Add (M7) extended

- `QuickAddController.submit` takes `editingId` → `MutationEnqueuer.update`;
  new `deleteTransaction(id)`.
- `QuickAddSheet` hydrates from a `TransactionEntity` for editing (kind fixed);
  a **paying-account picker** is back-filled into the expense / income form
  (M7 I-22), fed by `workspaceAccountsProvider`.
- `openQuickAdd(context, {kind, editing})`.

### Home

- `home_snapshot_card.dart` — with accounts, the hero is now the **total
  balance across accounts** (server-derived), tappable through to `/accounts`;
  the 30-day record count drops to the sub-line. With no accounts it keeps the
  honest count + an "add accounts" nudge.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **172 passing** (137 from M1–M7 + 35 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Screens are widget-tested against overridden providers; the balance fold, roll-up parsing, ledger filters and both controllers against in-memory Drift / fakes. |

New test files: `account_balances_parity_test`, `account_balances_provider_test`,
`account_draft_test`, `account_editor_test`, `accounts_screen_test`,
`summary/workspace_summary_test`, `transactions/ledger_test`,
`transactions/transactions_screen_test`; plus edit / delete cases added to
`quick_add_controller_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-26 | **Account writes are online-only** (no offline queue in V1, matching the web). Offline → `NetworkFailure`, nothing queued. | Can't add an account on a plane | Acceptable for V1; revisit if it bites |
| I-27 | The mobile account form sets **name / type / opening balance** only. Bank, holder, last4, branch, colour, purposes stay web-only; a mobile edit PATCHes just its columns so it never clears them. | Reduced form on mobile | Widen later if wanted |
| I-28 | **Opening date** is set to "today" on create and is not editable on mobile (not in the M4 cache — would need a schema migration). | A back-dated opening balance needs the web | Migration in a later phase if needed |
| I-29 | Balances need the `dashboard_summary` roll-up; until it has loaded (or from `kv_cache` offline) they show **opening balances only**, with a "updates on next sync" hint. | First launch / long offline shows opening figures | By design |
| I-30 | The roll-up only refetches on a completed sync or an account write — not on every local transaction add. An unsynced transaction is not in `dashboard_summary` yet anyway, so the balance is correct-as-of-server until it syncs. | Balance lags an unsynced txn | Correct behaviour given ADR-0006 |
| I-31 | `dashboard_summary` is called with `p_tz='UTC'` (Flutter has no IANA zone without a plugin; Postgres rejects the platform name). | A transaction within a few hours of a month boundary can land in the neighbouring month bucket — affects only the Home current-month figure, not balances | Add a timezone plugin in a later phase |
| I-32 | Ledger search rebuilds the query on every keystroke (no debounce). The cache is bounded (~180 days) so it is cheap. | None observed | Debounce if a huge cache ever makes it lag |
| I-33 | Deleting an account nulls `transactions.account_id` server-side (`ON DELETE SET NULL`); the local cache keeps the old id until the next pull. | Brief staleness on cached rows | Self-heals on sync |

None block M9.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 · M2 · M3 · M4 · M5 · M6 · M7 | audit · foundation · auth · local DB · sync · Home · Quick Add | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M8** | **Transactions ledger + Accounts** | ✅ **complete** (this report) |
| M9 | Trackers (list, detail, spend, assign) — `trackers` menu is a real paywall | ⬜ **next** |
| M10–M20 | budget/goals · investments/net-worth · recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 8 of 20** (M1–M8).

---

## 6. Next — M9 (Trackers)

The trackers list, detail (with server-derived `tracker_spend`), and assigning
a tracker to a transaction (the web's `useAssignToTracker` idempotency pattern —
already replay-safe, M1.5 contract §"not covered"). The `trackers` menu is a
real plan paywall (ADR-0002); the tab already shows a locked state (M6).
`TrackersRepository` and the Home trackers section are in place from M6.

**Stopping here for approval, per the phase-gate rule.**
