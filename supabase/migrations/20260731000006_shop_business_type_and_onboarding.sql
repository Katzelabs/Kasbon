-- =============================================================================
-- KASBON POS - What kind of shop this is, and who has finished setting one up
-- =============================================================================
-- Two facts a new user creates in the first minute, and nowhere to put either.
--
-- ## business_type
--
-- The signup trigger `handle_new_user()` creates a `user_profiles` row and
-- stops. No `shop_settings` row is created - and `shop_settings.name` is NOT
-- NULL - so until the user finds Settings -> Profil Toko their receipts print
-- an unnamed shop, their POS grid is empty and the app reads as broken.
--
-- The onboarding wizard fixes that by asking two questions. The first, the
-- shop name, already has a column. The second, what kind of shop it is, does
-- not - and it is the more useful of the two, because it is what picks the
-- starter categories (kedai kopi gets Kopi/Non-Kopi/Snack, kelontong gets
-- Sembako/Rokok/Perawatan). Throwing it away after one screen would mean
-- re-asking it the next time anything wants to tailor itself to the trade.
--
-- Free-form TEXT, not an enum or a CHECK. The list of Indonesian small-business
-- types is the app's editorial judgement, not a database invariant; adding
-- "Laundry" should be a Dart change, not a migration. It stays nullable because
-- every shop that exists today predates the question.
--
-- ## The onboarding backfill
--
-- Whether a user has been through the wizard is recorded in
-- `auth.users.raw_user_meta_data ->> 'onboarding_completed_at'`, and not in a
-- column here, because the GoRouter redirect that enforces it is synchronous:
-- `currentUser.userMetadata` is already in memory at first frame, while a table
-- read is a round trip that would paint the dashboard and then yank the user to
-- the wizard on every cold start.
--
-- Anyone who already has a `shop_settings` row has self-evidently done the
-- setup the wizard exists to collect, so they are marked complete here rather
-- than being marched through it on next launch.
--
-- Deliberately NOT done: mirroring the flag into `user_profiles`. Two writes of
-- one fact is a consistency bug with extra steps, and this is not a security
-- boundary - a user who edits their own flag only re-runs their own wizard.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BUSINESS TYPE
-- ---------------------------------------------------------------------------

ALTER TABLE public.shop_settings
  ADD COLUMN business_type TEXT;

COMMENT ON COLUMN public.shop_settings.business_type IS
  'What kind of shop this is, as chosen during onboarding (warung_makan, '
  'kedai_kopi, toko_kelontong, ...). Free-form TEXT because the list is the '
  'app''s editorial judgement, not a database invariant. Drives the starter '
  'category templates. NULL for shops created before onboarding existed.';

-- ---------------------------------------------------------------------------
-- 2. ONBOARDING BACKFILL
-- ---------------------------------------------------------------------------
-- Idempotent: the WHERE clause skips anyone already flagged, so re-applying
-- this migration cannot overwrite a real completion timestamp with NOW().

UPDATE auth.users u
   SET raw_user_meta_data =
         COALESCE(u.raw_user_meta_data, '{}'::JSONB)
         || JSONB_BUILD_OBJECT('onboarding_completed_at', NOW())
 WHERE EXISTS (
         SELECT 1 FROM public.shop_settings s WHERE s.user_id = u.id
       )
   AND u.raw_user_meta_data ->> 'onboarding_completed_at' IS NULL;
