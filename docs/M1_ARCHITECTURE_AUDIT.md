# FinRoot Mobile + Tablet — M1 Architecture Audit

**Status:** M1 deliverable. Audit only — no implementation has started.
**Date:** 2026-09-08
**Web repo audited:** `F:\Movie\AK\FinRoot\_extracted` — GitHub `KartikeyanC/finboom-galaxy`
**Supabase project:** `ludbntvhagefadfkhrjj` (Postgres 14.17 / PostgREST 14.17), 75 migrations
**New mobile app target:** `F:\Movie\AK\Finroot App` (fresh Flutter project, mobile-first)

> ⚠️ **STOP AFTER READING.** Per the master prompt (§60, §63) implementation of M2 does not begin
> until this audit is explicitly approved. Section 9 (Required shared backend changes) and Section 19
> (Risks) contain decisions that must be made *before* M7 (Quick Add) is built.

---

## 1. Existing architecture summary

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Vite + React 18 + TypeScript, shadcn/ui + Tailwind, React Router, TanStack Query | Plain controlled forms + zod (no react-hook-form). npm, Node 20. |
| Editing pipeline | **Lovable** (`lovable-tagger`, `src/integrations/lovable/`, `@lovable.dev/cloud-auth-js`) | The web app is edited through Lovable. Google OAuth is brokered by the Lovable Cloud auth SDK, not `supabase.auth.signInWithOAuth`. |
| Backend | Supabase — Postgres + Auth (GoTrue) + Edge Functions (Deno) + Storage | RLS-enforced. Single cloud project, no local stack in normal use (ADR-0004). |
| Hosting | Frontend on Vercel; Supabase free→Pro; email via Resend; billing via **Paddle** | Cost-first, free-tier-first. |
| Product shape | Personal finance tracker that became a **small multi-tenant SaaS** with a Product Owner (PO) admin console | Low traffic, few users. |

**Scale:** ~34 public tables, ~60 RPCs, 6 edge functions (`billing-api`, `live-price`,
`payments-webhook`, `po-auth`, `scan-receipt`, `send-email` — `send-email` is deliberately not
deployed). Gates on `master` (per repo CLAUDE.md, 2026-09-07): `tsc` 0 errors · eslint 0 errors /
24 warnings · vitest 813 passing · Playwright runs serially.

**Hard rules inherited from the web repo (apply to any shared-backend work):**

- Never edit an existing migration. Add a new timestamped one in `supabase/migrations/`.
- Never hand-edit `src/integrations/supabase/{client,types}.ts` — regenerate with `supabase gen types`.
- Security is server-side. RLS is the gate; client checks are convenience only.
- PO reads **aggregates only**, via `SECURITY DEFINER` RPCs — never raw finance rows.
- No new paid services without approval. Stay on free tiers.
- One implementation per rule (ADR-0008). Money is derived, never stored (ADR-0006).

**Directly relevant ADRs:** 0001 (membership multi-tenancy), 0002 (menus are a real paywall),
0003 (Postgres for shared state), 0006 (derive money, never store it), 0007 (app-lock is not
security), 0008 (one implementation per rule), 0010 (a tracker is a dimension, not a ledger),
**0011 (monorepo split — proposes Expo, not Flutter; see Risk R-2)**.

---

## 2. Supabase schema summary

All finance tables carry `tenant_id uuid NOT NULL DEFAULT current_tenant_id()` → `tenants(id)`,
RLS enabled, 4 policies each (`is_tenant_member` + often `has_menu`), an `updated_at` trigger, and
money columns as `numeric(14,2)` (net worth `numeric(16,2)`).

**Identity / tenancy / access**
`profiles` · `tenants` · `tenant_members` · `invitations` · `platform_admins` ·
`tenant_settings` (K/V JSON, per tenant) · `site_settings` (K/V JSON, global, PO-editable) ·
`audit_log`

**Core finance**
`transactions` · `accounts` · `budgets` · `goals` · `income_streams` · `recurring_items` ·
`recurring_reminders` · `reminders` · `trackers`

**Investments**
`investments` (class-specific fields in `fields jsonb`) · `demat_accounts` · `demat_ledger` ·
`price_cache`

**Assets / liabilities / misc finance**
`net_worth_entries` · `net_worth_snapshots` · `debts` (EMI/loan repayment ledger) ·
`insurance` · `trips` (jsonb sandbox — deliberately invisible to all aggregates) ·
`tracked_subscriptions`

**Commerce / lifecycle**
`plans` · `subscriptions` (Paddle, one row per tenant) · `coupons` (display-only) ·
`processed_webhooks` · `account_deletion_requests` · `storage_purge_queue` · `retention_policy`

**Category is NOT a table.** `transactions.category` is free text. Canonical lists live in
`src/lib/finance.ts` (`INCOME_CATEGORIES`, `EXPENSE_CATEGORIES`, `BUDGET_BUCKETS`,
`GOAL_CATEGORIES`). Custom categories / subcategories are tenant-scoped JSON blobs in
`tenant_settings`. The receipt scanner keeps its own hard-coded category list in the edge function.

---

## 3. Existing transaction model

Table `public.transactions`:

| Column | Type | Rule |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `tenant_id` | uuid NOT NULL | default `current_tenant_id()`, but clients **set it explicitly** (default = user's *first* membership, wrong for multi-workspace users) |
| `user_id` | uuid NOT NULL | author; FK `auth.users` — rows survive author removal |
| `type` | text | CHECK `IN ('income','expense','transfer')` |
| `amount` | numeric(14,2) | always **positive**; direction is by type + account refs, never a sign |
| `currency` | text | default `'INR'` |
| `category` | text NOT NULL | free text (see §2) |
| `description` | text NULL | user note. **Legacy** `[Mode\|accountId]` and `⟦SPLIT\|…⟧` prefixes may still appear on old rows |
| `occurred_at` | timestamptz | the ledger date; month-bucketed in the **caller's** timezone |
| `account_id` | uuid NULL | FK `accounts` `ON DELETE SET NULL`. Source account for a transfer. (Stage 3.4) |
| `payment_mode` | text NULL | UPI / Cash / Card / Net Banking / Wallet / Cheque. NULL for transfers |
| `transfer_to_account_id` | uuid NULL | FK `accounts` `ON DELETE SET NULL`. CHECK: set iff `type='transfer'` |
| `tracker_id` | uuid NULL | FK `trackers` `ON DELETE SET NULL`. Optional dimension; **NULL for the vast majority** |
| `source_recurring_id` | uuid NULL | set only by `mark_recurring_generated()` |
| `import_hash` | text NULL | dedup key for CSV import |
| `created_at` / `updated_at` | timestamptz | trigger-maintained |

**Constraints & indexes that matter for mobile:**

- `transactions_type_check`, `transactions_transfer_dest_check` (transfer must name a destination; non-transfer must not).
- Partial unique index `transactions_recurring_period_unique (source_recurring_id, occurred_at) WHERE source_recurring_id IS NOT NULL` — the *only* server-side idempotency guard on this table today.
- Partial index `transactions_tenant_tracker_idx (tenant_id, tracker_id, occurred_at DESC) WHERE tracker_id IS NOT NULL`.
- `transactions_tenant_account_idx`, plus a `(tenant_id, type, occurred_at DESC)` index (Stage 4.4).

**Write path (critical finding).** Ordinary transactions are written by **direct PostgREST**
`insert`/`update`/`delete` from `src/hooks/useTransactions.ts` — *not* through an RPC. There is
**no client-supplied mutation id and no dedup table** for user-entered transactions. The only
atomic/idempotent server write is `mark_recurring_generated(p_item_id)` and `goal_contribute` /
`budget_set_allocation`. This is the single largest gap for offline sync (see §9, R-1).

**Aggregation:** `transfer` rows are excluded from every income/expense/spend aggregate.
`dashboard_summary(p_tenant_id, p_months, p_tz)` returns per-currency monthly series, current-month
category breakdown, and lifetime counts as one JSON payload — so the client never downloads the
whole ledger.

---

## 4. Existing account model

Table `public.accounts` — `id`, `tenant_id`, `user_id`, `name`, `type` (bank/debit/credit/wallet/
cash/investment/other via client enum), `opening_balance numeric`, `opening_date`, plus display
metadata (`bank`, `branch`, `holder`, `last4`, `exp_month/year`, `color`, `icon`, `purposes[]`).

**Balances are derived, never stored.** `src/lib/accountBalances.ts`:

```
live balance = opening_balance
             + Σ income into the account
             − Σ expense from the account
             − Σ transfers out (account_id)
             + Σ transfers in (transfer_to_account_id)
```

Two equivalent paths, pinned equal by tests: `computeLiveBalances(accounts, txns)` (full ledger) and
`applyAccountDeltas(accounts, deriveAccountDeltas(txns))` (server-side per-account deltas from
`dashboard_summary`). `BalanceTxn` deliberately omits `tracker_id` — assigning a tracker
**cannot** move a balance, structurally.

Data source: `src/lib/accountsStore.ts` is now a Supabase-backed TanStack Query hook against the
`accounts` table, with a one-time `localStorage → DB` migration shim. (Web repo CLAUDE.md still
lists accounts as "pending migration" — that note is stale.)

---

## 5. Existing category model

- **No `categories` table.** `transactions.category` (and `recurring_items.category`,
  `budgets.bucket`, `goals.category`, `trackers.type`) are plain strings.
- Canonical seed lists: `src/lib/finance.ts`.
  - Expense: Food & Dining, Transport, Shopping, Healthcare, Education, Travel, Subscriptions, Utilities, Rent, Personal Care, Entertainment, Other.
  - Income: Salary, Freelance, Business, Investment, Rental, Dividend, Interest, Other.
  - Budget buckets (7): Needs, Financial Freedom, Education, Play, Long-Term Savings, Giving, Agri.
  - Goal categories: Emergency Fund, Insurance, Travel, Education, Vehicle, Home, Retirement, Gadget, Other.
- Custom categories & subcategories: tenant-scoped JSON in `tenant_settings` (Stage 3.1,
  `20260806120000_stage3_device_local_to_tenant.sql`). Shared across the workspace.
- Currency list: INR, USD, EUR, GBP, AED. FX is a **fixed table** in `src/lib/finance.ts`
  (`toINR`); income streams / recurring items carry a manual per-record rate. There is no FX feed.

**Implication for mobile:** categories are a value list + a `tenant_settings` blob, not an entity.
The Flutter app must read the same seed constants and the same `tenant_settings` key, or a mobile
row will render as an "unknown category" on the web.

---

## 6. Existing Tracker model / status

**Shipped** (`20260827120000_trackers.sql` + `20260827130000_trackers_reviewed_at.sql`, live on
`ludbntvhagefadfkhrjj`, merged to `master` 2026-09-07). ADR-0010 governs it.

Table `public.trackers`: `id`, `tenant_id`, `user_id`, `name` (1–80 chars, real name — **no "T-"
prefix stored**), `type` (`Home Construction`/`Travel`/`Wedding`/`Vehicle`/`Education`/
`Business Project`/`Event`/`Custom`), `start_date date NOT NULL` (real project start, may predate
`created_at`), `end_date date NULL`, `budget numeric(14,2) NULL` (NULL = no budget, never a fake
zero; **INR**), `currency` (default INR), `description`, `status` (`active`/`completed`/`archived`),
`completed_at`, `archived_at`, `deleted_at` (**soft delete** — first on a finance table),
`reviewed_at`, timestamps.

- Unique index on `(tenant_id, lower(btrim(name))) WHERE status='active' AND deleted_at IS NULL`.
- RLS: all 4 policies gated by `is_tenant_member(tenant_id, …) AND has_menu(tenant_id, 'trackers')`.
- The `trackers` **table is menu-gated** (paid feature: free "Roots" plan does not include it);
  `transactions.tracker_id` **column is not gated** (`menuContract.test.ts` forbids gating
  `transactions`). On a plan without the menu, tracker rows are unreadable → the badge just doesn't
  render; the transaction row is never hidden.

**Rules (BR-067…077):** zero or one tracker per transaction (no join table); assigning/removing
never moves money; a tagged row stays visible in every existing view; spend is **derived** via
`tracker_spend(p_tenant_id)` RPC (per tracker × type × currency) folded by
`src/lib/trackers.ts` (`toINR`, expenses only, inflow kept separate); nothing is ever auto-assigned;
bulk assign carries `.is("tracker_id", null)` so it is **idempotent and replayable** (good pattern
to copy for mobile); `"T-"` is display-only (`trackerDisplayLabel`).

Hooks: `useTrackers`, `useTrackerSpend`, `useTrackerTransactions` (incl. `useAssignToTracker` /
`useUnassignFromTracker`), `useMarkTrackerReviewed`.

---

## 7. Existing authentication architecture

Paths (see `docs/Authentication_Flow.md`, partly dated 2026-08-04):

1. **Tenant email + password** — `supabase.auth.signInWithPassword`. Session in `localStorage`,
   `persistSession: true`, `autoRefreshToken: true`.
2. **Tenant Google OAuth** — brokered by `@lovable.dev/cloud-auth-js`, then
   `supabase.auth.setSession(tokens)`. **Web-only; does not port to Flutter** (see R-5).
3. **Product Owner** — identifier + password *or* identifier + 16-digit secret → magic link, via
   the `po-auth` edge function. Console-only; **not needed in the mobile app**.
4. **Optional device PIN** — `src/lib/appLock.ts`, PBKDF2-SHA256 versioned record, 6-digit default.
   Per device, per user, per tab unlock. A curtain, not access control (ADR-0007). RLS is unaffected
   while "locked".

**Signup trigger** `handle_new_user()` (SECURITY DEFINER, `AFTER INSERT ON auth.users`) atomically
creates: `profiles` row, a personal `tenants` row (`"<name>'s Workspace"`), an `owner`
`tenant_members` row, and an active Free `subscriptions` row.

**The `SIGNED_IN` gotcha:** `supabase-js` fires `SIGNED_IN` on *every* session restore, not just a
real sign-in. Web works around it with a per-tab `markSignInIntent()` / `consumeSignInIntent()`
marker set immediately before any credential call. The Flutter app needs an equivalent guard if it
implements a local lock that keys off auth events.

**Password reset:** `resetPasswordForEmail(email, { redirectTo })` → `/reset-password` page →
`auth.updateUser({ password })`. On mobile this becomes a deep link.

**Known auth weaknesses (from the audit doc, mostly still open):** tokens in `localStorage`
(XSS-readable), no CSP, `po-auth` has no rate limiting, PO secret is an *alternative* not a second
factor, PO sign-ins are not audited, edge functions send `Access-Control-Allow-Origin: *`. None of
these block the mobile build; the CORS `*` actually makes edge functions callable from a native
client without change.

---

## 8. Existing tenant / RLS architecture

**Model:** membership-based multi-tenancy (ADR-0001). `tenant_members (tenant_id, user_id, role,
status, menu_overrides)`. Roles `owner > admin > viewer`. A user can belong to multiple workspaces;
`src/contexts/TenantContext.tsx` supports switching and persists the choice in
`localStorage["finroot.tenant.current"]`.

**Helper functions (all `SECURITY DEFINER`, `STABLE`):**

- `is_tenant_member(p_tenant_id, p_min_role default 'viewer')` — the row gate on every finance table.
- `current_tenant_id()` — the user's *first* active membership. Used only as a column default;
  **clients must pass `tenant_id` explicitly** on every write and filter it on every read (RLS
  returns rows for *all* the user's workspaces).
- `is_platform_admin()` — PO check.
- `has_menu(p_tenant_id, p_menu)` = `p_menu = ANY(get_effective_menus(p_tenant_id))`.
- `get_effective_menus(p_tenant_id)` = `plan.menu_set` (ceiling) − tenant deny-list ∩ member
  allow-list. Owners bypass the override layers but not the plan.
- `all_feature_menus()` — canonical menu id list; mirrored by hand in `src/lib/accessMenus.ts`
  (16 ids: dashboard, income, expenses, investments, budget, goals, reminders, calculator,
  bill-scan, import, export, insurance, net-worth, trips, trackers, billing).

**Paywall (ADR-0002):** a menu is *enforced* iff it maps 1:1 to a feature's table(s). Enforced
tables carry `has_menu(...)` in all 4 RLS policies: `investments`, `demat_accounts`, `demat_ledger`,
`insurance`, `trips`, `net_worth_entries`, `net_worth_snapshots`, `reminders`, `goals`, `budgets`,
`income_streams`, `trackers`. **`transactions` and `accounts` are never gated.** `SECURITY DEFINER`
RPCs (`goal_contribute`, `budget_set_allocation`, `tracker_spend`, `dashboard_summary`, …) re-check
membership and menu explicitly because a definer bypasses RLS.

**PO isolation:** `platform_admins` has no INSERT policy (seeded via service role). All PO data
access is through `po_*` SECURITY DEFINER RPCs that return counts / timestamps / plan breakdowns
only — never an amount, description or category.

**Storage:** tenant-scoped buckets, purge queue, `storage_object_tenant(p_name)` for path→tenant
resolution. Relevant to mobile only if it uploads attachments (receipts).

---

## 9. Required shared backend changes

Ordered by necessity. Each is a **new append-only migration**, reviewed for web compatibility
(the web app keeps its current direct-PostgREST path unchanged; the RPC is additive).

### R-1 (MUST, before M7) — Idempotent transaction mutation RPC + mutation log

**Problem:** offline capture + retry against a raw PostgREST `insert` will create duplicate
financial rows (₹500, ₹500, ₹500). React Query's own `retry`, a lost ack, or a background-sync
replay all trigger it. `import_hash` and `source_recurring_id` dedup only import and recurring.

**Proposed shape:**

```
-- new table
public.client_mutations (
  mutation_id  uuid PRIMARY KEY,          -- client-generated
  tenant_id    uuid NOT NULL,
  user_id      uuid NOT NULL DEFAULT auth.uid(),
  operation    text NOT NULL,             -- 'txn.create' | 'txn.update' | 'txn.delete'
  entity_id    uuid,                      -- resulting/target transaction id
  result       jsonb,                     -- canonical row returned on first apply
  created_at   timestamptz NOT NULL DEFAULT now()
)  -- RLS: is_tenant_member(tenant_id,'viewer') for select; writes only via the RPC

-- new RPC (SECURITY DEFINER, re-checks is_tenant_member(tenant_id,'admin'))
public.apply_transaction_mutation(p_mutation jsonb) RETURNS jsonb
```

Behaviour: look up `mutation_id`; if present, return the stored `result` unchanged (true
idempotency). Otherwise validate (`type`/transfer rules, account & tracker ownership within the
tenant), perform the insert/update/delete, record the row in `client_mutations`, return the
canonical transaction + server timestamps. Grant `EXECUTE` to `authenticated` only.

Web impact: none required — web may adopt the RPC later, or keep PostgREST. Both paths write the
same table and the same columns.

### R-2 (SHOULD) — Pull/delta read contract for sync

Realtime already broadcasts `INSERT/UPDATE/DELETE` on `transactions`, `budgets`, `goals` filtered
by `tenant_id` (`useRealtimeSync.tsx`). For a cold start / long-offline catch-up the mobile client
needs a bounded delta read. Options, cheapest first:

1. **No backend change** — page `transactions` by `occurred_at` / `updated_at` cursor over
   PostgREST (indexes exist), and call `dashboard_summary` / `budget_spend` / `tracker_spend` for
   roll-ups. Recommended for V1.
2. A `sync_snapshot(p_tenant_id, p_since timestamptz)` RPC returning changed rows across the core
   tables in one call, if (1) proves chatty. Deferred until measured.

Soft-deletes: only `trackers` has `deleted_at`. A hard `DELETE` of a transaction produces a
Realtime delete event but leaves no tombstone for an offline client — see R-6.

### R-3 (SHOULD) — "Money owed / Relationships" table

The master prompt's Relationships module (person, "you owe" / "owes you", due date, mark settled)
**has no backend today.** `debts` is an EMI/loan repayment ledger (lender, monthly, installments
jsonb); person-to-person receivables are only encoded as split metadata inside transaction
descriptions (`src/lib/splitMeta.ts`, BR-030). A new tenant-scoped `relationships` /
`relationship_entries` table is needed, or the mobile module is cut from V1. **Decision required.**

### R-4 (CONSIDER) — Net-worth history

`net_worth_snapshots` exists (Stage 2). Web's sparkline historically ran on a **synthetic seed**
(BR-052); confirm the snapshot table is now the real source before mobile shows a trend. Mobile
should read `net_worth_snapshots` only and never fabricate a curve.

### R-5 (MUST if Google sign-in is in scope) — Native OAuth

Web's Google path is Lovable-SDK-brokered. Mobile must use `supabase_flutter`
`signInWithOAuth(OAuthProvider.google, redirectTo: <app deep link>)` with a registered redirect URL
in the Supabase Auth settings + platform intent filters / associated domains. If Google is
out-of-scope for V1, email+password + reset deep link is sufficient and needs no backend change.

### R-6 (CONSIDER) — Deletion tombstones

If a transaction is deleted on the web while mobile is offline, mobile currently only learns via a
live Realtime event it may miss. A lightweight `deleted_rows (tenant_id, entity, id, deleted_at)`
table populated by triggers would let the pull in R-2 reconcile deletions. Low priority for V1
(realtime + periodic full refetch of the recent window covers it).

### Not required

- Categories, budgets, goals, recurring, trackers, accounts, investments, reminders, insurance:
  the existing tables + RPCs are client-agnostic and enforced by RLS. No change.
- Edge functions (`scan-receipt`, `live-price`): callable from Flutter as-is (bearer token + JSON;
  CORS is `*`). `scan-receipt` wants `{ images: [{data,mimeType}], tenant_id }` and returns
  structured line items.

---

## 10. Mobile architecture proposal

**Framework:** Flutter (stable), Dart 3, Material 3. Android + iOS, phone + tablet in one codebase.

**State management:** Riverpod (recommended) — testable, no `BuildContext` coupling, good async
primitives. The prior scaffold used a single `ChangeNotifier`; do not run both. Decision to confirm
in M2.

**Layers**

```
lib/
  app/                 MaterialApp, router, theme wiring
  core/
    config/            env (--dart-define), flavors, feature flags
    supabase/          client factory (URL + anon key + SecureStore session)
    money/             Decimal money type, toINR, fold helpers  ← audited Dart re-impl, golden-tested
    errors/            failure types, user-facing messages
    result/            Result<T> / typed errors
  data/
    db/                Drift schema + DAOs (local cache + outbox)
    remote/            PostgREST + RPC gateways, edge-function clients
    sync/              outbox worker, pull/cursor, realtime bridge, backoff
    repositories/      TransactionRepository, AccountRepository, TrackerRepository, ...
  domain/
    models/            Transaction, Account, Tracker, Budget, Goal, ...  (mirror types.ts)
    (no business logic that the server owns)
  features/
    home/ transactions/ quick_add/ accounts/ trackers/ budget/ goals/
    investments/ net_worth/ relationships/ recurring/ reminders/
    bill_scan/ voice/ ai/ search/ settings/ onboarding/
  navigation/          bottom nav, tablet rail, route guards (menu gate)
  widgets/             design-system components (see §55 of the brief)
```

**Money.** Use a `Decimal` type (package `decimal`) end-to-end — never `double` — because the DB is
`numeric(14,2)`. The server stays the source of truth for every roll-up: call `dashboard_summary`,
`budget_spend`, `tracker_spend`, `goal_contribute`, `mark_recurring_generated`. The **only** Dart
re-implementations of money rules are the small, pinned ones needed to render *cached/optimistic*
data offline: `toINR` (the fixed FX table from `finance.ts`), the account-balance fold
(`accountBalances.ts`), and the tracker spend fold. Each gets a golden test that compares its output
to the RPC result on a fixture, so drift fails CI. This is the Flutter-specific answer to ADR-0008
(see R-2 of §19).

**Auth.** `supabase_flutter` with an `expo-secure-store`-equivalent (`flutter_secure_storage`)
session store. Email+password + reset deep link for V1. `is_tenant_member` / `get_effective_menus`
drive an in-app **menu gate** identical in spirit to web's `<MenuGuard>`.

**Tenancy.** Fetch memberships on sign-in, keep a selected `tenantId` in secure storage, pass it
explicitly on every write, filter it on every read — exactly as `TenantContext` + the hooks do.

---

## 11. Tablet architecture proposal

Same Flutter app, no separate codebase, no separate business logic. Adaptive layout keyed off
`MediaQuery` size class:

- **Compact (< 600 dp):** phone UI — bottom navigation, full-screen flows, bottom sheets.
- **Medium (600–840 dp):** large phone / small tablet — bottom nav retained, wider content, 2-col
  lists where useful.
- **Expanded (≥ 840 dp):** `NavigationRail` + list/detail **split view** (transactions list |
  transaction detail; trackers list | tracker detail; accounts | account ledger). Quick Add becomes
  a modal dialog rather than a full sheet.

Tablet stays touch-first: same 44–48 dp targets, same components, same information hierarchy — just
more of it visible at once. It is explicitly *not* the web dashboard (ADR-0011: "a tablet is a
responsive layout inside the mobile app, not a third target").

---

## 12. Offline storage proposal

**Engine:** Drift (SQLite) — typed, migratable, testable, good Flutter support. (`sqflite` is the
lower-level fallback the prior scaffold used.)

**What is cached (a bounded working set, not the whole account):**

| Cached fully | Cached as recent window | Not cached |
|---|---|---|
| accounts, trackers (active + recent), budgets (current period), goals, categories/`tenant_settings`, recurring_items | transactions (last ~90 days or N=500, whichever larger) | investments detail, insurance, PO data, audit log, full history |

**Tables:** mirror the subset above (snake_case columns matching `types.ts`) + two control tables:

```
sync_outbox(
  mutation_id TEXT PK, entity TEXT, operation TEXT, payload TEXT/json,
  state TEXT CHECK(state IN ('pending','syncing','synced','failed')),
  attempts INT, last_error TEXT, created_at, updated_at)

sync_cursor(entity TEXT PK, last_pulled_at TEXT, last_full_refresh_at TEXT)
```

**Encryption:** SQLCipher (`drift` + `sqlcipher_flutter_libs`) with the key in
`flutter_secure_storage` (Keychain / Keystore). Purge the DB on confirmed sign-out. Exclude from
iOS/Android auto-backup.

**Never logged:** amounts, account ids, descriptions, tokens, RPC payloads, raw server exceptions.

---

## 13. Sync architecture proposal

**Outbox / pull hybrid.**

**Write (push):**
1. Validate → generate `mutation_id` (uuid v4) → write cache row optimistically (`state=pending`)
   → update UI immediately (Doherty).
2. Attempt `apply_transaction_mutation(payload)` (R-1). On success: reconcile the canonical row +
   server timestamps back into the cache, `state=synced`. On network failure: leave `pending`.
   On validation failure (4xx): `state=failed`, surface a specific message + Retry/Discard.
3. A background worker (`workmanager` / `flutter_background_service`) drains `pending` with
   exponential backoff (e.g. 2s → 4s → … cap 5m), network-constrained, auth-refresh-aware.
   Idempotency (R-1) makes replay safe.

**Read (pull):**
1. On foreground / pull-to-refresh: for each cached entity, PostgREST query `updated_at >
   sync_cursor.last_pulled_at` (bounded), upsert into cache, advance cursor.
2. Roll-ups (`dashboard_summary`, `budget_spend`, `tracker_spend`) fetched fresh on the Home /
   Budget / Tracker screens and cached with a short TTL.
3. Realtime channel `realtime:tenant:<id>` on `transactions`/`budgets`/`goals` invalidates the
   relevant cache slices and (for another member's change) shows a "Workspace updated" toast —
   mirroring `useRealtimeSync`.

**Conflict policy (V1):** server wins. If a pending local update targets a row the pull found
newer, keep the server row and mark the local mutation `failed` with "changed elsewhere — review".
No field-level merge in V1. `transactions.tracker_id` bulk assigns already use the replay-safe
`.is('tracker_id', null)` guard — reuse that idiom.

**Duplicate-prevention test matrix:** offline create → kill app → relaunch → sync once; create →
airplane mode toggle mid-request; double-tap Save; 3× worker retry after a dropped ack. All must
yield exactly one server row.

---

## 14. Mobile navigation proposal

Bottom navigation, 5 slots (brief §5):

```
[ Home ]  [ Transactions ]  [  +  ]  [ Trackers ]  [ More ]
```

- **`+`** is the primary action (brief §7–8): opens a bottom sheet → Expense / Income / Transfer /
  Scan Bill / Voice. Expense is the fast path (amount-first, numeric keypad, chips).
- **More** is a scrollable list, not a tab bar: Accounts, Budget, Goals, Investments, Net Worth,
  Money Owed, Recurring, Reminders, Bill Scan, Voice, AI Insights, Search, Settings — each gated by
  `get_effective_menus` where the web equivalent is (`investments`, `budget`, `goals`, `net-worth`,
  `reminders`, `trackers`, `bill-scan`, `insurance`; `transactions`/`accounts` always on).
- Menu-locked items show an upsell only when the lock is a **plan** lock (mirror
  `src/lib/menuUpsell.ts`), never when an owner switched the menu off.

Route guard: unauthenticated → auth flow; authenticated but no membership → "no workspace" state;
menu-denied → locked screen (not a crash, not a raw uuid).

---

## 15. Tablet navigation proposal

- `NavigationRail` replaces the bottom bar at ≥ 840 dp: Home, Transactions, Trackers, Accounts,
  Budget, Goals, More. `+` becomes a prominent FAB / rail action opening a centered dialog.
- List/detail panes: selecting a transaction, tracker, or account fills the right pane instead of
  pushing a route. Back navigation collapses the pane.
- The workspace switcher and profile move to a rail footer menu.
- No persistent multi-column "dashboard grid" — Home stays a single scrollable feed, just wider.

---

## 16. Mobile feature scope (V1)

Mapped to backend readiness (brief §45):

| Module | Backend | V1 |
|---|---|---|
| Home feed | `dashboard_summary`, cached balances, `tracker_spend`, recurring due list | ✅ |
| Quick Add: Expense / Income / Transfer | **R-1 RPC** (new) | ✅ (gated on R-1) |
| Transactions list / detail / edit / delete | `transactions` + R-1 | ✅ |
| Search + filters (bottom sheet) | PostgREST queries | ✅ |
| Accounts + account ledger | `accounts`, derived balances | ✅ |
| Categories (value lists + `tenant_settings`) | existing | ✅ read; custom-category create = ✅ |
| Trackers (list, create, detail, assign, budget, complete/archive) | `trackers`, `tracker_spend`, tracker txn hooks | ✅ (menu-gated) |
| Budget overview + progress + alerts | `budgets`, `budget_set_allocation`, `budget_spend` | ✅ (simplified vs web planner) |
| Goals + contribute | `goals`, `goal_contribute` | ✅ |
| Recurring (upcoming, mark paid/received, skip/pause) | `recurring_items`, `mark_recurring_generated` | ✅ |
| Reminders / notifications | `reminders`, `recurring_reminders`, `notifications` (bell polls 60s) | ✅ read + local notifications |
| Money Owed / Relationships | **none — needs R-3** | ⚠️ deferred unless R-3 approved |
| Investments (basic: portfolio value, invested, returns, class split) | `investments`, `demat_*`, `live-price` edge fn | ✅ read-only, lightweight |
| Net Worth (basic snapshot) | `net_worth_snapshots` (verify R-4) | ✅ read-only |
| Bill Scan / OCR | `scan-receipt` edge fn (Gemini) → editable draft → R-1 | ✅ |
| Voice-to-ledger | new: on-device STT + parser → draft → R-1 | ✅ (confirmation required, brief §23/51) |
| AI Insights | no edge fn today — client-side heuristics over cached data for V1 | ✅ minimal, read-only |
| Offline sync | Drift + outbox + R-1 | ✅ |
| Settings + app lock (PIN/biometric) | `flutter_secure_storage`, `local_auth` | ✅ |
| Onboarding (mobile-native, short) | `profiles.onboarding_*`; reuse selection step | ✅ |

**Explicitly out of V1:** PO console, Paddle checkout / plan upgrade UI (link out to web),
Import/Export, Insurance, Trips, advanced budget planner, advanced investment analytics,
member/invitation management (link out to web `WorkspaceManage`).

---

## 17. Tablet feature scope

Everything in §16, plus, using the extra space:

- Transactions: list + detail side by side; inline edit; multi-select bulk tracker-assign.
- Trackers: list + detail + category/account breakdown + the historical-review flow in one view.
- Budget: all 7 buckets with progress bars visible at once; period switcher.
- Accounts: account list + selected account's full ledger and income/expense/transfer tabs.
- Net worth: assets and liabilities lists expanded rather than behind "View assets".

Still no admin, no PO, no import/export authoring — those stay web.

---

## 18. Web vs Mobile vs Tablet responsibility matrix

| Capability | Web | Mobile | Tablet |
|---|:--:|:--:|:--:|
| Daily capture (expense/income/transfer) | ✅ | ✅ **primary** | ✅ |
| Bill scan (camera) | ⚠️ upload | ✅ **primary** | ✅ |
| Voice capture | ✖ | ✅ **primary** | ✅ |
| Transactions browse / edit / delete | ✅ | ✅ | ✅ |
| Trackers: use & assign | ✅ | ✅ | ✅ |
| Trackers: bulk historical review | ✅ | basic | ✅ |
| Budget awareness | ✅ | ✅ | ✅ |
| Budget planner (advanced) | ✅ **primary** | ✖ | read |
| Goals track & contribute | ✅ | ✅ | ✅ |
| Investments overview | ✅ | basic read | read+ |
| Investments deep analytics | ✅ **primary** | ✖ | ✖ |
| Net worth snapshot | ✅ | ✅ basic | ✅ |
| Money owed / relationships | ⚠️ split-meta only | ⚠️ pending R-3 | ⚠️ pending R-3 |
| Recurring & reminders | ✅ | ✅ | ✅ |
| Notifications | poll | ✅ push/local | ✅ |
| Import / Export | ✅ **only** | ✖ (link out) | ✖ |
| Insurance / Trips | ✅ **only** | ✖ | ✖ |
| Member & permission management | ✅ **only** | link out | link out |
| Plan upgrade / billing | ✅ **only** | link out | link out |
| Product Owner console | ✅ **only** | ✖ | ✖ |
| Offline use | ✖ (PWA-lite) | ✅ **primary** | ✅ |

Shared and identical across all three: Supabase project, database, auth, RLS, tenant model, money
math (server RPCs), category value lists.

---

## 19. Risks

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| **R-1** | No idempotent write path for user transactions → offline retry creates duplicate financial rows. | **Critical** | Ship the `apply_transaction_mutation` RPC + `client_mutations` table (§9 R-1) **before M7**. Test matrix in §13. |
| **R-2** | ADR-0011 assumes **Expo/React Native** so `@finroot/core` money logic is shared as TS. Flutter cannot import it → risk of two drifting implementations of `toINR` / balances / folds (violates ADR-0008). | High | Server RPCs are the source of truth for roll-ups. The 3 unavoidable Dart re-impls are golden-tested against RPC fixtures in CI. **Get explicit sign-off that Flutter supersedes ADR-0011's Expo recommendation** and update/replace ADR-0011. |
| **R-3** | Lovable owns the web editing pipeline. Backend migrations and `types.ts` regen must be coordinated; "never edit a migration" is absolute. | High | All backend changes are additive append-only migrations, reviewed for web no-op. Coordinate every `supabase/migrations` change with the web/Lovable owner. Mobile never touches web source. |
| **R-4** | Balances, dashboard, budget spend, tracker spend, net worth are **derived**. Fully offline, the app cannot authoritatively compute a *new* balance without the complete ledger. | Medium | Cache a bounded recent window + last server roll-up; label offline figures as "as of last sync"; recompute deltas locally only for the cached window; reconcile on pull. |
| **R-5** | Google OAuth is Lovable-SDK, web-only. | Medium | Use native `supabase_flutter` OAuth + deep link (R-5 in §9), or ship email+password only for V1. Decision needed. |
| **R-6** | "Money Owed / Relationships" has no backend entity (only `debts` EMI ledger + description split-meta). | Medium | Approve `relationships` tables (§9 R-3) or cut the module from V1. Decision needed. |
| **R-7** | Categories are free text + a `tenant_settings` JSON blob. A mobile-created category string that doesn't match the web's list renders as "unknown" on web. | Medium | Read the same `src/lib/finance.ts` constants (port as a generated Dart constants file) and the same `tenant_settings` key; validate against the shared list on write. |
| **R-8** | RLS returns rows for **every** workspace the user belongs to. Forgetting the client-side `tenant_id` filter leaks/mixes workspaces. | Medium | Repository layer always applies `.eq('tenant_id', currentTenantId)` on reads and sets it on writes. Lint/review rule. |
| **R-9** | `numeric(14,2)` money vs Dart `double`. | Medium | `Decimal` everywhere; never parse money as `double`; serialize as string. |
| **R-10** | Net-worth trend was historically synthetic (BR-052). | Low | Verify `net_worth_snapshots` is real (R-4); show snapshot points only, never an interpolated curve. |
| **R-11** | Free-tier Supabase limits (auth mailer rate limits during testing, Realtime connection caps, edge-function quotas). | Low | Mobile e2e uses its own seeded account (ADR-0011 note); don't hammer the auth mailer; a single Realtime channel per tenant. |
| **R-12** | Device PIN / biometric is not access control (ADR-0007); RLS stays the gate. | Low | Say so in any UI that mentions the lock; never gate data on it. Port the `markSignInIntent` guard if the lock keys off auth events. |
| **R-13** | Web `Business_Rules.md` is dated 2026-08-04 and partly stale (transfer type, workspace switching, migrated stores). | Low | Trust `types.ts` + latest migrations + hooks over the older prose docs. This audit already reconciled the main deltas. |
| **R-14** | Stage 1 security items still open on the backend (`po-auth` no rate limit, no CSP, CORS `*`). | Low (for mobile) | Out of mobile scope; note them so mobile doesn't depend on the current lax CORS as a feature. |

---

## 20. Implementation sequence

Each phase: inspect → state changes → implement that phase only → run `dart format` + `flutter
analyze` + `flutter test` → check for regressions → report files/tests → **STOP for approval**
(brief §60).

| Phase | Content | Backend dependency | Gate before starting |
|---|---|---|---|
| **M1** | This audit. | — | — |
| **M1.5** | **Backend: `apply_transaction_mutation` RPC + `client_mutations` (R-1); decide R-3 (relationships) and R-5 (OAuth).** Migration reviewed for web no-op; `types.ts` regenerated. | writes `supabase/migrations` | M1 approved + web/Lovable owner sign-off |
| **M2** | Flutter project in `F:\Movie\AK\Finroot App`; structure, Material 3 theme + tokens, router, env/flavors, Riverpod, error handling, logging (redacted). | — | M1 approved |
| **M3** | Auth: email+password sign-in/up, session in secure storage, sign-out, reset deep link. Membership fetch + tenant selection + menu gate. | existing | M2 |
| **M4** | Drift schema (cached subset + `sync_outbox` + `sync_cursor`), SQLCipher, migrations. | existing | M3 |
| **M5** | Sync engine: outbox worker + backoff, pull-by-cursor, Realtime bridge, idempotent push via M1.5 RPC. Duplicate-prevention test matrix. | **M1.5** | M4 |
| **M6** | Bottom nav + tablet rail scaffold, Home feed, More list, menu-gated routing. Establishes the mobile design language. | `dashboard_summary` | M5 |
| **M7** | Quick Add: Expense / Income / Transfer — amount-first, chips, smart defaults, ≤ 10 s. | **M1.5 RPC** | M6 |
| **M8** | Transactions list (grouped Today/Yesterday/…), detail sheet, edit, delete, swipe actions + accessible alternatives, search, filter bottom sheet. Accounts + account ledger. | existing | M7 |
| **M9** | Trackers: list, create, edit, detail, tracker transactions, tracker budget, category/account breakdown, complete/archive, historical review (idempotent bulk assign). | `tracker_spend` | M8 |
| **M10** | Budget overview + progress + alerts; Goals + progress + contribute. | `budget_spend`, `goal_contribute` | M9 |
| **M11** | Investments (basic read) + Net Worth (snapshot read). | `live-price`, `net_worth_snapshots` | M10 |
| **M12** | Relationships (**iff R-3 approved**), Recurring, Reminders, notifications + local scheduling. | `mark_recurring_generated`, R-3 | M11 |
| **M13** | Bill Scan: camera → `scan-receipt` → editable draft → confirm → M1.5 RPC. | `scan-receipt` edge fn | M12 |
| **M14** | Voice-to-ledger: on-device STT → parser → draft with per-field confidence → confirm (never silent) → M1.5 RPC. | existing | M13 |
| **M15** | AI Insights: client-side heuristics over cached data (spend anomalies, tracker/budget warnings, upcoming recurring). Read-only. | existing | M14 |
| **M16** | Tablet adaptive layer: rail, split views, multi-column, dialog Quick Add. | — | M15 |
| **M17** | Accessibility + UX audit against the brief's 15 laws + WCAG 2.2 AA; fix. | — | M16 |
| **M18** | Security + performance audit: RLS/tenant checks, token storage, log redaction, cache encryption, cold-start, scroll, battery, network. | — | M17 |
| **M19** | Full test pass: unit, widget, integration, sync, offline, regression; Android + iOS phone + tablet, portrait/landscape. | — | M18 |
| **M20** | Release prep: Android + iOS builds, icons, splash, store metadata, prod env, crash reporting, release checklist. | — | M19 |

**Rough estimate to a mobile vertical slice on real data (auth + sync + Quick Add + transactions):**
M1.5–M8, ~4–6 focused weeks, one developer, prior phases green — consistent with ADR-0011's own
estimate.

---

## Appendix A — Key file references (web repo)

- Schema of record: `src/integrations/supabase/types.ts` (generated from `ludbntvhagefadfkhrjj`).
- Transactions: `src/hooks/useTransactions.ts`, `src/hooks/useTrackerTransactions.ts`.
- Balances (pure): `src/lib/accountBalances.ts` (+ `.test.ts` — the money invariant).
- Money / FX / category lists: `src/lib/finance.ts`.
- Trackers (pure): `src/lib/trackers.ts`; migration `supabase/migrations/20260827120000_trackers.sql`.
- Tenancy: `supabase/migrations/20260604120000_phase1_tenancy_foundation.sql`; `src/contexts/TenantContext.tsx`.
- Menu contract: `src/lib/accessMenus.ts`; `all_feature_menus()` / `get_effective_menus()` / `has_menu()`.
- Dashboard roll-up: `supabase/migrations/20260810130000_stage4_dashboard_summary.sql`.
- Recurring atomic write: `supabase/migrations/20260817120000_bug104_recurring_mark_atomic.sql`.
- Realtime: `src/hooks/useRealtimeSync.tsx`.
- Receipt OCR: `supabase/functions/scan-receipt/index.ts`.
- Auth: `src/hooks/useAuth.tsx`, `docs/Authentication_Flow.md`, `src/lib/appLock.ts`.
- Prior (blind) Flutter attempt for reference only: `F:\Movie\AK\FinRoot Mobile APp\` + its `docs/MOBILE_ARCHITECTURE.md`.

## Appendix B — Decisions required before M2

1. **Approve Flutter over ADR-0011's Expo recommendation** (R-2) and agree to update ADR-0011.
2. **Approve the M1.5 backend migration** (`apply_transaction_mutation` + `client_mutations`) and
   name the reviewer for web compatibility (R-1, R-3).
3. **Money Owed / Relationships:** build the `relationships` tables in M1.5, or cut the module from
   V1 (R-6).
4. **Google sign-in:** in scope for V1 (native OAuth + deep link) or email+password only (R-5)?
5. **State management:** confirm Riverpod.
6. Confirm the mobile app builds in `F:\Movie\AK\Finroot App` as a standalone repo (not folded into
   the web monorepo now).
