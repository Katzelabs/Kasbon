-- =============================================================================
-- KASBON POS - Row Level Security
-- =============================================================================
-- The whole tenant boundary for the six public tables, in one file. 23 policies,
-- four per table except user_profiles, which has three.
--
-- Two properties every one of them has, both of which were retrofitted onto an
-- earlier version of this schema and are stated directly here instead:
--
-- **`TO authenticated`.** Created without a role clause, a policy means
-- `TO public`, so it is also evaluated for `anon` - on a project where
-- authentication is mandatory and an anonymous caller can never match. Naming
-- the role lets the planner skip the policy for anon rather than evaluate a
-- predicate that cannot be true. `security_invariants.sql` check 4 asserts this
-- structurally, so it fails for a policy nobody has written yet.
--
-- Note it is `TO authenticated` *plus* an ownership predicate. `TO authenticated`
-- on its own is authentication without authorisation - it checks the role and
-- says nothing about which rows.
--
-- **`(SELECT auth.uid())`** rather than a bare `auth.uid()`. This is the
-- widely-repeated Supabase tuning tip, and on this schema it measured as a wash:
-- 27.623 ms bare against 25.099 ms wrapped over a 100k-row scan, 30 calls each,
-- which is inside this machine's noise. The advice assumes the function is
-- re-evaluated per row; auth.uid() is STABLE and the plans already showed it
-- folded into the index condition:
--
--   Bitmap Index Scan on idx_transactions_user
--     Index Cond: (user_id = (COALESCE(NULLIF(current_setting(...
--
-- It is written this way anyway because it is free, it is what every Supabase
-- linter expects, and it makes the behaviour explicit rather than dependent on
-- the planner continuing to inline a STABLE function. Recorded as tidiness, not
-- as a speedup, so nobody measures it later and concludes this file did nothing.
--
-- UPDATE carries both USING and WITH CHECK throughout. Without WITH CHECK a user
-- can reassign a row's user_id to somebody else, and Postgres falling back to
-- USING is a rule a reader should not have to know to be sure the policy is
-- right.
--
-- Column-level restrictions are NOT expressible here - Postgres RLS scopes rows,
-- not columns - which is why user_profiles.tier needs the trigger in 010005.
-- =============================================================================

ALTER TABLE public.user_profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- user_profiles - keyed on its own primary key, not on a user_id column
-- ---------------------------------------------------------------------------
-- No DELETE policy, deliberately. A user does not delete their profile row on
-- its own; account deletion removes the `auth.users` row and this goes with it
-- through ON DELETE CASCADE (see 010010).

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  TO authenticated
  USING (id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- shop_settings
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own shop settings"
  ON public.shop_settings FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own shop settings"
  ON public.shop_settings FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own shop settings"
  ON public.shop_settings FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete own shop settings"
  ON public.shop_settings FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own categories"
  ON public.categories FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own categories"
  ON public.categories FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own categories"
  ON public.categories FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete own categories"
  ON public.categories FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own products"
  ON public.products FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own products"
  ON public.products FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own products"
  ON public.products FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete own products"
  ON public.products FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own transactions"
  ON public.transactions FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own transactions"
  ON public.transactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own transactions"
  ON public.transactions FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete own transactions"
  ON public.transactions FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- transaction_items
-- ---------------------------------------------------------------------------
-- Scoped on the item's own user_id rather than through a join to its
-- transaction. Denormalised on purpose: a policy that joined would be evaluated
-- per row on the largest table in the schema.

CREATE POLICY "Users can view own transaction items"
  ON public.transaction_items FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert own transaction items"
  ON public.transaction_items FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own transaction items"
  ON public.transaction_items FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete own transaction items"
  ON public.transaction_items FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));
