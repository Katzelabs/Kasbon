-- =============================================================================
-- KASBON POS - Core schema: six tables, their indexes and their triggers
-- =============================================================================
-- Multi-tenant by `user_id` (by `id` on user_profiles), every tenant table
-- keyed off `auth.users(id) ON DELETE CASCADE`. That cascade is load-bearing
-- well beyond this file: it is what makes account deletion (010010) a single
-- `auth.admin.deleteUser()` call rather than a hand-written teardown.
--
-- Row Level Security is enabled and policed in 010004, not here, so the RLS
-- story is one file rather than two.
--
-- Columns appear in the order the tables actually acquired them, because column
-- order is part of the schema: views and `select *` depend on it, and
-- `supabase/scripts/schema-fingerprint.sh` compares it. The four payment
-- columns are last on `transactions` for that reason, not by preference.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. TRIGGER FUNCTIONS
-- ---------------------------------------------------------------------------

-- Both pin an empty search_path so an unqualified name cannot be resolved
-- against a schema someone else controls. handle_updated_at is SECURITY INVOKER
-- and touches nothing but NEW, so there is no live escalation in it; it is the
-- case Supabase's linter flags as `function_search_path_mutable`, and the
-- invariant test asserts it for every function in `public` without exception.
CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- Creates the `user_profiles` row on signup, and stops there. It deliberately
-- does NOT create `shop_settings` - `shop_settings.name` is NOT NULL and there
-- is nothing to put in it yet. The onboarding wizard collects that, gated by
-- `auth.users.raw_user_meta_data ->> 'onboarding_completed_at'` rather than by a
-- column here, because the GoRouter redirect that enforces it is synchronous.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.user_profiles (id, full_name, phone, tier)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    COALESCE(NEW.raw_user_meta_data ->> 'phone', ''),
    COALESCE(NEW.raw_user_meta_data ->> 'tier', 'free')
  );
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. TABLES (in FK dependency order)
-- ---------------------------------------------------------------------------

CREATE TABLE public.user_profiles (
  id                       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name                TEXT NOT NULL DEFAULT '',
  phone                    TEXT DEFAULT '',
  -- Entitlements, not profile fields. Not writable by their owner - see the
  -- freeze trigger in 010005, which is why this is not just a CHECK.
  tier                     TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium')),
  subscription_expires_at  TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.shop_settings (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                  TEXT NOT NULL,
  address               TEXT,
  phone                 TEXT,
  logo_url              TEXT,
  receipt_header        TEXT,
  receipt_footer        TEXT,
  currency              TEXT NOT NULL DEFAULT 'IDR',
  low_stock_threshold   INTEGER NOT NULL DEFAULT 5,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- What kind of shop this is, chosen during onboarding. Free-form TEXT rather
  -- than an enum or a CHECK: the list of Indonesian small-business types is the
  -- app's editorial judgement, so adding "Laundry" should be a Dart change, not
  -- a migration. Drives the starter category templates.
  business_type         TEXT,

  -- How long a payment proof is kept. Per shop rather than a constant, because
  -- the right answer is a business question: a warung selling snacks settles
  -- arguments within days, a shop taking large QRIS payments for furniture may
  -- want a season.
  --
  -- The lower bound is 7 rather than 0 or 1. A window short enough to delete a
  -- proof before the weekend it was taken on is a data-loss bug wearing a
  -- settings row, and nothing in the app has any business offering it.
  payment_proof_retention_days INTEGER NOT NULL DEFAULT 90
    CHECK (payment_proof_retention_days BETWEEN 7 AND 3650),

  UNIQUE (user_id)
);

CREATE TABLE public.categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  color       TEXT DEFAULT '#FF6B35',
  icon        TEXT DEFAULT 'category',
  sort_order  INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, name)
);

CREATE TABLE public.products (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id    UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  sku            TEXT NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT,
  barcode        TEXT,
  -- Both prices, which is what makes profit tracking possible at all.
  cost_price     DECIMAL(12,2) NOT NULL DEFAULT 0,
  selling_price  DECIMAL(12,2) NOT NULL,
  stock          INTEGER NOT NULL DEFAULT 0,
  min_stock      INTEGER DEFAULT 5,
  unit           TEXT DEFAULT 'pcs',
  -- An object path inside the `product-images` bucket, never a URL. A full URL
  -- bakes the Supabase host into the row, and the host belongs to the
  -- environment: a photo written from a browser (127.0.0.1) could not load in
  -- the Android emulator (10.0.2.2) or from production. Resolved at render time.
  image_url      TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Generated, because PostgREST cannot compare two columns to each other:
  -- there is no way to ask it for `stock <= min_stock`. The product list used to
  -- request a page and then drop non-matching rows in Dart, *after* `.range()`
  -- had already chosen which rows the page contained - a filter applied to an
  -- arbitrary slice, so "stok rendah" could return an empty page 3 and a full
  -- page 4, next to a total that ignored the filter entirely.
  --
  -- COALESCE(min_stock, 5) and not 0: `min_stock` is nullable and
  -- ProductModel.fromJson reads a null as 5, so five is the threshold the app
  -- has always shown for those rows. The column has to agree with the app
  -- rather than with SQL's instinct.
  --
  -- STORED rather than VIRTUAL because it is filtered on, and only a stored
  -- generated column can be indexed.
  is_low_stock   BOOLEAN GENERATED ALWAYS AS (stock <= COALESCE(min_stock, 5)) STORED,

  UNIQUE (user_id, sku)
);

CREATE TABLE public.transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  transaction_number    TEXT NOT NULL,
  customer_name         TEXT,
  subtotal              DECIMAL(12,2) NOT NULL,
  discount_amount       DECIMAL(12,2) DEFAULT 0,
  discount_percentage   DECIMAL(5,2) DEFAULT 0,
  tax_amount            DECIMAL(12,2) DEFAULT 0,
  total                 DECIMAL(12,2) NOT NULL,
  payment_method        TEXT NOT NULL DEFAULT 'cash'
                          CHECK (payment_method IN ('cash', 'transfer', 'qris', 'debt')),
  -- 'paid' and 'debt' only. There is no 'cancelled', and no report filters for
  -- one: a hutang is a completed sale whose goods left the shop, so it counts
  -- toward revenue and profit everywhere. If a status is ever added that must
  -- NOT count as revenue, that is one considered pass over every report
  -- function with a test per function - not a predicate left in two of them.
  payment_status        TEXT NOT NULL DEFAULT 'paid'
                          CHECK (payment_status IN ('paid', 'debt')),
  cash_received         DECIMAL(12,2),
  cash_change           DECIMAL(12,2),
  notes                 TEXT,
  cashier_name          TEXT,
  transaction_date      TIMESTAMPTZ NOT NULL,
  debt_paid_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- The QRIS confirmation record.
  --
  -- A shop paying by QRIS today uses a printed sticker (QRIS statis). There is
  -- no API and no webhook behind a sticker: the customer scans it, types the
  -- amount themselves, and shows the cashier a success screen. So the app does
  -- not verify a QRIS payment - it records that a human verified one.
  --
  -- Deliberately absent: a 'pending' payment_status. With manual confirmation
  -- there is no asynchronous gap, so the row is 'paid' from birth. A pending
  -- state earns its place when something can confirm a sale *later*.

  -- Object path in the `payment-proofs` bucket, never a URL - same reason as
  -- products.image_url above.
  payment_proof_path    TEXT,
  -- When a human (or, later, a webhook) affirmed the money arrived, as opposed
  -- to transaction_date, which is when the sale happened.
  payment_confirmed_at  TIMESTAMPTZ,
  -- 'cashier' is the only value the app writes today. The other two are named
  -- now so the vocabulary is fixed before there are rows to migrate, and so a
  -- reconciliation report can tell "someone looked at a phone screen" apart
  -- from "the bank told us".
  payment_confirmed_by  TEXT
                          CHECK (payment_confirmed_by IN ('cashier', 'notification', 'webhook')),
  -- Gateway-side identifier (RRN, order id). Written by nothing yet: it is here
  -- so that the day the shop upgrades to a gateway and dynamic QRIS is a new
  -- Edge Function and nothing else, not an ALTER TABLE against a live shop.
  payment_reference     TEXT,

  UNIQUE (user_id, transaction_number)
);

-- Line items carry a snapshot of the prices at the time of sale, which is why
-- cost_price and selling_price are repeated here rather than read from
-- `products`. A shop owner editing a price must not silently rewrite history.
CREATE TABLE public.transaction_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  transaction_id   UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  -- Nullable, ON DELETE SET NULL: deleting a product must not delete the record
  -- of having sold it. product_name / product_sku are what the receipt reprints
  -- in that case.
  product_id       UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_name     TEXT NOT NULL,
  product_sku      TEXT NOT NULL,
  quantity         INTEGER NOT NULL,
  cost_price       DECIMAL(12,2) NOT NULL,
  selling_price    DECIMAL(12,2) NOT NULL,
  discount_amount  DECIMAL(12,2) DEFAULT 0,
  subtotal         DECIMAL(12,2) NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 3. INDEXES
-- ---------------------------------------------------------------------------
-- Every ordinary read is scoped by user_id (RLS supplies it), so that is the
-- leading column almost everywhere. The three exceptions are called out below.

CREATE INDEX idx_categories_user           ON public.categories (user_id);
CREATE INDEX idx_categories_user_sort      ON public.categories (user_id, sort_order);

CREATE INDEX idx_products_user             ON public.products (user_id);
CREATE INDEX idx_products_user_name        ON public.products (user_id, name);
CREATE INDEX idx_products_user_category    ON public.products (user_id, category_id);
CREATE INDEX idx_products_user_active      ON public.products (user_id, is_active);
CREATE UNIQUE INDEX idx_products_user_barcode
  ON public.products (user_id, barcode) WHERE barcode IS NOT NULL;

-- Partial on is_active, matching how the product list actually reads: RLS
-- supplies user_id, the datasource supplies is_active. Indexing inactive rows
-- would grow the index with rows no list asks for.
CREATE INDEX idx_products_user_low_stock
  ON public.products (user_id, is_low_stock)
  WHERE is_active;

CREATE INDEX idx_transactions_user              ON public.transactions (user_id);
CREATE INDEX idx_transactions_user_date         ON public.transactions (user_id, transaction_date);
CREATE INDEX idx_transactions_user_status       ON public.transactions (user_id, payment_status);
CREATE INDEX idx_transactions_user_customer     ON public.transactions (user_id, customer_name);

CREATE INDEX idx_txn_items_user            ON public.transaction_items (user_id);
CREATE INDEX idx_txn_items_transaction     ON public.transaction_items (transaction_id);
CREATE INDEX idx_txn_items_product         ON public.transaction_items (product_id);

-- Trigram indexes, for the two deliberately unanchored ILIKEs: `searchProducts`
-- in product_remote_datasource.dart, and get_customer_names, whose match cannot
-- be anchored because "sri" has to find "Bu Sri" - Indonesian names carry
-- honorifics. Measured, warm, against ~280 distinct customer names and a
-- 2k-product catalogue:
--
--   get_customer_names('sri')   256.646 ms -> 14.319 ms
--   product search ILIKE          5.137 ms ->  1.439 ms
--
-- Selectivity decides whether the planner takes these at all. An early version
-- of that measurement used five distinct customer names, so '%sri%' matched 20%
-- of the table and Postgres correctly ignored the index. A synthetic dataset
-- that is too uniform will tell you these are useless.
--
-- gin rather than gist: slower to build, faster to search, and these are read
-- far more than written.
--
-- The operator class is schema-qualified, and it has to be. pg_trgm lives in
-- `extensions` (010001), and whether `gin_trgm_ops` resolves unqualified
-- depends on the search_path of whichever role applies the migration - which
-- differs between environments. Locally the `postgres` role carries
-- `search_path = "$user", public, extensions` and a bare `gin_trgm_ops` works;
-- on a hosted project it does not, and `db push` fails here with
--
--   ERROR: operator class "gin_trgm_ops" does not exist for access method "gin"
--
-- Found the only way it could be found: the first `db push` to production. The
-- superseded migration set did not hit this because it created pg_trgm in
-- `public`, built these indexes while the opclass was resolvable there, and
-- only then moved the extension - the indexes followed by OID. Qualifying is
-- the more robust form of that, and does not depend on a role setting.
CREATE INDEX idx_products_name_trgm
  ON public.products USING gin (name extensions.gin_trgm_ops)
  WHERE is_active;

CREATE INDEX idx_transactions_customer_trgm
  ON public.transactions USING gin (customer_name extensions.gin_trgm_ops)
  WHERE customer_name IS NOT NULL;

-- Not user-scoped, and the only index here that is not: `expired_payment_proofs`
-- (010009) reads across every tenant by design, so none of the (user_id, ...)
-- indexes help it. Partial because the rows it wants are a small minority -
-- only QRIS sales with a photo ever have a path, and the retention sweep clears
-- the column as it goes - which also keeps it untouched by the ordinary POS
-- insert path. Measured with ~1% of 200k sales carrying a proof:
-- 27.189 ms -> 0.536 ms.
CREATE INDEX idx_transactions_proof_retention
  ON public.transactions (transaction_date)
  WHERE payment_proof_path IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. TRIGGERS
-- ---------------------------------------------------------------------------

CREATE TRIGGER set_updated_at_user_profiles
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_shop_settings
  BEFORE UPDATE ON public.shop_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_categories
  BEFORE UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_products
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_transactions
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 5. COLUMN COMMENTS
-- ---------------------------------------------------------------------------
-- These reach the client: PostgREST publishes them in its OpenAPI output, and
-- they are what a reader sees in Studio.

COMMENT ON COLUMN public.products.is_low_stock IS
  'Generated: stock <= COALESCE(min_stock, 5). Exists so PostgREST can filter '
  'on a comparison between two columns, which it cannot express directly. '
  'Includes out-of-stock rows - the app''s "stok rendah" filter pairs this '
  'with stock > 0, and "tersedia" is this being false.';

COMMENT ON COLUMN public.shop_settings.business_type IS
  'What kind of shop this is, as chosen during onboarding (warung_makan, '
  'kedai_kopi, toko_kelontong, ...). Free-form TEXT because the list is the '
  'app''s editorial judgement, not a database invariant. Drives the starter '
  'category templates. NULL for shops created before onboarding existed.';

COMMENT ON COLUMN public.shop_settings.payment_proof_retention_days IS
  'Days a payment proof is kept before storage-janitor deletes it. 7..3650, default 90.';

COMMENT ON COLUMN public.transactions.payment_proof_path IS
  'Object path in the payment-proofs bucket. Not a URL - resolve at render time.';
COMMENT ON COLUMN public.transactions.payment_confirmed_at IS
  'When payment was affirmed, as opposed to transaction_date (when the sale happened).';
COMMENT ON COLUMN public.transactions.payment_confirmed_by IS
  'cashier | notification | webhook. Only cashier is written today.';
COMMENT ON COLUMN public.transactions.payment_reference IS
  'Gateway RRN / order id. Unused until dynamic QRIS via a payment gateway.';
