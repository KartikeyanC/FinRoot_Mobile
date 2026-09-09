-- ===========================================================================
-- M1.5 — idempotent transaction writes for the mobile client
--
--   PROPOSED migration for the FinRoot web repo (KartikeyanC/finboom-galaxy),
--   supabase/migrations/. NOT YET APPLIED. Review backend/M1.5_WEB_IMPACT.md
--   before applying. Authored by the FinRoot Mobile build (M1 audit §9, R-1).
--
--   REV 2 (2026-09-09, during M5): `create_transaction` now accepts an optional
--   client-supplied `transaction_id` and inserts the row with it, so a row
--   created offline keeps the same id locally and on the server (no re-keying).
--   Still additive; still no web impact — the web omits it and the column
--   default fires exactly as before.
--
-- ---- Why -----------------------------------------------------------------
--
-- The web app writes a transaction with a raw PostgREST insert
-- (src/hooks/useTransactions.ts → .from('transactions').insert(...)). That is
-- correct for an always-online client. The mobile client is offline-first: a
-- create is queued locally and retried by a background worker after the
-- network returns, an app restart, or an OS-scheduled wake. Any of those can
-- resend a create whose first attempt actually succeeded (the response was
-- lost, not the write). With a raw insert that produces a SECOND real
-- transaction — duplicated money, silently — exactly the failure BUG-017
-- (import de-dup) and BUG-104 (recurring double-post) already fixed for their
-- own paths.
--
-- This adds the same protection for the mobile write path, reusing patterns
-- this codebase already established:
--   * a client-supplied idempotency key (like transactions.import_hash), and
--   * a SECURITY DEFINER RPC with an explicit membership check and a lock
--     (like goal_contribute / budget_set_allocation / mark_recurring_generated).
--
-- ---- What it does -------------------------------------------------------
--
--   1. public.client_mutations   — a tiny idempotency-key ledger. IDS AND
--                                   TIMESTAMPS ONLY, no transaction content —
--                                   the same "carries no identity" shape as
--                                   processed_webhooks.
--   2. public.apply_transaction_mutation(jsonb)
--                                 — create / update / delete a transaction,
--                                   idempotently. A replay of a mutation_id
--                                   re-reads and returns the current row, and
--                                   writes nothing.
--
-- ---- What it deliberately does NOT do ----------------------------------
--
--   * No change to the transactions table — no column, constraint, policy,
--     trigger or index.
--   * No change to any existing function, RLS policy, grant or trigger.
--   * No change to how the WEB app writes. useTransactions.ts keeps its raw
--     insert and is completely unaffected. The web never calls the new RPC.
--   * No DELETE or UPDATE of existing data. No backfill.
--   * transactions-only. Accounts / trackers / budgets / goals keep their
--     existing write paths.
--
-- ---- The one web-side follow-up (see M1.5_WEB_IMPACT.md §4) -------------
--
-- After `supabase gen types`, add ONE line to src/lib/dataExport.ts →
-- NOT_PERSONAL for `client_mutations` (it is an internal technical ledger with
-- no personal data — ids only). Without it `dataExport.test.ts` fails, the
-- same forced-decision the trackers migration triggered.
-- ===========================================================================

-- ---- 1. the idempotency-key ledger -----------------------------------

CREATE TABLE public.client_mutations (
  -- Client-generated (UUID v4). The primary key IS the idempotency guarantee:
  -- a second call with the same id can never insert a second row here, so the
  -- RPC returns the current state instead of re-doing the write.
  mutation_id  uuid PRIMARY KEY,

  tenant_id    uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

  -- Nullable + ON DELETE SET NULL, matching trackers.user_id.
  user_id      uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  operation    text NOT NULL CHECK (operation IN (
                 'create_transaction','update_transaction','delete_transaction')),

  -- Forward room for accounts / trackers later; 'transaction' for now.
  entity       text NOT NULL DEFAULT 'transaction',

  -- The affected transaction's id. NULL only when a delete targeted a row that
  -- was already gone. NO amount / category / description is stored here — on a
  -- replay the RPC re-reads the live row by this id.
  entity_id    uuid,

  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.client_mutations ENABLE ROW LEVEL SECURITY;

CREATE INDEX client_mutations_tenant_created_idx
  ON public.client_mutations (tenant_id, created_at DESC);

-- Members may READ their own workspace's ledger (support / debugging). There
-- is deliberately NO insert/update/delete policy and NO write grant below —
-- only apply_transaction_mutation(), as SECURITY DEFINER, writes here.
CREATE POLICY cm_select ON public.client_mutations FOR SELECT
  USING (public.is_tenant_member(tenant_id, 'viewer'));

-- Explicit grants are required — 20260805120000_stage1b_grant_hardening.sql
-- and the trackers migration both make this point. SELECT only for end users.
REVOKE ALL ON public.client_mutations FROM anon, authenticated;
GRANT SELECT ON public.client_mutations TO authenticated;
GRANT ALL    ON public.client_mutations TO service_role;

COMMENT ON TABLE public.client_mutations IS
  'M1.5. One row per applied mobile transaction mutation, keyed by the client '
  'mutation_id, for offline-retry de-duplication. Ids and timestamps only — no '
  'transaction content, no personal data. Written only by '
  'apply_transaction_mutation(). Safe to prune rows older than ~90 days.';

-- ---- 2. the idempotent RPC ------------------------------------------------
--
-- Shape mirrors the codebase's other definer RPCs: parse → explicit membership
-- check (a definer bypasses RLS, so the tx_* policy gate is restated here as
-- is_tenant_member(tenant, 'admin')) → lock → act → record the key.
--
-- ENVELOPE (jsonb):
--   {
--     "mutation_id":     "<uuid>",                       -- required, unique per mutation
--     "operation":       "create_transaction"
--                      | "update_transaction"
--                      | "delete_transaction",           -- required
--     "tenant_id":       "<uuid>",                        -- required, the active workspace
--     "transaction_id":  "<uuid>",                        -- update/delete: the row's id.
--                                                         -- create: the client's own id for
--                                                         -- the new row (offline-first — the
--                                                         -- local and server ids match from
--                                                         -- birth, no re-keying). Omit to let
--                                                         -- the server generate one.
--     "payload": {                                        -- required for create / update
--       "type":                    "income|expense|transfer",
--       "amount":                  "18600.00",            -- string or number, numeric(14,2)
--       "currency":                "INR",
--       "category":                "Labour",
--       "description":             "Labour salary" | null,
--       "occurred_at":             "2026-09-08T10:30:00Z",
--       "account_id":              "<uuid>" | null,
--       "payment_mode":            "UPI" | null,
--       "transfer_to_account_id":  "<uuid>" | null,       -- required iff type = transfer
--       "tracker_id":              "<uuid>" | null        -- optional label; never moves money
--     }
--   }
--
-- update_transaction carries the COMPLETE desired row (the mobile client holds
-- it locally), not a partial patch — so replay and last-write-wins are
-- unambiguous.
--
-- RETURNS (jsonb):
--   { "status": "applied" | "replayed",
--     "operation": "...",
--     "transaction": <row as json> | null,
--     "deleted": bool }

CREATE OR REPLACE FUNCTION public.apply_transaction_mutation(p_mutation jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mid          uuid;
  v_op           text;
  v_tenant       uuid;
  v_txn_id       uuid;
  v_payload      jsonb;
  v_existing     public.client_mutations%ROWTYPE;
  v_txn          public.transactions%ROWTYPE;
  v_account      uuid;
  v_transfer_to  uuid;
  v_tracker      uuid;
  v_owner_tenant uuid;
  v_deleted      boolean := false;
BEGIN
  -- ---- 1. parse & validate the envelope --------------------------------
  v_mid     := nullif(p_mutation->>'mutation_id', '')::uuid;
  v_op      := p_mutation->>'operation';
  v_tenant  := nullif(p_mutation->>'tenant_id', '')::uuid;
  v_txn_id  := nullif(p_mutation->>'transaction_id', '')::uuid;
  v_payload := p_mutation->'payload';

  IF v_mid IS NULL THEN
    RAISE EXCEPTION 'mutation_id is required' USING errcode = '22023';
  END IF;
  IF v_op IS NULL OR v_op NOT IN
       ('create_transaction','update_transaction','delete_transaction') THEN
    RAISE EXCEPTION 'unknown operation: %', coalesce(v_op, '(null)')
      USING errcode = '22023';
  END IF;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required' USING errcode = '22023';
  END IF;
  IF v_op <> 'create_transaction' AND v_txn_id IS NULL THEN
    RAISE EXCEPTION 'transaction_id is required for %', v_op USING errcode = '22023';
  END IF;
  IF v_op <> 'delete_transaction'
     AND (v_payload IS NULL OR jsonb_typeof(v_payload) <> 'object') THEN
    RAISE EXCEPTION 'payload is required for %', v_op USING errcode = '22023';
  END IF;

  -- ---- 2. authorization — the same gate as the tx_* RLS policies -------
  -- (tx_insert / tx_update / tx_delete all require is_tenant_member(_, 'admin');
  --  a SECURITY DEFINER function bypasses RLS, so it is restated explicitly —
  --  identical reasoning to goal_contribute() and mark_recurring_generated().)
  IF NOT public.is_tenant_member(v_tenant, 'admin') THEN
    RAISE EXCEPTION 'Not authorized for this workspace' USING errcode = '42501';
  END IF;

  -- ---- 3. idempotency — serialize everyone holding this mutation_id ----
  -- A transaction-scoped advisory lock: a concurrent retry with the same id
  -- blocks here until the first call commits, then falls through to the
  -- "already recorded" branch. Auto-released on commit/rollback.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_mid::text, 0));

  SELECT * INTO v_existing FROM public.client_mutations WHERE mutation_id = v_mid;
  IF FOUND THEN
    IF v_existing.tenant_id <> v_tenant OR v_existing.operation <> v_op THEN
      RAISE EXCEPTION
        'mutation_id % was already used for a different mutation', v_mid
        USING errcode = '22023';
    END IF;

    IF v_existing.operation = 'delete_transaction' THEN
      RETURN jsonb_build_object(
        'status', 'replayed', 'operation', v_op,
        'transaction', NULL, 'deleted', true);
    END IF;

    -- Re-read the live row: returning current state on replay is more useful
    -- than a stale snapshot, and needs no stored copy.
    SELECT * INTO v_txn FROM public.transactions
      WHERE id = v_existing.entity_id AND tenant_id = v_tenant;
    RETURN jsonb_build_object(
      'status', 'replayed', 'operation', v_op,
      'transaction', CASE WHEN v_txn.id IS NULL THEN NULL ELSE to_jsonb(v_txn) END,
      'deleted', false);
  END IF;

  -- ---- 4. referenced ids must belong to this workspace ---------------
  -- Stricter than the web's raw insert, which does not verify this. It is a
  -- security improvement (a client cannot attach another workspace's account or
  -- tracker to a row) and changes nothing for the web, which never calls this.
  IF v_op <> 'delete_transaction' THEN
    v_account     := nullif(v_payload->>'account_id', '')::uuid;
    v_transfer_to := nullif(v_payload->>'transfer_to_account_id', '')::uuid;
    v_tracker     := nullif(v_payload->>'tracker_id', '')::uuid;

    IF v_account IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM public.accounts
          WHERE id = v_account AND tenant_id = v_tenant) THEN
      RAISE EXCEPTION 'account_id does not belong to this workspace'
        USING errcode = '23503';
    END IF;
    IF v_transfer_to IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM public.accounts
          WHERE id = v_transfer_to AND tenant_id = v_tenant) THEN
      RAISE EXCEPTION 'transfer_to_account_id does not belong to this workspace'
        USING errcode = '23503';
    END IF;
    IF v_tracker IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM public.trackers
          WHERE id = v_tracker AND tenant_id = v_tenant AND deleted_at IS NULL) THEN
      RAISE EXCEPTION 'tracker_id does not belong to this workspace'
        USING errcode = '23503';
    END IF;
  END IF;

  -- ---- 5. perform ---------------------------------------------------
  -- The transactions table's own CHECK constraints still fire here:
  -- transactions_type_check, transactions_transfer_dest_check,
  -- transactions_import_hash_key (import_hash stays NULL),
  -- transactions_recurring_period_unique (source_recurring_id stays NULL).
  IF v_op = 'create_transaction' THEN
    INSERT INTO public.transactions (
      id, user_id, tenant_id, type, amount, currency, category, description,
      occurred_at, account_id, payment_mode, transfer_to_account_id, tracker_id
    ) VALUES (
      -- The client's own id when it supplied one (offline-first), else a fresh
      -- one. A reused id from a *different* mutation fails the PK — correct; the
      -- replay of the *same* mutation was already handled in section 3.
      coalesce(v_txn_id, gen_random_uuid()),
      auth.uid(),
      v_tenant,
      v_payload->>'type',
      (v_payload->>'amount')::numeric,
      coalesce(nullif(v_payload->>'currency', ''), 'INR'),
      v_payload->>'category',
      nullif(v_payload->>'description', ''),
      coalesce((v_payload->>'occurred_at')::timestamptz, now()),
      v_account,
      nullif(v_payload->>'payment_mode', ''),
      v_transfer_to,
      v_tracker
    )
    RETURNING * INTO v_txn;

  ELSIF v_op = 'update_transaction' THEN
    UPDATE public.transactions SET
      type                   = v_payload->>'type',
      amount                 = (v_payload->>'amount')::numeric,
      currency               = coalesce(nullif(v_payload->>'currency', ''), 'INR'),
      category               = v_payload->>'category',
      description            = nullif(v_payload->>'description', ''),
      occurred_at            = coalesce((v_payload->>'occurred_at')::timestamptz,
                                        occurred_at),
      account_id             = v_account,
      payment_mode           = nullif(v_payload->>'payment_mode', ''),
      transfer_to_account_id = v_transfer_to,
      tracker_id             = v_tracker
    WHERE id = v_txn_id AND tenant_id = v_tenant
    RETURNING * INTO v_txn;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'no transaction % in this workspace', v_txn_id
        USING errcode = 'P0002';
    END IF;

  ELSE  -- delete_transaction
    SELECT tenant_id INTO v_owner_tenant
      FROM public.transactions WHERE id = v_txn_id;
    IF v_owner_tenant IS NOT NULL AND v_owner_tenant <> v_tenant THEN
      RAISE EXCEPTION 'no transaction % in this workspace', v_txn_id
        USING errcode = 'P0002';
    END IF;
    -- Idempotent: deleting an already-gone row is a success, not an error.
    DELETE FROM public.transactions WHERE id = v_txn_id AND tenant_id = v_tenant;
    v_deleted := true;
  END IF;

  -- ---- 6. record the key ------------------------------------------
  INSERT INTO public.client_mutations (
    mutation_id, tenant_id, user_id, operation, entity, entity_id
  ) VALUES (
    v_mid, v_tenant, auth.uid(), v_op, 'transaction',
    CASE WHEN v_op = 'delete_transaction' THEN v_txn_id ELSE v_txn.id END
  );

  RETURN jsonb_build_object(
    'status',      'applied',
    'operation',   v_op,
    'transaction',
      CASE WHEN v_op = 'delete_transaction' THEN NULL ELSE to_jsonb(v_txn) END,
    'deleted',     v_deleted
  );
END;
$$;

COMMENT ON FUNCTION public.apply_transaction_mutation(jsonb) IS
  'M1.5. Idempotent create/update/delete of one transaction for the mobile '
  'offline-sync path. Replays a known mutation_id from client_mutations without '
  're-doing the work. Explicit is_tenant_member(_, ''admin'') gate (SECURITY '
  'DEFINER bypasses the tx_* RLS policies). The web does not use this — it '
  'keeps its raw insert in useTransactions.ts.';

REVOKE ALL     ON FUNCTION public.apply_transaction_mutation(jsonb) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.apply_transaction_mutation(jsonb) TO authenticated;

-- ---- 3. fresh-apply self-check -----------------------------------------
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM pg_policies
           WHERE schemaname = 'public' AND tablename = 'client_mutations') = 1,
    'expected exactly one policy (cm_select) on client_mutations';

  ASSERT NOT EXISTS (
    SELECT 1 FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND table_name = 'client_mutations'
       AND grantee IN ('anon','authenticated')
       AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE')
  ), 'client_mutations must not be end-user writable';

  ASSERT (SELECT prosecdef FROM pg_proc
           WHERE proname = 'apply_transaction_mutation'
             AND pronamespace = 'public'::regnamespace),
    'apply_transaction_mutation must be SECURITY DEFINER';
END $$;

-- ===========================================================================
-- Post-apply verification — run as a REAL signed-in workspace admin over
-- PostgREST (rpc/apply_transaction_mutation), not the Management API.
--
--   -- 1. a create with a client-supplied id returns status=applied, and the
--   --    returned transaction.id equals the id we sent
--   select public.apply_transaction_mutation(jsonb_build_object(
--     'mutation_id',    gen_random_uuid(),
--     'operation',      'create_transaction',
--     'tenant_id',      '<your tenant>',
--     'transaction_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
--     'payload', jsonb_build_object(
--       'type','expense','amount','12.34','currency','INR',
--       'category','Other','occurred_at', now())));
--
--   -- 2. resending the SAME envelope returns status=replayed, same row,
--   --    and adds NO second transaction:
--   select count(*) from public.transactions where amount = 12.34;   -- expect 1
--   select count(*) from public.transactions
--    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';              -- expect 1
--
--   -- 3. a viewer / non-member call raises 'Not authorized for this workspace'
--
--   -- 4. an account_id from another workspace raises 23503
--
--   -- 5. the WEB app: sign in on the web, add a transaction the normal way,
--   --    confirm it still works (it never touches the new objects)
-- ===========================================================================
