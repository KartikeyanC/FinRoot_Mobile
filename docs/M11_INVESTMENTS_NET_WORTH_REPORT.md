# M11 — Investments + Net worth · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M12
**Repo:** `F:\Movie\AK\Finroot App` · builds on `13a12b0` (M10)

---

## 1. Scope

A simple **investments portfolio** (invested vs current per holding, totals,
return) and a manual **net-worth ledger** (assets − liabilities, with a trend
from `net_worth_snapshots`). Both are menu-gated plan features (ADR-0002) and
**online-only, not cached** — the M1 audit puts investments and net-worth detail
in the "not cached" column, so these read and write live PostgREST like the web.

No backend change, no web impact. **Demat accounts / ledger are deferred**
(niche; the web's `useDematAccounts` is 250 lines of broker-specific flow).

---

## 2. What M11 built

### Investments

| File | Purpose |
|---|---|
| `features/investments/domain/investment.dart` | `InvestmentRecord` — `invested` / `current` getters port the web's per-asset logic (`src/lib/investmentsStore.ts`), with a `_mobile` fast path for records this app writes; `assetLabel` / `assetIcon` / `InvestmentDraft` / validators |
| `features/investments/data/investments_gateway.dart` | `SupabaseInvestmentsGateway` — list / create / update / delete on `investments`. Mobile writes a **normalized** `fields = {name, invested, current, _mobile: '1'}` |
| `features/investments/application/investments_providers.dart` | `investmentsProvider` (FutureProvider, not cached), `portfolioSummaryProvider` (invested / current / gain / return %, by asset) |
| `features/investments/application/investment_editor_controller.dart` | create / update / delete — session + role + **menu(`investments`)** + online gate |
| `features/investments/presentation/investments_screen.dart` · `investment_form_sheet.dart` | portfolio card + holdings list; the simplified add/edit form |

### Net worth

| File | Purpose |
|---|---|
| `features/net_worth/domain/net_worth.dart` | `NetWorthEntry` (`grp` ↔ `group`), `NetWorthTotals.of` (assets − liabilities — the web computes it purely from these manual entries, **not** from accounts/investments), `NetWorthPoint`, asset / liability groups, validators |
| `features/net_worth/data/net_worth_gateway.dart` | `net_worth_entries` CRUD; `history()` from `net_worth_snapshots`; `recordSnapshot()` — upserts today's figures on `(tenant_id, captured_on)` so history accumulates just by opening the screen (web `useNetWorthHistory`) |
| `features/net_worth/application/…` | `netWorthEntriesProvider`, `netWorthTotalsProvider`, `netWorthHistoryProvider` (records a snapshot on load), `netWorthEditorController` (menu(`net-worth`) gated) |
| `features/net_worth/presentation/net_worth_screen.dart` · `entry_form_sheet.dart` | headline (net worth, assets, liabilities), a since-first-snapshot trend line, grouped Assets / Liabilities lists; add / edit / delete |

### Routing

`/investments` and `/net-worth` are real screens now; their "M11" tags are
removed from the More list.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **273 passing** (246 from M1–M10 + 27 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Screens are widget-tested against overridden providers; the investment getters, net-worth arithmetic and both editor controllers against fakes. |

New test files: `investment_getters_test`, `investment_editor_test`,
`investments_screen_test`, `net_worth/net_worth_test`,
`net_worth/net_worth_editor_test`, `net_worth/net_worth_screen_test`.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-45 | Investments + net worth are **not cached** — offline they show an error/retry, and their writes need a connection. | Matches the M1 audit's cache policy | By design |
| I-46 | The mobile investment form is a **simple invested / current value** — the web's per-asset calculators (FD maturity, RD schedule, PF contributions, stock lots) stay web-only. A web-created record still displays correctly (the getters port the web logic); a mobile-created one carries `fields._mobile = '1'`. | Reduced input on mobile | Widen per-asset later if needed |
| I-47 | **Demat accounts / demat ledger are not implemented** on mobile. | A demat-heavy user manages that on the web | Later phase if warranted |
| I-48 | Portfolio and net-worth totals sum figures **as-is** (INR assumption). A USD/AED holding is not FX-converted in the total. V1 is INR (brief §41); the web portfolio totals do the same. | Cross-currency totals slightly off | Matches web; revisit with a real FX need |
| I-49 | `net_worth` is manual-only — it does **not** pull in account balances (M8) or the investments portfolio (this phase). This mirrors the web exactly, but a user may expect composition. | Expectation mismatch | Matches web; a "pull from accounts" helper could be added |
| I-50 | The net-worth snapshot is recorded from the client on screen open (no cron). Opening the screen on two days a week gives two points; not opening it leaves gaps. | Sparse history for infrequent users | Matches web; a pg_cron job can be added server-side later |

None block M12.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M10 | … · trackers · budget + goals | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M11** | **Investments + Net worth** | ✅ **complete** (this report) |
| M12 | Recurring items + Reminders (`recurring_items`, `reminders`; local notifications) | ⬜ **next** |
| M13–M20 | bill scan · voice · AI · tablet · a11y · security · testing · release | ⬜ |

**Completed: 11 of 20** (M1–M11).

---

## 6. Next — M12 (Recurring + Reminders)

Recurring income / expense templates (`recurring_items` — the web materialises
due ones) and reminders (`reminders`, menu-gated), with **local notifications**
(`flutter_local_notifications` + `timezone` — the first genuinely new
dependency since M5) scheduled on device. The "Upcoming" card on Home (M6
placeholder) gets its data source here.

**Stopping here for approval, per the phase-gate rule.**
