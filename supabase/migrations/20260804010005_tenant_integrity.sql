-- =============================================================================
-- KASBON POS - The column RLS cannot protect
-- =============================================================================
-- `user_profiles.tier` and `subscription_expires_at` are entitlements, not
-- profile fields. "Users can update own profile" (010004) scopes rows and says
-- nothing about columns, so
--
--   update user_profiles set tier = 'premium',
--                            subscription_expires_at = '2099-01-01'
--
-- is a valid statement for any signed-in user against their own row.
--
-- Nothing in the app reads `tier` today - `auth_remote_datasource.dart` only ever
-- SELECTs this table - so nothing is currently bypassed. This is the day before
-- it matters, which is the only good day to fix it.
--
-- ## Why a trigger and not a policy
--
-- Postgres RLS cannot express "these columns are read-only to this role". The
-- alternative is `REVOKE ... ON COLUMN`, which PostgREST reports as a blanket
-- 403 on the whole update - a confusing failure for a client that legitimately
-- sends the full row back.
--
-- ## Why it restores silently instead of raising
--
-- Same reason. A client that PATCHes a whole profile row should not fail because
-- it echoed back a `tier` it never intended to change. The quiet version is the
-- one that stays correct when a profile-edit screen eventually appears.
--
-- service_role is exempt: that is how billing will actually set the tier, from a
-- webhook or an admin path that never travels through PostgREST as the user.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.freeze_privileged_profile_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF COALESCE(auth.role(), 'service_role') = 'service_role' THEN
    RETURN NEW;
  END IF;

  NEW.tier                    := OLD.tier;
  NEW.subscription_expires_at := OLD.subscription_expires_at;
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.freeze_privileged_profile_columns() IS
  'Restores tier / subscription_expires_at to their previous values on any '
  'update that does not come from the service role. These are entitlements, '
  'not profile fields, and RLS cannot scope a policy to columns.';

CREATE TRIGGER freeze_tier_on_user_profiles
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.freeze_privileged_profile_columns();
