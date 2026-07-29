import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/product.dart';
import 'products_provider.dart';

/// Enum for product list view mode
enum ProductViewMode {
  grid,
  table,
}

/// Key the product list's view mode is persisted under.
///
/// Namespaced the same way [navigationSidebarPrefsKey] is - see
/// `navigation_sidebar_provider.dart` for why the flat key space is avoided.
const String productViewModePrefsKey = 'products.view_mode';

/// Whether the product list shows cards or a table.
///
/// Deliberately *not* `autoDispose`, unlike [productSelectionProvider]: this is
/// a preference, not a transient interaction. Someone who switches to the table
/// means "show me tables", and having that revert every time they visit the
/// dashboard and come back would be a bug of its own. It is mirrored to
/// `shared_preferences` so it also survives a restart.
final productViewModeProvider =
    NotifierProvider<ProductViewModeNotifier, ProductViewMode>(
  ProductViewModeNotifier.new,
);

/// Holds the view mode and mirrors it to `shared_preferences`.
///
/// Callers go through [setMode] rather than assigning `state` directly, which
/// is what a bare `StateProvider` used to allow. `Notifier.state` is protected,
/// and an intent-named method is the better API anyway: writing the preference
/// is not the same act as writing the field, and only one of those is what a
/// toggle button means.
class ProductViewModeNotifier extends Notifier<ProductViewMode> {
  /// True once the value has changed in this session.
  ///
  /// Guards against a slow disk read landing *after* the user has already
  /// toggled the view and reverting it - the same race the navigation rail's
  /// preference has, and for the same reason: the list is interactive long
  /// before the platform channel answers.
  bool _touched = false;

  bool _disposed = false;

  @override
  ProductViewMode build() {
    ref.onDispose(() => _disposed = true);

    _hydrate();

    // Grid until the stored value arrives, if there is one.
    return ProductViewMode.grid;
  }

  /// Switches the list's view mode and remembers the choice.
  ///
  /// Persistence hangs off this rather than off `listenSelf`, which was the
  /// first attempt: `listenSelf` also fires for the state `build` returns, so
  /// the notifier marked itself "touched" before hydration had even read the
  /// disk and then discarded every stored preference. Only an explicit call is
  /// a user choice.
  void setMode(ProductViewMode mode) {
    // Set before the equality check: choosing the mode you are already in is
    // still a choice, and it still has to win against an in-flight read.
    _touched = true;

    if (mode == state) return;
    state = mode;
    _persist(mode);
  }

  Future<void> _hydrate() async {
    final prefs = await _openPrefs();
    if (prefs == null || _touched || _disposed) return;

    final stored = prefs.getString(productViewModePrefsKey);
    if (stored == null) return;

    for (final mode in ProductViewMode.values) {
      if (mode.name == stored) {
        // Re-checked after the await: the user may have toggled while the read
        // was in flight.
        if (!_touched && !_disposed) state = mode;
        return;
      }
    }
  }

  Future<void> _persist(ProductViewMode mode) async {
    final prefs = await _openPrefs();
    await prefs?.setString(productViewModePrefsKey, mode.name);
  }

  /// `shared_preferences`, or null where the platform channel is unavailable.
  ///
  /// A widget test that pumps the list without calling
  /// `SharedPreferences.setMockInitialValues` gets a [MissingPluginException].
  /// That is not worth an unhandled error over a view toggle, so it degrades to
  /// "no stored preference" and the grid default stands.
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

/// Notifier for managing product selection state
class ProductSelectionNotifier extends StateNotifier<Set<String>> {
  ProductSelectionNotifier() : super({});

  void toggleSelection(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    } else {
      state = Set.from(state)..add(id);
    }
  }

  void select(String id) {
    if (!state.contains(id)) {
      state = Set.from(state)..add(id);
    }
  }

  void deselect(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    }
  }

  void selectAll(List<String> ids) {
    state = Set.from(ids);
  }

  void clearSelection() {
    state = {};
  }

  void selectMultiple(List<String> ids) {
    state = Set.from(state)..addAll(ids);
  }

  void deselectMultiple(List<String> ids) {
    state = Set.from(state)..removeAll(ids);
  }

  bool isSelected(String id) => state.contains(id);

  bool get hasSelection => state.isNotEmpty;

  int get selectionCount => state.length;
}

/// Which products are ticked.
///
/// `autoDispose`, so leaving the products screen clears the selection. Without
/// it a bulk selection outlived the screen: tick three products, go to the
/// dashboard, come back, and the bulk action bar was still there offering to
/// delete them. In a split view, where the master pane stays mounted behind the
/// detail, that stale state is visible for far longer.
final productSelectionProvider =
    StateNotifierProvider.autoDispose<ProductSelectionNotifier, Set<String>>(
  (ref) {
    return ProductSelectionNotifier();
  },
);

/// Whether every product currently on screen is selected.
///
/// Reads [paginatedProductsProvider] - what the list actually renders. It used
/// to read a separate `filteredProductsProvider` that ran its own client-side
/// filter over *all* products and ignored pagination entirely, so "select all"
/// answered a question about a result set nobody could see: on page 2 of a
/// filtered list the checkbox reported unticked with every visible row ticked,
/// and ticking it selected rows from page 1.
final allProductsSelectedProvider = Provider.autoDispose<bool>((ref) {
  final selectedIds = ref.watch(productSelectionProvider);
  final pageAsync = ref.watch(paginatedProductsProvider);

  return pageAsync.maybeWhen(
    data: (page) {
      if (page.items.isEmpty) return false;
      return page.items.every((p) => selectedIds.contains(p.id));
    },
    orElse: () => false,
  );
});

/// The selected products as entities, for the bulk action bar.
///
/// Same result set as [allProductsSelectedProvider], for the same reason.
final selectedProductsProvider = Provider.autoDispose<List<Product>>((ref) {
  final selectedIds = ref.watch(productSelectionProvider);
  final pageAsync = ref.watch(paginatedProductsProvider);

  return pageAsync.maybeWhen(
    data: (page) =>
        page.items.where((p) => selectedIds.contains(p.id)).toList(),
    orElse: () => [],
  );
});

/// Provider for selection count
final selectionCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(productSelectionProvider).length;
});
