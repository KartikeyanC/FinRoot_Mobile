# M16 — Tablet adaptive layer · completion report

**Date:** 2026-09-09 · **Status:** complete, awaiting approval for M17
**Repo:** `F:\Movie\AK\Finroot App` · builds on `65e442d` (M15) · commit `0318d65`

---

## 1. Scope

The navigation *shell* has switched to a `NavigationRail` at the `expanded`
breakpoint since M2, and Quick Add has opened as a dialog on tablet since M7.
M16 is the **content** side of the same promise (M1 audit §11, §15, §17):

- the rail earns its width — a workspace + Settings footer, inline labels on a
  wide tablet;
- the list screens (Transactions, Trackers, More) become **two-pane
  list/detail** at `expanded` — the row selects, the detail fills the second
  pane instead of a sheet or a pushed route;
- a single reading column stops stretching edge-to-edge on a wide screen.

One codebase, one set of widgets — the layout switches on `MediaQuery` width,
never a build flavor (ADR-0011: "a tablet is a responsive layout inside the
mobile app, not a third target").

**No backend change. No web impact. No new dependency.**

---

## 2. What M16 built

### Breakpoint tokens (`design/tokens/app_breakpoints.dart`)

| Addition | Value | Meaning |
|---|---|---|
| `WindowSize.showsTwoPane` | `== expanded` (≥ 840dp) | list screens render two panes |
| `AppBreakpoints.railExtended` / `railExtendedAt(w)` | 1000dp | rail shows inline labels + a wider footer |
| `AppBreakpoints.contentMaxWidth` | 720 | cap for a single reading column |
| `AppBreakpoints.listPaneWidth` | 372 | fixed width of the list pane |

### `navigation/two_pane.dart` — the split

`TwoPane({list, detail, placeholder})` — a `Row` of a fixed-width list pane, a
divider, and an `Expanded` detail pane that shows `PaneWaiting` (a neutral
"nothing selected yet" state) until something is picked. Callers build it
**only** when `showsTwoPane` is true; on a phone the same screens keep their
single-column flow.

### `navigation/pane_selection.dart` — what's open

Three Riverpod `Notifier`s holding the current selection per two-pane screen:
`selectedTransactionIdProvider`, `selectedTrackerIdProvider` (both `String?`,
null = nothing selected), `selectedMoreRouteProvider` (`String`, defaults to
`/accounts` so the More pane is never empty). Ignored on a phone.

### The rail footer (`navigation/app_shell.dart`)

`_RailFooter` sits below the rail destinations (M1 audit §15 — "the workspace
switcher and profile move to a rail footer"):

- a workspace chip / icon that opens the existing `showWorkspaceSwitcher` sheet
  (only interactive when the user is in more than one workspace);
- a Settings entry → `/settings`.

Compact icons below 1000dp; labelled `TextButton` / workspace-name chip at and
above it, where `NavigationRail.extended` also turns on and the Quick Add
leading action becomes a `FloatingActionButton.extended`.

### Transactions — two-pane (`features/transactions/`)

- `transaction_detail_sheet.dart`: the sheet body is extracted into a public
  **`TransactionDetailView`** (`id`, `onClose`). `openTransactionDetail(context,
  id)` now branches — a **centred dialog** on `expanded`, the bottom sheet on a
  phone — so every caller (Home, tracker detail, ledger) does the right thing.
- `transactions_screen.dart`: at `expanded`, a `TwoPane` — the ledger list on
  the left (selected row tinted), `TransactionDetailView` in the right pane,
  its delete `onClose` clearing the selection. A phone still opens the sheet.

### Trackers — two-pane (`features/trackers/`)

- `tracker_detail_screen.dart`: the body is extracted into a public
  **`TrackerDetailView`** (`trackerId`, `inPane`, `onDeleted`). `inPane` adds a
  compact header (title + Assign + the overflow menu) in place of the
  full-screen route's `AppBar` and FAB. The edit/complete/archive/delete menu
  is a shared `TrackerActionsMenu`. `TrackerDetailScreen` is now a thin
  `Scaffold` wrapper around the view for the `/tracker/:id` route.
- `trackers_screen.dart`: at `expanded`, a `TwoPane` — card taps select
  instead of pushing `/tracker/:id`. The status filter chips now scroll
  horizontally so they fit the 372dp list pane.

### More — two-pane (`features/more/`)

- `more_screen.dart`: at `expanded`, a `TwoPane` — the More list on the left,
  the chosen feature's own screen embedded in the right pane
  (`_MorePaneDetail` maps a route → its `Scaffold` screen; each is already
  self-contained, menu-lock handling included). Tapping a tile sets
  `selectedMoreRouteProvider`. A phone still pushes the route (and still shows
  the "feature turned off" sheet for a locked entry).

### Home — wider-screen column (`features/home/`)

`home_screen.dart` wraps the feed in **`ContentBounds`** (new,
`design/components/content_bounds.dart`) — centres and caps the column at
720dp so the feed reads as a column on a wide tablet rather than a full-bleed
strip. A no-op on a phone.

---

## 3. Verification

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **438 passing** (423 from M1–M15 + 15 new) |
| Device / emulator run | ⚠️ **not performed** — no Android SDK (M2 I-1). Two-pane layout, the rail footer and the extended rail are covered by widget tests that drive `tester.view.physicalSize` to tablet widths against overridden providers. |

New / extended test files:

- `test/navigation/two_pane_test.dart` — placeholder vs detail, generic
  waiting state, list-pane fixed width
- `test/navigation/app_shell_test.dart` — bottom bar at compact, rail +
  Settings action at expanded, extended rail + workspace name past 1000dp
- `test/navigation/breakpoints_test.dart` — `showsTwoPane`, `railExtendedAt`
- `test/features/more/more_screen_test.dart` — single list on a phone, list +
  embedded default (Accounts) pane on a tablet
- `test/features/trackers/trackers_screen_test.dart` — two-pane waiting state,
  selecting a card fills the detail pane
- `test/features/transactions/transactions_screen_test.dart` — two-pane
  waiting state, tapping a row fills the detail pane

---

## 4. Issues / risks

| # | Issue | Impact | Action |
|---|---|---|---|
| I-75 | Two-pane layout, the rail footer and the extended rail are **unrun on a device** (no Android SDK — M2 I-1). Pane proportions, the rail footer at a short landscape height, and the 372dp list-pane density are analyzer + widget-test verified only. | Visual polish unconfirmed | First device run (M19) |
| I-76 | The **pushed full-screen feature routes** (`/budget`, `/goals`, `/accounts`, … reached by deep link, or `/tracker/:id` from Home) do **not** get a body max-width — only their `expanded` pane form (via More) and Home do. On a wide tablet those screens are full-bleed. | Minor readability | Per-screen `ContentBounds` on the body, a small follow-up |
| I-77 | `/tracker/:id` opened from **Home's trackers section** or a transaction's tracker row still **pushes the full-screen route** on a tablet rather than switching the Trackers tab to that selection — cross-branch selection was out of scope. The route renders fine; it's a consistency gap, not a break. | Slightly inconsistent tablet nav | Revisit if it grates; would need a branch-switch + select helper |
| I-78 | The rail footer **trails the destinations** (inside `NavigationRail`'s own scroll area) rather than pinning to the very bottom — `NavigationRail.trailing` with an `Expanded` is unsafe. Fine at every supported tablet height; on a very short window the footer scrolls with the rail. | Cosmetic | Acceptable |
| I-79 | `TwoPane` details are **not** wrapped in `ContentBounds` — the detail pane (≈ 470–830dp) uses its full width. `OutlinedButton.icon` as a bare child of a header `Row` with an `Expanded` sibling forces an infinite width (Flutter's `.icon` `Flexible` + unbounded-measure), so the tracker pane header uses a plain `IconButton` for Assign. | None | Noted so the `.icon`-in-a-Row trap isn't reintroduced |

None block M17.

---

## 5. Phase status

| Phase | | Status |
|---|---|---|
| M1 – M15 | … · voice · insights | ✅ |
| M1.5 | `apply_transaction_mutation` + `client_mutations` (backend package, rev 2) | ⏳ awaiting web-owner review + apply |
| **M16** | **Tablet adaptive layer** — rail footer, two-pane list/detail | ✅ **complete** (this report) |
| M17 | Accessibility + UX audit against the brief's 15 laws + WCAG 2.2 AA; fix | ⬜ **next** |
| M18–M20 | security · testing · release | ⬜ |

**Completed: 16 of 20** (M1–M16).

---

## 6. Next — M17 (Accessibility + UX audit)

A pass over every screen against the brief's 15 laws and WCAG 2.2 AA: target
sizes (the 372dp list pane and the rail footer icons need checking), focus
order and traversal through the two panes, screen-reader labels on the rail
footer and the pane selection, contrast on the selected-row tint, dynamic type
at the `expanded` breakpoint, and the reduced-motion path. Findings, then fixes.

**Stopping here for approval, per the phase-gate rule.**
