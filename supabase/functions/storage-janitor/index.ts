// =============================================================================
// storage-janitor - bounds what the two storage buckets can grow to
// =============================================================================
// Two jobs, both of which exist because storage is the quota that runs out
// first. On the free tier the project gets 1 GB, and a shop photographing 50
// QRIS sales a day writes ~15 MB/day against it - about ten weeks to full, with
// nothing that ever deletes anything.
//
//   retention - a payment proof past its shop's window. A proof is a
//               reconciliation aid for arguing about a sale; once the sale is
//               too old to argue about, it is just bytes.
//
//   orphans   - objects no row points at. Both delete paths in the app drop
//               their errors deliberately (`RemovePaymentProof`,
//               `ProductFormScreen._releaseUnusedImages`), because a row naming
//               a missing file is worse than a file nobody names. That is the
//               right trade and it leaks; this is the other half of it.
//
// ## Why this is a function and not a cron job in SQL
//
// `storage.protect_delete()`, a BEFORE DELETE trigger on `storage.objects`,
// raises on any direct delete: "Direct deletion from storage tables is not
// allowed. Use the Storage API instead." Removing an object is an HTTP call,
// and pg_cron cannot make one without pg_net, which cannot easily handle the
// response. So Postgres decides *what* (see 20260801000001) and this decides
// nothing at all - it only performs the deletes and reports what happened.
//
// ## Auth
//
// `verify_jwt = true` is necessary and nowhere near sufficient. It proves the
// caller holds *some* valid JWT for this project - which every signed-in shop
// owner does. It says nothing about which role that JWT carries, so on its own
// it let any authenticated user fire a project-wide sweep that runs, below,
// with the service role.
//
// The damage was bounded (the policy functions in 20260801000001 only ever
// name objects that are already expired or already orphaned, so nothing a user
// could still reach was deletable) but the sweep is O(objects) and free to
// trigger in a loop, and "bounded" is not the same as "authorised".
//
// So the caller is checked against the service key directly rather than by
// decoding claims. `run_storage_janitor` sends `Bearer <service key>` read from
// Vault, so the expected value is known exactly and an equality test cannot be
// fooled by a JWT that merely parses. The comparison is length-then-XOR so it
// does not return early on the first differing byte.
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

/// Constant-time string comparison.
///
/// A plain `===` leaks how many leading bytes matched through its running time.
/// That is a thin channel over HTTP and this key is long, but the mitigation is
/// four lines and the alternative is arguing about how thin.
function secureEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return diff === 0
}

/// Buckets swept for orphans. Retention applies only to payment proofs - a
/// product photo has no expiry, it is deleted when its product is.
const ORPHAN_BUCKETS = ['product-images', 'payment-proofs'] as const

/// How long an object must have existed before it can be called an orphan.
///
/// Load-bearing. An upload writes the object *before* the row that names it
/// (`ProductImagePicker` uploads on pick, the form writes the row on save), so
/// "no row points at this" is the normal state of every photo belonging to a
/// form somebody currently has open. Anything shorter than an editing session
/// deletes live photos out from under people.
const ORPHAN_MIN_AGE = '24 hours'

/// Objects per Storage API call.
///
/// `remove()` takes an array, and the API rejects very large bodies. 100 keeps
/// each request small enough to retry cheaply and bounds how much one failure
/// costs.
const DELETE_BATCH = 100

interface Report {
  /// True when nothing was deleted. Named in the payload rather than left to
  /// the caller to remember, because this report is written to a log that
  /// someone reads weeks later while working out where an object went - and
  /// "orphansFound: 3" means two completely different things depending on it.
  dryRun: boolean
  proofsExpired: number
  proofsDeleted: number
  pathsCleared: number
  /// Found, not deleted: on a dry run nothing is removed, and on a real run a
  /// batch can fail. Compare against `orphansDeleted` for the difference.
  orphansFound: Record<string, number>
  orphansDeleted: Record<string, number>
  errors: string[]
}

Deno.serve(async (req) => {
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Before anything else, and before the service-role client below exists.
  const presented = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? ''
  if (!secureEquals(presented, serviceKey)) {
    // Deliberately terse. The caller is a cron job that does not read this, and
    // anything more descriptive only helps someone probing the endpoint.
    return new Response(JSON.stringify({ error: 'forbidden' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 403,
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceKey,
    // No session to persist and nothing to refresh: this process handles one
    // request and exits.
    { auth: { persistSession: false, autoRefreshToken: false } },
  )

  // A dry run reports what it would delete and deletes nothing. Worth having
  // before the first real run against a project with real shops on it.
  const dryRun = new URL(req.url).searchParams.get('dry_run') === 'true'

  const report: Report = {
    dryRun,
    proofsExpired: 0,
    proofsDeleted: 0,
    pathsCleared: 0,
    orphansFound: {},
    orphansDeleted: {},
    errors: [],
  }

  // ---------------------------------------------------------------------------
  // 1. RETENTION
  // ---------------------------------------------------------------------------
  try {
    const { data: expired, error } = await supabase.rpc('expired_payment_proofs')
    if (error) throw error

    const rows = (expired ?? []) as { transaction_id: string; object_path: string }[]
    report.proofsExpired = rows.length

    if (rows.length > 0 && !dryRun) {
      // Object first, then the column - see clear_payment_proof_paths for why
      // this is the opposite order to RemovePaymentProof. A failure between the
      // two leaves a row naming a deleted object, which the next run finds and
      // finishes; the reverse would strand the object with nothing to find it
      // by.
      for (let i = 0; i < rows.length; i += DELETE_BATCH) {
        const batch = rows.slice(i, i + DELETE_BATCH)

        const { error: removeError } = await supabase
          .storage
          .from('payment-proofs')
          .remove(batch.map((r) => r.object_path))

        if (removeError) {
          // Only this batch is lost; the rest of the sweep still runs and the
          // next one retries these. Nothing here is destructive on retry.
          report.errors.push(`proof batch ${i}: ${removeError.message}`)
          continue
        }
        report.proofsDeleted += batch.length

        const { data: cleared, error: clearError } = await supabase
          .rpc('clear_payment_proof_paths', {
            p_transaction_ids: batch.map((r) => r.transaction_id),
          })

        if (clearError) {
          report.errors.push(`clear batch ${i}: ${clearError.message}`)
          continue
        }
        report.pathsCleared += (cleared as number) ?? 0
      }
    }
  } catch (e) {
    report.errors.push(`retention: ${e instanceof Error ? e.message : String(e)}`)
  }

  // ---------------------------------------------------------------------------
  // 2. ORPHANS
  // ---------------------------------------------------------------------------
  for (const bucket of ORPHAN_BUCKETS) {
    report.orphansFound[bucket] = 0
    report.orphansDeleted[bucket] = 0
    try {
      const { data, error } = await supabase.rpc('orphaned_object_paths', {
        p_bucket: bucket,
        p_min_age: ORPHAN_MIN_AGE,
      })
      if (error) throw error

      const paths = ((data ?? []) as { object_path: string }[]).map((r) => r.object_path)
      report.orphansFound[bucket] = paths.length
      if (paths.length === 0 || dryRun) continue

      for (let i = 0; i < paths.length; i += DELETE_BATCH) {
        const batch = paths.slice(i, i + DELETE_BATCH)
        const { error: removeError } = await supabase.storage.from(bucket).remove(batch)

        if (removeError) {
          report.errors.push(`${bucket} orphan batch ${i}: ${removeError.message}`)
          continue
        }
        report.orphansDeleted[bucket] += batch.length
      }
    } catch (e) {
      report.errors.push(`${bucket}: ${e instanceof Error ? e.message : String(e)}`)
    }
  }

  // Always 200 with a body describing what happened, even when parts failed.
  // The caller is pg_cron via pg_net, which stores the response and does not
  // read it - so a non-2xx would be a silent failure, while a body in
  // `net._http_response` is something a human can go and look at. `errors`
  // being non-empty is the signal, not the status code.
  console.log(JSON.stringify(report))

  return new Response(JSON.stringify(report, null, 2), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})
