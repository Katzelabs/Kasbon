/// Row limits for every Supabase read in the app.
///
/// ## Why an unbounded `.select()` is a bug, not just a slow query
///
/// PostgREST caps every response at `max_rows`, set to 1000 in
/// `supabase/config.toml`. It applies the cap *silently*: a `.select()` with no
/// range returns 1000 rows and a 200, with nothing in the payload to say the
/// set was cut. A list that renders those 1000 rows looks complete, and any
/// total summed from them is simply wrong once the table passes the cap - the
/// shop reads a smaller number than it actually took.
///
/// So the rule here is that every read states a bound. Either it asks for a
/// page (`.range`), or it caps itself below [supabaseMaxRows] and treats
/// hitting the cap as a fact worth surfacing. Nothing is left to the server's
/// default, because the server's default is a lie by omission.
class QueryLimits {
  const QueryLimits._();

  /// PostgREST's `max_rows` from `supabase/config.toml`.
  ///
  /// Any single request asking for more than this gets silently truncated to
  /// it, so no chunk size in the app may exceed it.
  static const int supabaseMaxRows = 1000;

  /// Rows per request when walking a whole table in chunks.
  ///
  /// Half of [supabaseMaxRows] rather than all of it: a chunk that lands
  /// exactly on the server cap is indistinguishable from a chunk that was
  /// truncated by it, and the paging loop's "a short page means the end" test
  /// would never fire.
  static const int chunkSize = 500;

  /// Transactions per page in the history list.
  ///
  /// Roughly two screens' worth on a phone, so the infinite scroll's trigger
  /// has somewhere to sit below the fold on first load.
  static const int transactionPageSize = 20;

  /// Ceiling on the unpaid-debt list.
  ///
  /// The debt screen sums what it fetched, so this doubles as the point past
  /// which its totals stop being the whole truth - the list says so on screen
  /// when it is reached. 2000 is far past what a UMKM carries in open hutang;
  /// it exists so the screen degrades loudly instead of hanging on a table
  /// that grew unexpectedly.
  static const int debtCeiling = 2000;

  /// Ceiling on a product catalogue pulled for export.
  ///
  /// An export legitimately wants every product, so this is a memory guard
  /// rather than a page size. The exporters report truncation when it bites.
  static const int productExportCeiling = 10000;

  /// Ceiling on rows read from one table during a backup.
  ///
  /// A backup that is quietly missing rows is worse than a backup that fails,
  /// so passing this throws rather than returning a short file.
  static const int backupRowCeiling = 100000;

  /// Cap on a plain "give me the products" read.
  ///
  /// Every screen that renders products pages properly; this bounds the
  /// remaining whole-list reads (search, category, low stock) so none of them
  /// can reach the server cap unannounced.
  static const int productFetchCap = 500;

  /// Cap on the category list.
  ///
  /// Categories are a hand-curated handful in practice. The cap is here so the
  /// read has a stated bound like every other, not because it is expected to
  /// bind.
  static const int categoryFetchCap = 200;

  /// Cap on the line items of a single transaction.
  ///
  /// Scoped to one transaction, so this only binds on a receipt far larger
  /// than a till produces.
  static const int transactionItemsCap = 500;
}
