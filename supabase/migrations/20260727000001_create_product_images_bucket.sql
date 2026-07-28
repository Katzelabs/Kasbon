-- =============================================================================
-- KASBON POS - Product images storage bucket
-- =============================================================================
-- Product images used to be written to the device filesystem, and the absolute
-- path was stored in products.image_url. That path was only ever valid on the
-- phone that took the photo, so images have never synced across devices and
-- cannot render in a browser at all. This bucket is where they live instead.
--
-- Public bucket: an image is shown by <img src="..."> in the web build and by
-- Image.network on device, neither of which carries the user's access token.
-- Signed URLs would expire mid-session and break both. Nothing sensitive is in
-- a product photo.
--
-- "Public" here means exactly one thing: unauthenticated GET of a known object
-- path via /object/public/..., which bypasses RLS by design. It does NOT mean
-- the bucket should be browsable - see the SELECT policy below.
--
-- Writes stay locked down: the first path segment must be the caller's own uid,
-- which is the storage equivalent of the `user_id = auth.uid()` policies the
-- public tables use. The tenant key lives in the object path rather than in a
-- column, hence storage.foldername().
--
-- Object layout: <user_id>/<product_id>/<timestamp>.jpg
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BUCKET
-- ---------------------------------------------------------------------------

-- Idempotent so a re-run (or a `db reset` against a volume that kept storage
-- state) does not fail on the primary key.
--
-- The MIME and size limits are enforced by storage itself, before an object is
-- written, and they are not decoration. Without them any authenticated shop
-- owner could upload an arbitrary file - HTML, a video, anything - to a public
-- bucket and use the project's storage quota as free hosting. Verified: an
-- `evil.html` upload was accepted before these were set.
--
-- image/jpeg is the only type the app actually produces (the compressor
-- normalises everything to JPEG, see ImageCompression.mimeType). png and webp
-- are permitted so changing that constant later does not require a migration.
--
-- image/svg+xml is deliberately absent: SVG is a document format that can carry
-- script, so allowing it in a public bucket reintroduces exactly the upload
-- problem these limits close.
--
-- 5 MiB is far above a compressed 800px JPEG (~100-200 KB) and far below the
-- 50 MiB global ceiling in config.toml.
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

-- ---------------------------------------------------------------------------
-- 2. POLICIES
-- ---------------------------------------------------------------------------
-- storage.objects has RLS enabled by Supabase already; only policies are ours.
-- Dropped first so this migration can be re-applied cleanly.

drop policy if exists "Public read access to product images" on storage.objects;
drop policy if exists "Users can upload own product images" on storage.objects;
drop policy if exists "Users can update own product images" on storage.objects;
drop policy if exists "Users can delete own product images" on storage.objects;
drop policy if exists "Users can read own product images" on storage.objects;

-- Read: owner only, and this does NOT gate <img> rendering.
--
-- The obvious policy here is `for select using (bucket_id = 'product-images')`
-- so that "public bucket" and "public policy" match. That was the original
-- version and it was wrong, because on storage.objects a SELECT policy governs
-- LIST as well as read. Granted to role `public` with no folder scoping, an
-- unauthenticated caller could enumerate the bucket:
--
--   POST /storage/v1/object/list/product-images   (no Authorization header)
--   -> [{"name": "<some real user's auth uid>"}]
--
-- Since the tenant key IS the folder name, that hands out every user's uid and,
-- one level down, their product ids. Verified against a local stack before this
-- policy was tightened.
--
-- Rendering is unaffected: `product-images` is a public bucket, so
-- /object/public/... serves objects without consulting RLS at all. This policy
-- exists for the authenticated client's own operations - `list()` behind
-- imageExists, and reading back its own objects.
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

-- Overwriting an existing object needs both a USING (which row may be
-- targeted) and a WITH CHECK (what it may become), or a user could move
-- someone else's image into their own folder.
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
