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
-- a product photo, and object *names* are still guessable only if you know a
-- user id and a product id.
--
-- Writes are a different matter and stay locked down: the first path segment
-- must be the caller's own uid, which is the storage equivalent of the
-- `user_id = auth.uid()` policies the public tables use. The tenant key lives
-- in the object path rather than in a column, hence storage.foldername().
--
-- Object layout: <user_id>/<product_id>/<timestamp>.jpg
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BUCKET
-- ---------------------------------------------------------------------------

-- Idempotent so a re-run (or a `db reset` against a volume that kept storage
-- state) does not fail on the primary key.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = excluded.public;

-- ---------------------------------------------------------------------------
-- 2. POLICIES
-- ---------------------------------------------------------------------------
-- storage.objects has RLS enabled by Supabase already; only policies are ours.
-- Dropped first so this migration can be re-applied cleanly.

drop policy if exists "Public read access to product images" on storage.objects;
drop policy if exists "Users can upload own product images" on storage.objects;
drop policy if exists "Users can update own product images" on storage.objects;
drop policy if exists "Users can delete own product images" on storage.objects;

-- Read: anyone. This is what makes the bucket usable from <img> tags.
create policy "Public read access to product images"
  on storage.objects for select
  using (bucket_id = 'product-images');

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
