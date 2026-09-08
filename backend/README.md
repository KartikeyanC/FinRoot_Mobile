# backend/ — proposed shared-backend changes

The FinRoot mobile app shares the web app's Supabase project
(`ludbntvhagefadfkhrjj`). This project has **no `supabase/` directory of its
own** — it is a client only. When the mobile app needs a backend change, it is
authored here as a reviewable package and handed to the web repo
(`KartikeyanC/finboom-galaxy`) owner, who reviews it, drops the `.sql` into
`supabase/migrations/`, applies it, and regenerates `types.ts`.

Nothing in this folder is applied automatically. It is not wired into any
mobile build step.

## M1.5 — idempotent transaction writes (status: awaiting review)

| File | Purpose |
|---|---|
| `20260909120000_m1_5_client_mutation_ledger.sql` | the proposed migration — additive only (1 table, 1 function) |
| `M1.5_WEB_IMPACT.md` | the impact analysis to review before applying; how to apply; rollback |
| `M1.5_CLIENT_CONTRACT.md` | the envelope the mobile sync engine (M5) will send — reference, not yet built |

**Why:** the mobile app retries queued writes after going offline; a raw insert
would duplicate a transaction whose first attempt succeeded but whose response
was lost. The migration adds an idempotency-key ledger + a `SECURITY DEFINER`
RPC, using patterns already in the codebase (`import_hash`, `goal_contribute`).
The web app is unaffected — it keeps its raw insert and never calls the RPC.
