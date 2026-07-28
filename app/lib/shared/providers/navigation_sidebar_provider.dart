import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/responsive/breakpoint.dart';

/// Key the rail's collapse state is persisted under.
///
/// Namespaced rather than bare `sidebar_expanded`, because this is the first
/// preference the app stores and the flat key space fills up quickly.
const String navigationSidebarPrefsKey = 'navigation.sidebar.expanded';

/// The user's explicit choice about the navigation rail's width.
///
/// `null` means *no choice yet*, not *collapsed* - the shell then falls back to
/// the tier default via [resolveRailExpanded]. Keeping "unset" distinct from
/// "collapsed" is what lets `large` open expanded on first run while still
/// honouring a user who collapsed it once and expects it to stay that way.
///
/// Read it through [resolveRailExpanded] rather than using the raw value:
///
/// ```dart
/// final isExpanded = resolveRailExpanded(
///   context.windowBreakpoint,
///   ref.watch(navigationSidebarExpandedProvider),
/// );
/// ```
final navigationSidebarExpandedProvider =
    StateNotifierProvider<NavigationSidebarNotifier, bool?>(
  (ref) => NavigationSidebarNotifier(),
);

/// Whether the rail shows labels at [tier], given the user's [preference].
///
/// The tier has the final say at both ends of the range:
///
/// * `compact` has no rail at all, so the question is moot - false.
/// * `medium` (600-899dp) can only afford the 80dp rail. Expanding it to 280dp
///   would leave under 620dp of content, which is narrower than the phone
///   layouts that band is already tight for. The preference is remembered but
///   deliberately not applied here; it takes effect again at `expanded`.
/// * `expanded` and `large` differ only in their default: a landscape tablet
///   starts collapsed, a desktop window starts open.
bool resolveRailExpanded(Breakpoint tier, bool? preference) {
  switch (tier) {
    case Breakpoint.compact:
    case Breakpoint.medium:
      return false;
    case Breakpoint.expanded:
      return preference ?? false;
    case Breakpoint.large:
      return preference ?? true;
  }
}

/// Holds the rail preference and mirrors it to `shared_preferences`.
///
/// Hydration is asynchronous and the shell renders before it lands, so the
/// first frame shows the tier default and swaps to the stored value once it
/// arrives. That flicker is invisible in practice (the read resolves within a
/// frame or two) and is the price of not blocking startup on a disk read.
class NavigationSidebarNotifier extends StateNotifier<bool?> {
  NavigationSidebarNotifier() : super(null) {
    _hydrate();
  }

  /// True once the user has toggled the rail in this session.
  ///
  /// Guards against a slow disk read landing *after* a toggle and reverting it,
  /// which is a real race on a cold start: the shell is interactive long before
  /// the platform channel answers.
  bool _touched = false;

  Future<void> _hydrate() async {
    final prefs = await _openPrefs();
    if (prefs == null || _touched || !mounted) return;
    if (!prefs.containsKey(navigationSidebarPrefsKey)) return;

    state = prefs.getBool(navigationSidebarPrefsKey);
  }

  /// Records an explicit choice and persists it.
  Future<void> setExpanded(bool expanded) async {
    _touched = true;
    state = expanded;

    final prefs = await _openPrefs();
    await prefs?.setBool(navigationSidebarPrefsKey, expanded);
  }

  /// Flips the rail from whatever it currently shows at [tier].
  ///
  /// Takes the tier rather than negating [state] so the first toggle does the
  /// visible thing: with no stored preference on `large` the rail is open, and
  /// `!null` has no answer for that.
  Future<void> toggle(Breakpoint tier) =>
      setExpanded(!resolveRailExpanded(tier, state));

  /// Forgets the choice, returning the rail to its tier default.
  Future<void> clear() async {
    _touched = true;
    state = null;

    final prefs = await _openPrefs();
    await prefs?.remove(navigationSidebarPrefsKey);
  }

  /// `shared_preferences`, or null where the platform channel is unavailable.
  ///
  /// A widget test that pumps the shell without calling
  /// `SharedPreferences.setMockInitialValues` gets a [MissingPluginException];
  /// so does a headless run before the binding is ready. Neither is worth an
  /// unhandled error over a navigation rail's width, so both degrade to "no
  /// stored preference" and the tier default stands.
  static Future<SharedPreferences?> _openPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
