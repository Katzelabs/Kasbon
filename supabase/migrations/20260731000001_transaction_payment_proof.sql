-- =============================================================================
-- KASBON POS - Payment confirmation columns on transactions
-- =============================================================================
-- A shop paying by QRIS today uses a printed sticker (QRIS statis) from GoPay
-- Merchant or a bank. There is no API and no webhook behind a sticker: the
-- customer scans it, types the amount themselves, and shows the cashier a
-- success screen. Nothing tells this app the money arrived.
--
-- So the app does not verify a QRIS payment - it records that a human verified
-- one. These four columns are that record, plus the shape a real payment
-- gateway would need later.
--
-- Why add all four now when only three get written:
--
-- Three of them (proof, confirmed_at, confirmed_by) are written by the cashier
-- flow that ships with this change. payment_reference is not written by
-- anything yet. It is here because the day the shop upgrades to a gateway and
-- dynamic QRIS, the webhook has an RRN or order id to store, and that day
-- should be a new Edge Function and nothing else - not an ALTER TABLE against a
-- live shop's data. Four nullable columns cost nothing now and buy a migration
-- we do not have to run under pressure later.
--
-- Deliberately NOT added: a 'pending' payment_status. With manual confirmation
-- there is no asynchronous gap - the cashier taps the button only after seeing
-- the customer's screen, so the row is 'paid' from birth. A pending state earns
-- its place when something can confirm a sale *later* (a notification listener,
-- or a real webhook), and not before. Adding it early would mean every report
-- has to reason about a status no row ever holds.
-- =============================================================================

ALTER TABLE public.transactions
  -- Object path inside the `payment-proofs` bucket, never a URL.
  --
  -- The same lesson as products.image_url, which stored a full public URL until
  -- 20260730000001 and so baked the Supabase host into every row: a database
  -- read through the Android emulator (10.0.2.2), a browser (127.0.0.1) or
  -- production could not resolve an image written anywhere else. The host
  -- belongs to the environment and is applied at render time.
  ADD COLUMN payment_proof_path TEXT,

  -- When a human (or, later, a webhook) affirmed the money arrived.
  --
  -- Distinct from transaction_date, which is when the sale happened. For cash
  -- they are the same instant and this stays null; for QRIS they are the same
  -- instant today and will not be once confirmation can arrive asynchronously.
  ADD COLUMN payment_confirmed_at TIMESTAMPTZ,

  -- What did the confirming.
  --
  -- 'cashier' is the only value the app writes today. The other two are named
  -- now so the vocabulary is fixed before there are rows to migrate, and so a
  -- reconciliation report can tell "someone looked at a phone screen" apart
  -- from "the bank told us", which are very different levels of evidence.
  ADD COLUMN payment_confirmed_by TEXT
    CHECK (payment_confirmed_by IN ('cashier', 'notification', 'webhook')),

  -- Gateway-side identifier (RRN, order id). Null until a gateway exists.
  ADD COLUMN payment_reference TEXT;

COMMENT ON COLUMN public.transactions.payment_proof_path IS
  'Object path in the payment-proofs bucket. Not a URL - resolve at render time.';
COMMENT ON COLUMN public.transactions.payment_confirmed_at IS
  'When payment was affirmed, as opposed to transaction_date (when the sale happened).';
COMMENT ON COLUMN public.transactions.payment_confirmed_by IS
  'cashier | notification | webhook. Only cashier is written today.';
COMMENT ON COLUMN public.transactions.payment_reference IS
  'Gateway RRN / order id. Unused until dynamic QRIS via a payment gateway.';
