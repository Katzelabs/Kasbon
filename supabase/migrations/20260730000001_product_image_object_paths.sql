-- =============================================================================
-- KASBON POS - products.image_url holds an object path, not a URL
-- =============================================================================
-- The column was filled with what `getPublicUrl` returned, which is an absolute
-- URL: `http://127.0.0.1:54321/storage/v1/object/public/product-images/<path>`.
-- The host in that string belongs to whichever environment wrote the row, so a
-- photo uploaded from Chrome against a local stack could not load in the
-- Android emulator (`10.0.2.2`), on a LAN device, or from production - and
-- pointing the app at a different Supabase invalidated every image at once.
-- The app now stores `<user_id>/<product_id>/<timestamp>.jpg` and resolves the
-- host when it renders.
--
-- This rewrites the rows that still carry a URL. Guarded by the LIKE, so it is
-- idempotent and safe on a `db reset` where nothing matches.
--
-- Left alone deliberately:
--   * absolute device paths (`/data/user/0/...`) from the retired local
--     storage. They name no object here, and nulling them would be a data
--     deletion this migration has no business making - the app already renders
--     them as a placeholder everywhere but the phone that wrote them.
--   * URLs pointing at any other bucket or host, for the same reason.
-- =============================================================================

update products
set image_url = split_part(
      split_part(image_url, '/object/public/product-images/', 2),
      '?',
      1
    )
where image_url like '%/object/public/product-images/%';

-- A path with no `/` is not one of ours: every object this app writes lives
-- under `<user_id>/<product_id>/`. If the rewrite above produced one, the URL
-- it came from was malformed, and leaving a bare filename in the column would
-- have the app resolve it to a public URL for an object at the bucket root.
update products
set image_url = null
where image_url is not null
  and image_url <> ''
  and image_url not like '/%'
  and image_url not like '%://%'
  and image_url not like '%/%';
