# M17 — Accessibility + UX audit · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M18
**Repo:** `F:\Movie\AK\Finroot App` · builds on `0fad25c` (M16)

---

## 1. Scope

An audit of every primary surface against **WCAG 2.2 AA** and the brief's UX
laws, then the fixes. The design system was already a11y-aware from M2
(48/52dp targets, "direction of money never in colour alone", dark mode
redefined rather than inverted), so this milestone is **targeted fixes plus a
verification harness**, not a redesign.

**No backend change. No web impact. No new dependency.**

---

## 2. Audit method

### Automated — Flutter's built-in guidelines

`test/a11y/accessibility_guidelines_test.dart` pumps nine surfaces (Auth in
light **and** dark, Home, Transactions ledger, Transactions with an active
search, Trackers with a near-limit bar, Accounts, Budget, Quick Add sheet,
More) and asserts all three of:

| Guideline | Covers |
|---|---|
| `textContrastGuideline` | WCAG 1.4.3 Contrast (Minimum) — 4.5:1 body, 3:1 large |
| `androidTapTargetGuideline` | WCAG 2.5.8 Target Size + Material 48dp |
| `labeledTapTargetGuideline` | WCAG 4.1.2 Name, Role, Value — every tap target has a name |

**All nine pass.** Contrast was also computed by hand for the semantic-colour
pairs (income / expense / transfer / muted text on canvas and surface, both
themes): every one clears 4.5:1 except `warning`-on-`warningContainer` at 4.15
— which is only ever used for a **graphical** bar fill (needs 3:1) and the
85–99%-of-budget `%` label, never body text.

### Behavioural — `test/a11y/semantics_test.dart`

Six checks that a matcher can't see: the money spoken label, tile merging,
the live-region banner, 2× text-scale reflow of the ledger.

### Manual code sweep

Every `IconButton`, `Image`, `InkWell`, progress indicator and status message
in `lib/` was reviewed for a name, a live region, or a merge.

---

## 3. What M17 fixed

### Design-system roots (cascade everywhere)

| File | Fix | Law / SC |
|---|---|---|
| `design/components/amount_text.dart` | A screen reader read "minus rupee sign 1,234.50". Now every amount carries a **spoken label** — `"Expense ₹1,234.50"` / `"Income …"` / `"Transfer …"` / plain magnitude when typeless. Hero figures **wrap to 2 lines** instead of clipping when text is scaled up. | 1.3.1, 1.4.1, 1.4.4 |
| `design/components/state_views.dart` | `LoadingView` spinner gets a `"Loading"` label; `ErrorView` is a **live region** so an error that replaces content is announced. | 4.1.3, 1.1.1 |
| `design/components/section_header.dart` | Section titles are marked `header: true` (rotor / heading navigation). | 1.3.1, 2.4.6 |
| `navigation/two_pane.dart` | Each pane is a `FocusTraversalGroup` — keyboard / switch traversal runs the whole list, then the whole detail, never interleaved. | 2.4.3 |
| `navigation/app_shell.dart` | Bottom-bar items `excludeSemantics` their inner Icon+Text so the label isn't read twice. | 4.1.2 |

### Status messages → live regions (WCAG 4.1.3, AA)

- `features/sync/presentation/sync_status_widgets.dart` — the **sync banner**
  (offline / failed) is now `liveRegion: true`; its Retry target went 36dp →
  44dp. The Home **sync chip** `excludeSemantics` its inner row (was read
  twice) behind its `"Sync status: …"` label.
- `features/auth/presentation/auth_screen.dart` — the sign-in **error banner**
  is a live region.

### Names on icon-only controls (WCAG 4.1.2)

`AmountInputField` (the label-less amount-first field) gets a
`"Amount in <currency>"` semantic label; tooltips added to the clear / remove
`IconButton`s in Transactions search, Goals & Tracker date pickers, Net-worth
delete, and both Bill-scan review remove buttons; the Bill-scan receipt
thumbnail `Image.memory` gets `semanticLabel: 'Receipt photo'`.

### Grouping (Law of Common Region)

- `features/transactions/presentation/widgets/transaction_tile.dart` — the row
  is one `MergeSemantics` node: "Groceries, Food & Dining · 2 days ago,
  Expense ₹250, Pending" as a single button instead of five stops.
- `features/trackers/presentation/widgets/tracker_progress.dart` — the budget
  bar gets `semanticsLabel: 'Spent against budget'` + `semanticsValue: '<n>%'`.

---

## 4. UX laws — audit result

The app already embodies the relevant laws; M17 confirmed and did not need to
restructure anything.

| Law | Where it already holds |
|---|---|
| **Fitts** | 48/52dp targets in the theme; centre Quick Add FAB; rail Quick Add is the leading action |
| **Hick** | "More" progressive disclosure; three (not ten) capture kinds |
| **Jakob** | Standard Material nav, sheets, forms; no invented patterns |
| **Goal-gradient / Zeigarnik** | Progress bars on trackers, budget jars, goals; "N changes to sync" |
| **Doherty** | Cache-first paint (M4/M6) — the feed is instant and offline |
| **Von Restorff** | One hero figure per screen; one primary CTA |
| **Aesthetic-usability** | The M2 design system as a whole |
| **Postel** | Voice / bill-scan accept loose input and always show a review step |

---

## 5. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **453 passing** (438 from M1–M16 + 15 new a11y) |
| Screen reader on a device (TalkBack / VoiceOver) | ⚠️ **not performed** — no Android SDK (M2 I-1), iOS impossible on Windows. Semantics are verified through the semantics tree in widget tests, not spoken aloud. |

New test files: `test/a11y/accessibility_guidelines_test.dart`,
`test/a11y/semantics_test.dart`.

---

## 6. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-80 | **Not verified with a real screen reader.** The semantics *tree* is asserted; how TalkBack / VoiceOver actually phrase it (pause, emphasis, number reading) is unconfirmed. | Spoken output may still be awkward in places | Device pass in M19 |
| I-81 | **200% text scale** is spot-checked (hero amounts wrap; the ledger reflows without exception) but **not exhaustively** on every form / sheet. Long labels in the custom `_BottomBar` clip with an ellipsis at extreme scale (icon + selected state still communicate). | Some dense layouts may clip at ≥ 200% | Full reflow sweep in M19's test pass |
| I-82 | The **bill-scan tax-strip** remove buttons use `VisualDensity.compact` (~40dp) — above WCAG 2.2's 24px minimum, below Material's 48. | Minor, secondary action | Drop the compact density if the strip has room |
| I-83 | **`prefers-reduced-motion`** is honoured for route / implicit animations (Flutter default) but the `InkSparkle` splash is not dampened. | Cosmetic | Swap to `InkRipple` under `MediaQuery.disableAnimations` if wanted |
| I-84 | Two-pane selection **groups** focus order but does not **move** focus to the detail pane on selection — a switch/keyboard user re-traverses the list. | Touch-first app; minor for AT users | `Focus.requestFocus` on the detail root, a small follow-up |
| I-85 | The `warning` colour on `warningContainer` is 4.15:1 — fine for the bar fill it's used for, **not** for text. If a future screen puts `warning`-coloured body text on that container it would fail. | Latent | Darken `warningLight` a notch (#9A6700 → ~#8A5B00) if it's ever needed as text |

None block M18.

---

## 7. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M16 | … · insights · tablet | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M17** | **Accessibility + UX audit** — WCAG 2.2 AA + UX laws, then fix | ✅ **complete** (this report) |
| M18 | Security review (session, keystore, RLS trust boundary, redaction, deep-link) | ⬜ **next** |
| M19–M20 | full test pass (device, offline, regression) · release | ⬜ |

**Completed: 17 of 20** (M1–M17).

---

## 8. Next — M18 (Security review)

A pass over the client's trust boundary: session + PKCE storage (keystore, not
prefs — M2), the DB encryption key lifecycle (M4), sign-out wipe completeness
(M5), what `redact()` / `ProviderLogger` can still leak, deep-link handling
(`finroot://auth-callback`), the online-only write gateways' reliance on RLS,
and the M1.5 idempotency contract. Findings, then fixes.

**Stopping here for approval, per the phase-gate rule.**
