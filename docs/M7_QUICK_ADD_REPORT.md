# M7 — Quick Add · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M8
**Repo:** `F:\Movie\AK\Finroot App` · builds on `2d8f649` (M6)

---

## 1. Scope

Amount-first **Expense / Income / Transfer** capture behind the Quick Add seam
(brief §7). Save writes **locally only** — `MutationEnqueuer` (M5) puts the
optimistic row in the cache and the outbox in one transaction — so the sheet
closes instantly, the row shows on Home with its "Pending" marker (wired in
M6), and it syncs when it can.

No backend change. No web impact. The write path targets the M1.5
`apply_transaction_mutation` envelope that M5 already builds; **M1.5 is still
not applied server-side**, so pushes hold in the outbox until it is (documented
degradation — M5 I-16). The local capture works regardless.

---

## 2. What M7 built

### Capture

| File | Purpose |
|---|---|
| `features/quick_add/domain/quick_add_draft.dart` | `QuickAddKind` (expense/income/transfer → `TxnType`, category list); `kTransferCategory = 'Transfer'` (matches web `transferMeta.ts`); `QuickAddValidators` — pure amount / category / note / date / transfer-account rules |
| `features/quick_add/application/quick_add_controller.dart` | `QuickAddController.submit(...)` — role gate (viewer → `PermissionFailure`), session gate (`AuthFailure`), builds a `TransactionDraft`, `MutationEnqueuer.create`, nudges `SyncEngine`. Returns the new id, throws a `Failure` the sheet shows. |
| `features/quick_add/presentation/quick_add_sheet.dart` | Rewritten — `SegmentedButton` kind switch, amount-first form, entry vs transfer layouts, inline validation, error banner, view-only state |
| `features/quick_add/presentation/widgets/amount_input_field.dart` | The large tabular ₹ amount input (keypad, ≤2 decimals, autofocus). **M8 edit reuses it.** |

Entry (expense/income): amount · category (required) · payment mode (optional)
· date · note. Transfer: amount · from / to account (required, must differ) ·
date · note; `category` is the `Transfer` sentinel, `payment_mode` null, source
in `account_id`, destination in `transfer_to_account_id` — exactly the web
shape. An account picker for expense/income is deliberately deferred to **M8**
(the column is nullable; balances aren't computed yet).

### Accounts read layer (new — minimal, for the transfer picker)

| File | Purpose |
|---|---|
| `features/accounts/domain/account.dart` | `AccountEntity` (id, name, type + `typeLabel`) |
| `features/accounts/data/accounts_repository.dart` | `AccountsRepository.watchAll(tenant)` over the M4 cache |
| `features/accounts/application/accounts_providers.dart` | `workspaceAccountsProvider` — tenant-scoped |

Read-only, mirroring the M6 pattern. **M8 builds account management on top and
adds the write paths.** A workspace with < 2 cached accounts shows a "needs two
accounts" note on the Transfer tab.

### Wiring

- `core/providers/providers.dart` — `currentUserIdProvider` (small seam so
  writers depend on the id, not the whole `User`; overridable in tests).
- `navigation/quick_add_entry.dart` — `openQuickAdd(context, {kind})` now
  pre-selects a segment; Home's quick actions pass Income / Transfer.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **137 passing** (119 from M1–M6 + 18 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). The sheet is widget-tested against overridden providers; the write path against in-memory Drift. |

New test files:

- `test/features/quick_add/quick_add_validators_test.dart` — amount (junk / zero / overflow / symbols+commas), category requiredness, note cap, future date, transfer-account rules
- `test/features/quick_add/quick_add_controller_test.dart` — expense writes a `pendingCreate` row + `create_transaction` outbox entry (payload checked) + engine nudge; transfer shape (Transfer category, null payment mode, both account ids); viewer → `PermissionFailure` with nothing written; no session → `AuthFailure`
- `test/features/quick_add/quick_add_sheet_test.dart` — three kinds + Save, empty-amount validation, view-only state, transfer with / without two accounts

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-21 | Unrun on a device (no Android SDK). Keyboard behaviour, sheet resize with the keypad, `SegmentedButton` at narrow widths are analyzer + widget-test verified only. | Visual polish unconfirmed | First device run |
| I-22 | Expense/income capture cannot attach a paying account yet — `account_id` is always null for non-transfers. | Those rows are "unassigned" until edited | M8 adds the picker |
| I-23 | Currency is fixed to INR at capture (brief V1 rule). The `Money` / draft plumbing already carries a currency, so a picker is additive later. | None for V1 | Later phase if needed |
| I-24 | Pushes still fail until M1.5 is applied (M5 I-16). The row stays `pendingCreate` in the cache and the sync banner shows "didn't sync". | Capture works; sync waits | Web-owner applies M1.5 |
| I-25 | No account-balance validation on a transfer (e.g. overdraw) — the web doesn't do this either, and balances aren't on device. | Matches web | None |

None block M8.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 · M2 · M3 · M4 · M5 · M6 | audit · foundation · auth · local DB · sync · Home feed | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M7** | **Quick Add — Expense / Income / Transfer** | ✅ **complete** (this report) |
| M8 | Transactions + Accounts (reuses `TransactionTile`, `TransactionsRepository`, `AccountsRepository`, `AmountInputField`) | ⬜ **next** |
| M9–M20 | trackers · budget/goals · investments/net-worth · recurring/reminders · bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 7 of 20** (M1–M7).

---

## 6. Next — M8 (Transactions + Accounts)

The full ledger (grouped list, detail sheet, edit via `MutationEnqueuer.update`,
delete, search, filters) and account management (list, create/edit through a
new write path, the paying-account picker back-filled into Quick Add). Server-
derived account balances get cached here — which is what finally lets the Home
snapshot show a real money figure (M6 §3).

**Stopping here for approval, per the phase-gate rule.**
