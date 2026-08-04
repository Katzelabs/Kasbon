-- =============================================================================
-- KASBON POS - The two buckets, and who may touch what in them
-- =============================================================================
-- `product-images` is public, `payment-proofs` is not, and that difference is
-- the only real design decision in this file.
--
-- A product photo is drawn constantly - a grid tile, a detail panel, a browser
-- <img> with no access token attached - and a signed URL that expired mid-session
-- would break rendering for a shop owner who left a tab open. Nothing in a
-- product photo is sensitive.
--
-- A payment proof is the opposite on both counts. It is a photograph of someone
-- else's phone: an amount, a timestamp, often a name or a partial phone number,
-- occasionally a wallet balance. And it is looked at almost never - only when a
-- sale is disputed and someone goes back through the day. Rare, deliberate reads
-- are exactly the case a signed URL fits.
--
-- "Public" on a bucket means one thing: unauthenticated GET of a known object
-- path via /object/public/..., which bypasses RLS entirely. Proof paths are two
-- UUIDs deep and effectively unguessable, so a public bucket would probably not
-- leak anything in practice - and "probably not, in practice" is a fine argument
-- for a product photo and a poor one for a payment record.
--
-- In both buckets the tenant key is the first path segment, which is why these
-- policies use storage.foldername() where a table policy uses user_id:
--
--   product-images:  <user_id>/<product_id>/<timestamp>.<ext>
--   payment-proofs:  <user_id>/<transaction_id>/<timestamp>.<ext>
--
-- The extension travels with the bytes rather than coming from a constant: the
-- native encoders produce WebP, browsers still get JPEG (package:image only
-- encodes WebP losslessly, which would be larger than the JPEG it replaced), so
-- reading the extension from a constant is how an object ends up named `.jpg`
-- while holding WebP.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BUCKETS
-- ---------------------------------------------------------------------------
-- The MIME and size limits are enforced by storage itself, before an object is
-- written, and they are not decoration. Without them any authenticated shop
-- owner could upload an arbitrary file - HTML, a video, anything - to a public
-- bucket and use the project's storage quota as free hosting. Verified: an
-- `evil.html` upload was accepted before these were set.
--
-- image/svg+xml is deliberately absent from both. SVG is a document format that
-- can carry script, so allowing it in a public bucket reintroduces exactly the
-- problem these limits close.
--
-- 5 MiB is far above a compressed 800px image (~15 KB WebP, ~150-250 KB for a
-- proof) and far below the 50 MiB global ceiling in config.toml. The ceiling
-- exists to stop an uncompressed 12-megapixel original slipping through if the
-- compressor is ever bypassed.
--
-- `on conflict do update` so a re-run, or a reset against a volume that kept
-- storage state, does not fail on the primary key.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880, -- 5 MiB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

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
-- 2. PRODUCT IMAGE POLICIES
-- ---------------------------------------------------------------------------
-- storage.objects has RLS enabled by Supabase already; only the policies are
-- ours.
--
-- The SELECT policy is the one worth reading carefully. The obvious version is
-- `for select using (bucket_id = 'product-images')`, so that "public bucket" and
-- "public policy" match. That was the original and it was wrong, because on
-- storage.objects a SELECT policy governs LIST as well as read. Granted to role
-- `public` with no folder scoping, an unauthenticated caller could enumerate the
-- bucket:
--
--   POST /storage/v1/object/list/product-images   (no Authorization header)
--   -> [{"name": "<some real user's auth uid>"}]
--
-- Since the tenant key IS the folder name, that hands out every user's uid and,
-- one level down, their product ids. Verified against a local stack before it
-- was tightened.
--
-- Rendering is unaffected: this is a public bucket, so /object/public/... serves
-- objects without consulting RLS at all. This policy governs the authenticated
-- client's own operations - `list()` behind imageExists, and reading back its
-- own objects.

create policy "Users can read own product images"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can upload own product images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Overwriting an existing object needs both a USING (which row may be targeted)
-- and a WITH CHECK (what it may become), or a user could move someone else's
-- image into their own folder.
create policy "Users can update own product images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete own product images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- 3. PAYMENT PROOF POLICIES
-- ---------------------------------------------------------------------------
-- Same shape, one difference in consequence: there is no /object/public/ path
-- that skips RLS here, so this SELECT policy is what gates actual reads. Minting
-- a signed URL goes through it too, so a user can only sign objects in their own
-- folder.

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

-- A re-shot proof overwrites the previous one, so update needs both clauses.
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
