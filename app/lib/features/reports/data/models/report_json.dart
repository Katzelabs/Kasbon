/// Shared coercion helpers for RPC result rows.
///
/// The report RPCs return JSONB, and Postgres `DECIMAL` can arrive as a JSON
/// number or, for very large values, as a string. Every field is also nullable
/// in practice because `jsonb_agg` over an empty group yields nulls. These
/// helpers keep that defensiveness in one place instead of repeating a cast
/// chain in six models.
library;

/// Coerce a JSON value to double, falling back to [fallback].
double asDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Coerce a JSON value to a nullable double. Returns null for null or for a
/// string that does not parse, so callers can distinguish "absent" from "zero".
double? asDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Coerce a JSON value to int, falling back to [fallback].
int asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Coerce a JSON value to bool, falling back to [fallback].
///
/// Accepts the Postgres text forms as well, since a boolean can surface as
/// `"true"` / `"t"` depending on how it was cast.
bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalised = value.toLowerCase();
    if (normalised == 'true' || normalised == 't') return true;
    if (normalised == 'false' || normalised == 'f') return false;
  }
  return fallback;
}

/// Coerce a JSON value to a non-null String, falling back to [fallback].
String asString(dynamic value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

/// Coerce a JSON value to a nullable String, treating an empty string as null.
String? asStringOrNull(dynamic value) {
  if (value is String) return value.isEmpty ? null : value;
  if (value == null) return null;
  return value.toString();
}

/// Parse an ISO 8601 timestamp, returning null when absent or unparseable.
///
/// Timestamps come back from Postgres in UTC with an explicit offset; they are
/// converted to local time so date formatting in the UI matches the shop's own
/// clock.
DateTime? asDateTimeOrNull(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Parse a date-only bucket key such as `2026-07-31`.
///
/// These are already local wall-clock dates produced by the RPC's time zone
/// conversion, so they are parsed as-is rather than being shifted again.
DateTime? asLocalDateOrNull(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
