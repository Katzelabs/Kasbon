-- =============================================================================
-- KASBON POS - Payment proof storage bucket
-- =============================================================================
-- Where the photo of a customer's QRIS success screen lives. Referenced by
-- transactions.payment_proof_path as an object path, never a URL.
--
-- PRIVATE, unlike `product-images`, and that is the whole design decision here.
--
-- The product bucket is public because a product photo is drawn constantly - a
-- grid tile, a detail panel, a browser <img> with no access token attached -
-- and a signed URL that expires mid-session would break rendering for a shop
-- owner who left a tab open. Nothing in a product photo is sensitive.
--
-- A payment proof is the opposite on both counts. It is a photograph of someone
-- else's phone: an amount, a timestamp, often a name or a partial phone number,
-- occasionally a wallet balance. And it is looked at almost never - only when
-- a sale is disputed and someone goes back through the day. Rare, deliberate
-- reads are exactly the case a signed URL fits: mint it when the cashier opens
-- the transaction, let it expire, mint another next time.
--
-- "Public" on a bucket means unauthenticated GET of a known object path,
-- bypassing RLS entirely. Object paths here are two UUIDs deep and effectively
-- unguessable, so a public bucket would probably not leak anything in practice.
-- "Probably not, in practice" is a fine argument for a product photo and a poor
-- one for a payment record, so this bucket does not take it.
--
-- Object layout: <user_id>/<transaction_id>/<timestamp>.jpg
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BUCKET
-- ---------------------------------------------------------------------------
-- Idempotent, like the product bucket, so a re-run or a `db reset` against a
-- volume that kept storage state does not fail on the primary key.
--
-- The MIME and size limits are not decoration - see the product bucket
-- migration, where an `evil.html` upload was accepted before they were set.
-- They matter slightly less here (this bucket is not public, so it cannot be
-- used as free anonymous hosting) but a shop owner can still burn the project's
-- storage quota, and there is no reason to allow anything but an image.
--
-- image/svg+xml is deliberately absent for the same reason as the product
-- bucket: SVG is a document format that can carry script.
--
-- 5 MiB matches the product bucket. A compressed proof is ~150-250 KB; the
-- ceiling exists to stop an uncompressed 12-megapixel original slipping through
-- if the compressor is ever bypassed.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880, -- 5 MiB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 2. POLICIES
-- ---------------------------------------------------------------------------
-- storage.objects has RLS enabled by Supabase; only the policies are ours.
-- Dropped first so this migration re-applies cleanly.
--
-- Every policy is scoped to `to authenticated` and to the caller's own folder.
-- The tenant key is the first path segment rather than a column, which is why
-- these use storage.foldername() where a table policy would use user_id.

drop policy if exists "Users can read own payment proofs" on storage.objects;
drop policy if exists "Users can upload own payment proofs" on storage.objects;
drop policy if exists "Users can update own payment proofs" on storage.objects;
drop policy if exists "Users can delete own payment proofs" on storage.objects;

-- Read.
--
-- On storage.objects a SELECT policy governs LIST as well as GET, so folder
-- scoping is load-bearing: an unscoped `using (bucket_id = '...')` granted to
-- `public` let an unauthenticated caller enumerate the product bucket and
-- harvest every user's auth uid, since the uid IS the folder name. That was
-- found and fixed on the product bucket; this one is born with the fix.
--
-- Unlike the product bucket, this policy is also what gates actual reads -
-- there is no /object/public/ path that skips RLS here. Creating a signed URL
-- goes through it too, so a user can only sign objects in their own folder.
create policy "Users can read own payment proofs"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can upload own payment proofs"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- A re-shot proof overwrites the previous one, so update needs both clauses:
-- USING says which object may be targeted, WITH CHECK says what it may become.
-- (Postgres would fall back to USING for the check if WITH CHECK were omitted,
-- so this is explicitness rather than a fix - but a reader should not have to
-- know that fallback rule to be sure the policy is right.)
create policy "Users can update own payment proofs"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete own payment proofs"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
