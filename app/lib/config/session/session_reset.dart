import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/crash_reporting.dart';
import '../../features/pos/presentation/providers/cart_provider.dart';
import '../../features/pos/presentation/providers/pos_search_provider.dart';
import '../../features/reports/presentation/providers/analytics_provider.dart';
import '../../features/reports/presentation/providers/date_range_provider.dart';
import '../../features/reports/presentation/providers/report_filter_provider.dart';
import '../../shared/providers/user_provider.dart';

/// State that belongs to *one signed-in account* and outlives the screen that
/// owns it.
///
/// Every data provider in the app is `autoDispose`, so signing out disposes it
/// along with the shell and the next sign-in refetches. These are the
/// exceptions: root-scoped state deliberately kept alive across navigation,
/// which is exactly why it also survived a sign-out and greeted the next user
/// with the previous one's cart and report filters.
///
/// Device preferences are *not* here on purpose. The rail's collapse state, the
/// product list's card/table mode and the POS cart's expansion say how this
/// person likes this screen on this device, not whose data is on it - some are
/// even mirrored to `shared_preferences` to survive a restart, which would make
/// clearing them here half a reset anyway.
///
/// Add to this list when you add root-scoped state holding anything derived
/// from the signed-in account.
final List<ProviderOrFamily> sessionScopedProviders = <ProviderOrFamily>[
  // A cart is a sale in progress. Carrying one across accounts is how user B
  // rings up user A's products - against B's stock, at A's prices.
  cartProvider,

  // The POS search box and category chip: what was on screen when A left.
  posSearchQueryProvider,
  posCategoryFilterProvider,

  // Report scope. A range or a filter pinned to A's data means B opens Laporan
  // already narrowed to a question they never asked.
  dateRangeProvider,
  reportFilterProvider,
  trendGranularityProvider,
];

/// Discards everything the previous account left behind.
///
/// Takes the container rather than a `WidgetRef` so it can be driven from a
/// test without pumping a widget.
void resetSessionState(ProviderContainer container) {
  for (final provider in sessionScopedProviders) {
    container.invalidate(provider);
  }
}

/// Resets per-account state whenever the signed-in account changes.
///
/// Sits directly under the root `ProviderScope`, above the router, because the
/// account can change from anywhere: the settings screen's logout, the app
/// bar's menu, or a session that expired while the app was backgrounded.
///
/// Sign-out alone is not enough to make the UI fresh - it unmounts the shell,
/// which disposes every `autoDispose` provider under it - but the state listed
/// in [sessionScopedProviders] is root-scoped and has to be told, and decoded
/// image bytes live in a cache the widget tree does not own at all.
class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<SessionGate> {
  @override
  void initState() {
    super.initState();
    // `ref.listen` does not fire for the value already there, and launching
    // straight into a restored session is the common case - a POS device stays
    // signed in on the counter for weeks.
    unawaited(setCrashReportingUser(ref.read(currentUserIdProvider)));
  }

  @override
  Widget build(BuildContext context) {
    // Listening to the id rather than to the auth stream is what keeps a token
    // refresh - which fires every hour, mid-sale - from emptying the cart.
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _onAccountChanged(next);
    });

    return widget.child;
  }

  void _onAccountChanged(String? userId) {
    // Which shop a crash came from, so one broken device does not read as an
    // outage. The uid only - see core/observability/crash_reporting.dart.
    unawaited(setCrashReportingUser(userId));

    resetSessionState(ProviderScope.containerOf(context, listen: false));

    // Product photos are decoded and held by key - an object path, and for
    // rows written before the storage migration a signed URL. Nothing in the
    // widget tree evicts them, so without this the next account can be served
    // bytes fetched for the previous one.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}
