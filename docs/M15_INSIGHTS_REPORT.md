# M15 — Insights · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M16
**Repo:** `F:\Movie\AK\Finroot App` · builds on `fa213fa` (M14)

---

## 1. Scope

Spending-pattern observations and nudges — the M6 Home "Insights" placeholder
becomes real, plus a full `/insights` screen.

### Rule-based, on device — **not** an LLM

M15 generates insights from data the app **already loads** (`dashboard_summary`
roll-up, budgets, goals, recurring items) with a deterministic rule engine
(`insight_engine.dart`). This was a deliberate call:

- An **AI-backed** version (Gemini over the user's aggregates, like
  `scan-receipt`) would need a **new shared Edge Function**. Edge Functions
  live in the web repo, and the project rule is *never edit web source;
  coordinate backend changes with the web owner*. The M1.5 package is still
  awaiting that same review — adding an untested Deno function unilaterally is
  the wrong move.
- The rule engine ships **now**, works **offline**, costs nothing, is fully
  testable, and never sends a figure off device.
- The AI version is captured as I-72 for a future phase, once the web owner is
  in the loop.

**No backend change, no web impact, no new dependency.**

---

## 2. What M15 built

### `dashboard_summary` model — widened (additive)

`WorkspaceSummary` (`features/summary/domain/workspace_summary.dart`) now also
carries:

| Field | From | Used for |
|---|---|---|
| `monthlySeries: List<MonthPoint>` | `dashboard_summary.monthly` (all months, folded to INR) | savings-rate-vs-average, spend-vs-last-month |
| `categorySpend: List<CategorySpendPoint>` | `dashboard_summary.categories` (current month, INR, largest first) | top category, concentration |

Both are persisted in `toCache` / `fromCache`, so Home insights work offline
like the rest of the feed. M8's existing fields and tests are untouched.

### `features/insights/`

| File | Purpose |
|---|---|
| `domain/insight.dart` | `Insight` (`id`, `kind` = positive/neutral/watch/alert, `title`, `detail`, optional `route`, `priority`) + its icon |
| `domain/insight_engine.dart` | **`buildInsights({summary, budgets, goals, recurring, now})`** — pure, deterministic. Rules: negative savings (alert) · savings rate vs recent average · spending ±15%+ vs last month · biggest category this month · category concentration ≥ 45% · budget jars over / tight (with days-left) · goal fully funded / ≥ 50% funded · recurring bills due in the next 7 days · an onboarding line when nothing fires. Sorted by priority then severity |
| `application/insights_providers.dart` | `insightsProvider` (combines `workspaceSummaryProvider` + `budgetsWithSpendProvider` + `goalsProvider` + `recurringItemsProvider`; skips budget / goal inputs when those menus are locked) · `homeInsightsProvider` (top 3) |
| `presentation/insight_tile.dart` · `insights_screen.dart` | the row widget (accent by kind, tappable when it has a route) and the `/insights` list |

### Home

`home_insights_card.dart` replaces the placeholder — top 3 insights, an
"All N" link to `/insights`, hides itself when the engine has nothing to say.
`home_placeholders.dart` is deleted (it held only this card).

### Routing

`/insights` is a real screen; the More entry is renamed "AI Insights" →
**"Insights"** (it is not AI in V1) and its "M15" tag removed. Not menu-gated.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **423 passing** (404 from M1–M14 + 19 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). The engine, the widened summary parse/cache, the screen and the Home card are all tested against fixtures / overridden providers. |

New test files: `insights/insight_engine_test`, `insights/insights_screen_test`,
`home/home_insights_card_test`; `summary/workspace_summary_test` extended.

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-70 | Insights are **rule-based**, not AI. The rules are hand-tuned thresholds (±15% spend, 45% concentration, 85% budget). They surface the obvious patterns; they will not find subtle ones or phrase things conversationally. | Fewer / blunter insights than an LLM | By design for V1 — see I-72 |
| I-71 | Category trend needs history **by category**, which `dashboard_summary` only gives for the **current** month. So "Dining is up 40% vs your usual" is **not** possible — only "Dining is your biggest / X% of spend this month". | No per-category month-over-month | A wider RPC (`dashboard_summary` returning `categories` per month) would fix it — a backend change, so deferred with I-72 |
| I-72 | **AI-backed insights are not built.** A `generate-insights` Edge Function (Gemini over the roll-up + budgets, returning 2–4 phrased insights) is the natural next step but is a **new Edge Function in the web repo** — needs web-owner review, like M1.5. The `InsightsProvider` is structured so a `RemoteInsightsGateway` could be slotted in front of the rule engine (feature-detect, fall back). | The feature is named for AI but isn't | Package + hand off in a later phase, with the M1.5 backend batch |
| I-73 | The engine reads `budgetsWithSpendProvider` / `goalsProvider`, which are **online-only** (M10). Offline, budget / goal insights disappear (savings, category and recurring insights still work from the cached summary + cached recurring… wait recurring is also online-only). | Offline, insights thin out to the cached-summary ones | Matches each feature's own cache policy |
| I-74 | Recurring items (I-57, M12) are **online-only / not cached**, so the "bills due this week" insight is absent offline. | — | Matches M12 |

None block M16.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M14 | … · bill scan · voice | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M15** | **Insights** (rule-based, on device) | ✅ **complete** (this report) |
| M16 | Tablet layouts (split views, rail) | ⬜ **next** |
| M17–M20 | a11y · security · testing · release | ⬜ |

**Completed: 15 of 20** (M1–M15).

---

## 6. Next — M16 (Tablet)

The adaptive shell already switches to a `NavigationRail` at the `expanded`
breakpoint (M2). M16 is the **content** side: two-pane layouts (ledger + detail,
trackers + detail, budget + jar), wider Home, and making the Quick Add dialog
(already a dialog on tablet) and the review sheets feel right at width.

**Stopping here for approval, per the phase-gate rule.**
