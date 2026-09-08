# ADR-M001 — Flutter supersedes the web repo's Expo/monorepo plan

**Status:** Accepted (2026-09-08). Supersedes the client-technology half of the
web repo's **ADR-0011 — "The mobile app shares the backend and the money logic
through a monorepo"** (status: Proposed).

## Context

Web ADR-0011 proposed that, when the mobile app was staffed, the repository
would become a pnpm workspace with `apps/web` (Vite) and `apps/mobile`
(**Expo + Expo Router**), sharing three packages: `@finroot/core` (the money
arithmetic), `@finroot/data` (the Supabase client + query hooks) and
`@finroot/supabase-types`. The reasoning was sound and still is: *the money
arithmetic, the Supabase contract and the access model must not compute
differently on two clients.*

The product decision (2026-09-08) is **Flutter**, as a standalone repository at
`F:\Movie\AK\Finroot App`, not Expo inside the web monorepo.

That decision invalidates ADR-0011's *mechanism* — a Dart client cannot import
`@finroot/core` — while leaving its *goal* fully intact. Without a replacement
mechanism, `toINR()`, the account-balance fold, the budget/tracker folds and the
savings-rate rule would exist twice, in two languages, drifting silently. That
is precisely the failure web ADR-0008 ("one implementation per rule") and
ADR-0006 ("derive money, never store it") exist to prevent.

## Decision

**Flutter, standalone repo, and the server becomes the shared implementation.**

1. **Roll-ups are computed by Postgres, not by either client.** The mobile app
   calls the same `SECURITY DEFINER` RPCs the web app already uses —
   `dashboard_summary()`, `budget_spend()`, `tracker_spend()`,
   `goal_contribute()`, `mark_recurring_generated()`. These are already the
   single implementation; mobile simply becomes a second caller. No new
   server-side maths is written for mobile.

2. **Exactly three rules are re-implemented in Dart, and only for offline
   display of cached data:**
   - `toInr()` + the fixed FX table (`lib/core/money/currency.dart`)
   - money formatting, `en_IN` lakh/crore grouping (`lib/core/money/money_format.dart`)
   - the account-balance fold and tracker spend fold (added in M8/M9)

   Each is annotated with the web file it mirrors, and each is **pinned by a
   parity test** (`test/core/money/fx_parity_test.dart`,
   `test/domain/constants_test.dart`, and the golden tests M8/M9 add against
   RPC fixtures). If the web file changes and this one does not, CI fails. That
   test is the replacement for the shared package.

3. **Value lists are mirrored, not re-derived** — categories, budget buckets,
   goal categories, tracker types, payment modes, feature-menu ids
   (`lib/domain/constants.dart`), each pinned by the same kind of test. Category
   is not a table in FinRoot; a mobile-invented string would render as "unknown"
   on the web.

4. **The web app does not move.** No `apps/web/`, no pnpm workspace, no change
   to the Lovable editing pipeline. Web ADR-0011's own gate — "Lovable is the
   thing that decides the timing" — is therefore never reached, and the web app
   keeps building exactly as it does today.

5. **`supabase/migrations` stays the single source of truth**, in the web repo,
   append-only. Mobile-driven backend needs (the M1.5 idempotent mutation RPC)
   are authored as new timestamped migrations and reviewed for web impact
   before they are applied.

## Consequences

- **The shared surface shrinks from "logic + data" to "the database".** That is
  a weaker guarantee than a shared TypeScript package, and we accept it in
  exchange for a native Flutter client. The parity tests are what keep it
  honest; **they are not optional**, and a phase that adds a Dart money rule
  without one is incomplete.
- **`@finroot/data` never exists.** Each client writes its own repository layer
  against PostgREST/RPC. The queries must stay shape-compatible — same tables,
  same `tenant_id` filter, same `deleted_at IS NULL` filters — which is a review
  discipline rather than a compiler guarantee.
- **The component layer doubles, as ADR-0011 already predicted.** ~145 web
  components have no mobile equivalent and never will. Mobile builds its own
  design system (`lib/design/`) from its own tokens. This was true for Expo too.
- **Two toolchains, not one.** Flutter/Dart CI alongside the web's Node CI. No
  shared lockfile, no task runner to keep fast — which is *less* standing
  overhead than the monorepo ADR-0011 described.
- **Auth grows a native shape**, unchanged from ADR-0011's prediction: session
  in the keystore/keychain instead of `localStorage`, PKCE, password reset as a
  deep link. The web's Lovable-brokered Google OAuth does not port; V1 is
  email + password only (product decision, 2026-09-08).
- **Web ADR-0011 should be marked Superseded** in the web repo, with a pointer
  here. That edit belongs to the web app's owner — this repo does not modify
  web source.

## Where it lives

`lib/core/money/` · `lib/domain/constants.dart` · `test/core/money/fx_parity_test.dart` ·
`test/domain/constants_test.dart` · [`../M1_ARCHITECTURE_AUDIT.md`](../M1_ARCHITECTURE_AUDIT.md) §10, Risk R-2.
