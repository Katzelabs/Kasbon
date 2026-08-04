// =============================================================================
// delete-account - erases the caller's own account, and only their own
// =============================================================================
// Google Play requires an in-app route to delete the account; Apple requires
// the same of any app that creates one. The app calls this; there is no other
// caller.
//
// ## Why an Edge Function
//
// Deleting an `auth.users` row needs `auth.admin.deleteUser()`, which needs the
// service role. The app ships a publishable key, so the client cannot do it -
// and a `SECURITY DEFINER` RPC that could would be one blanket grant away from
// letting any signed-in user delete any account by uuid (see
// 20260804010003, which grants EXECUTE on every new public function to
// `authenticated` by default). Holding the service key in a process the client
// cannot reach, and deriving the target uid from the caller's own token rather
// than from a parameter, is the shape that has no such failure mode.
//
// ## Auth
//
// The caller presents *their own* user access token. `verify_jwt` is off in
// config.toml, and the verification below is strictly stronger: `getUser(jwt)`
// is checked against the auth server with the service-role client, so an
// expired, revoked or forged token fails, and the uid comes back from that
// check rather than from the request body. There is no parameter naming who to
// delete, so there is nothing to tamper with.
//
// This is the opposite of `storage-janitor`, which compares the presented
// credential against the service key: that one is called by cron and must be
// callable by nobody else, this one is called by every user and must act only
// on themselves. A service key presented here is rejected by `getUser` - it is
// a JWT with a role and no `sub`, so it identifies no user.
//
// ## Order of operations
//
// The auth row goes first, then storage:
//
//   1. Collect the object paths (before anything is destroyed, so a failure
//      here costs nothing).
//   2. `deleteUser` - cascades user_profiles, shop_settings, categories,
//      products, transactions, transaction_items. If this fails, nothing has
//      been deleted and the user can retry.
//   3. Delete the objects. If a batch fails, the account is already gone and
//      the objects are now unreferenced, which is exactly what
//      `storage-janitor`'s orphan sweep collects - so the worst case degrades
//      to the 24h path rather than to a leak.
//
// The reverse order has a strictly worse failure mode: photos deleted out from
// under an account that still exists.
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

/// Buckets an account owns objects in. Both key the tenant off the first path
/// segment (`<user_id>/<product_id>/<file>`), which is what makes the prefix
/// query in `account_object_paths` sufficient.
const BUCKETS = ['product-images', 'payment-proofs'] as const

/// Objects per Storage API call, and per `account_object_paths` page.
///
/// `remove()` takes an array and the API rejects very large bodies. Matches the
/// janitor's batch size for the same reasons.
const DELETE_BATCH = 100

/// Stops a pathological loop. A shop with more than this many objects in one
/// bucket has bigger problems, and the leftovers are orphans the janitor
/// collects.
const MAX_BATCHES = 200

/// CORS, which the janitor does not need and this does.
///
/// The web build is a must-ship target, so this is called from a browser with
/// a preflight. `Authorization` must be in the allowed headers or the real
/// request never leaves; `apikey` and `content-type` are what supabase-js
/// attaches to an `invoke`.
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface Report {
  /// True when the auth row is gone. The user is deleted or they are not;
  /// storage errors below do not change this.
  deleted: boolean
  objectsDeleted: Record<string, number>
  /// Non-fatal. Anything in here is an object left behind, which is now an
  /// orphan and gets swept within 24h. Logged so the sweep is a known fallback
  /// rather than a surprise.
  errors: string[]
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    status,
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  // POST only. A deletion behind a GET is one prefetching link preview away
  // from happening by accident.
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    // No session to persist and nothing to refresh: this process handles one
    // request and exits. Critically, it must not adopt the caller's token as
    // its own - the admin calls below need the service role.
    { auth: { persistSession: false, autoRefreshToken: false } },
  )

  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? ''
  if (!token) {
    return json({ error: 'unauthorized' }, 401)
  }

  const { data: caller, error: callerError } = await supabase.auth.getUser(token)
  const userId = caller?.user?.id
  if (callerError || !userId) {
    // Terse on purpose: the app shows its own copy, and detail here only helps
    // someone probing the endpoint.
    return json({ error: 'unauthorized' }, 401)
  }

  const report: Report = { deleted: false, objectsDeleted: {}, errors: [] }

  // ---------------------------------------------------------------------------
  // 1. WHAT WILL NEED DELETING - before anything is destroyed
  // ---------------------------------------------------------------------------
  const paths: Record<string, string[]> = {}
  for (const bucket of BUCKETS) {
    paths[bucket] = []
    report.objectsDeleted[bucket] = 0

    // Keyset paging: nothing is deleted during this loop, so the set does not
    // shrink and `p_after` is what stops the same page coming back forever.
    let after = ''
    for (let batch = 0; batch < MAX_BATCHES; batch++) {
      const { data, error } = await supabase.rpc('account_object_paths', {
        p_bucket: bucket,
        p_user_id: userId,
        p_limit: DELETE_BATCH,
        p_after: after,
      })

      if (error) {
        // Not fatal. The account still gets deleted below and whatever was
        // missed here becomes an orphan for the janitor.
        report.errors.push(`list ${bucket}: ${error.message}`)
        break
      }

      const page = ((data ?? []) as { object_path: string }[]).map((r) => r.object_path)
      if (page.length === 0) break

      paths[bucket].push(...page)
      after = page[page.length - 1]
      if (page.length < DELETE_BATCH) break
    }
  }

  // ---------------------------------------------------------------------------
  // 2. THE ACCOUNT - the part that must succeed
  // ---------------------------------------------------------------------------
  const { error: deleteError } = await supabase.auth.admin.deleteUser(userId)
  if (deleteError) {
    // Nothing has been destroyed at this point. Reported as a failure so the
    // app can say so and the user can try again.
    console.error(`delete-account: ${userId}: ${deleteError.message}`)
    return json({ error: 'delete_failed', message: deleteError.message }, 500)
  }
  report.deleted = true

  // ---------------------------------------------------------------------------
  // 3. THE OBJECTS - best effort, with a known fallback
  // ---------------------------------------------------------------------------
  for (const bucket of BUCKETS) {
    const all = paths[bucket]
    for (let i = 0; i < all.length; i += DELETE_BATCH) {
      const batch = all.slice(i, i + DELETE_BATCH)
      const { error } = await supabase.storage.from(bucket).remove(batch)

      if (error) {
        report.errors.push(`${bucket} batch ${i}: ${error.message}`)
        continue
      }
      report.objectsDeleted[bucket] += batch.length
    }
  }

  // Logged whole: this is the only record that an account existed, since every
  // row naming it is gone by now.
  console.log(JSON.stringify({ userId, ...report }))

  return json(report, 200)
})
