/// Fallback for platforms with neither `dart:io` nor JS interop.
///
/// Unreachable in practice - every target the app builds for resolves to the
/// io or web variant. It exists so the conditional export in
/// `url_strategy.dart` has a default, which the language requires.
void configureUrlStrategy() {}
