/// The shop's business time zone, and conversions between it and UTC.
///
/// Report boundaries and report *bucketing* have to agree on what "1 July"
/// means, or a period silently gains and loses hours at its edges. The SQL side
/// buckets in `Asia/Jakarta` (see the `p_tz` default in
/// `supabase/migrations/20260726000001_advanced_report_rpcs.sql`); this class is
/// the Dart half of that same decision.
///
/// Dates flow through the app as *business wall-clock* values - a plain
/// `DateTime` whose calendar fields read as the shop sees them, so formatting
/// one for display needs no conversion. They are only turned into absolute
/// instants at the point they are sent to Postgres, via [toInstant].
///
/// A fixed offset is exact here: Indonesia observes no daylight saving. If the
/// shop time zone ever becomes configurable per user, this is the single place
/// that changes - and [zoneName] must then be passed explicitly as `p_tz`
/// rather than relying on the RPC default.
class BusinessTime {
  BusinessTime._();

  /// IANA zone name, matching the `p_tz` default on the report RPCs.
  static const String zoneName = 'Asia/Jakarta';

  /// Offset from UTC. WIB is UTC+7 year round.
  static const Duration offset = Duration(hours: 7);

  /// The current moment as business wall-clock.
  ///
  /// Use this instead of `DateTime.now()` when deciding which day, week or
  /// month the shop is currently in: on a device set to another zone,
  /// `DateTime.now()` can name a different day than the shop is trading in.
  static DateTime now() => DateTime.now().toUtc().add(offset);

  /// Read [wallClock]'s calendar fields as business-local and return the
  /// absolute instant they refer to.
  ///
  /// The input's own UTC/local flag is ignored on purpose - only its calendar
  /// fields carry meaning. `toInstant(DateTime(2026, 7, 1))` is 1 July 00:00 in
  /// Jakarta, i.e. 2026-06-30T17:00Z, whatever zone the device is set to.
  static DateTime toInstant(DateTime wallClock) {
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
      wallClock.microsecond,
    ).subtract(offset);
  }

  /// Turn an absolute [instant] into business wall-clock, for display.
  ///
  /// The inverse of [toInstant]. Timestamps coming back from Postgres are
  /// absolute, so anything rendered next to a report boundary should pass
  /// through here to stay on the same clock.
  static DateTime fromInstant(DateTime instant) => instant.toUtc().add(offset);

  /// Serialise a business wall-clock value for an RPC parameter.
  static String toRpcArgument(DateTime wallClock) =>
      toInstant(wallClock).toIso8601String();

  /// Midnight starting the business day containing [reference] (default: now).
  static DateTime startOfDay([DateTime? reference]) {
    final base = reference ?? now();
    return DateTime(base.year, base.month, base.day);
  }

  /// Midnight starting the business week (Monday) containing [reference].
  ///
  /// Monday-first matches both Postgres `date_trunc('week', ...)` and the
  /// Indonesian convention used in the heatmap.
  static DateTime startOfWeek([DateTime? reference]) {
    final base = reference ?? now();
    return DateTime(base.year, base.month, base.day - base.weekday + 1);
  }

  /// The 1st of the business month containing [reference].
  static DateTime startOfMonth([DateTime? reference]) {
    final base = reference ?? now();
    return DateTime(base.year, base.month);
  }
}
