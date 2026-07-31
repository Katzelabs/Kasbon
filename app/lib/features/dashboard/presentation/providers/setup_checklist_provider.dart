import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/di/injection.dart';
import '../../../products/domain/entities/product_filter.dart';
import '../../../products/domain/usecases/get_paginated_products.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/domain/usecases/get_shop_settings.dart';
import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_provider.dart';

/// One row of the "Lengkapi tokomu" card.
class SetupChecklistItem {
  const SetupChecklistItem({
    required this.label,
    required this.route,
    required this.isDone,
  });

  final String label;
  final String route;
  final bool isDone;
}

/// What the shop still has not set up.
class SetupChecklist {
  const SetupChecklist(this.items);

  final List<SetupChecklistItem> items;

  int get doneCount => items.where((item) => item.isDone).length;
  bool get isComplete => doneCount == items.length;
}

/// Counts the products this account has, without touching the products
/// screen's filter.
///
/// Deliberately not `paginatedProductsProvider`: that one watches
/// `productFilterProvider`, so a search term typed on the products screen would
/// silently change what the dashboard counts. This asks for page one of an
/// unfiltered query purely for its `totalCount`.
final _productCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final result = await getIt<GetPaginatedProducts>()(
    const ProductFilter(pageSize: 1),
  );
  return result.fold((_) => 0, (page) => page.totalCount);
});

final _checklistShopSettingsProvider =
    FutureProvider.autoDispose<ShopSettings?>((ref) async {
  final result = await getIt<GetShopSettings>()();
  return result.fold((_) => null, (settings) => settings);
});

/// Whether the user has dismissed the card on this device.
///
/// Device-local rather than account state: dismissing a nudge is a preference
/// about this screen, not a fact about the shop, and someone who wants it gone
/// on their phone may still want it on the tablet they do paperwork on.
final setupChecklistDismissedProvider =
    StateNotifierProvider<SetupChecklistDismissal, bool>(
  (ref) => SetupChecklistDismissal()..load(),
);

class SetupChecklistDismissal extends StateNotifier<bool> {
  SetupChecklistDismissal() : super(false);

  static const _key = 'setup_checklist_dismissed';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> dismiss() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

/// The checklist itself.
///
/// Every item is derived from data the app already has a use case for, and
/// every one links somewhere that can actually complete it - which is why
/// "upload logo toko" is absent despite `shop_settings.logo_url` existing:
/// there is no logo field on the shop profile screen for it to point at.
final setupChecklistProvider =
    FutureProvider.autoDispose<SetupChecklist>((ref) async {
  final settings = await ref.watch(_checklistShopSettingsProvider.future);
  final productCount = await ref.watch(_productCountProvider.future);

  DashboardSummary? summary;
  try {
    summary = await ref.watch(dashboardSummaryProvider.future);
  } catch (_) {
    // A failed summary should cost the user one tick, not the whole card.
    summary = null;
  }

  bool filled(String? value) => value != null && value.trim().isNotEmpty;

  return SetupChecklist([
    SetupChecklistItem(
      label: 'Lengkapi alamat & telepon toko',
      route: '/settings/shop-profile',
      isDone: filled(settings?.address) && filled(settings?.phone),
    ),
    SetupChecklistItem(
      label: 'Atur catatan pada struk',
      route: '/settings/receipt',
      isDone: filled(settings?.receiptFooter),
    ),
    SetupChecklistItem(
      label: 'Tambah 5 produk',
      route: '/products/add',
      isDone: productCount >= 5,
    ),
    SetupChecklistItem(
      label: 'Catat transaksi pertama',
      route: '/pos',
      isDone: (summary?.transactionCount ?? 0) > 0,
    ),
  ]);
});
