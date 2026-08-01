import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/domain/usecases/get_shop_settings.dart';
import '../../domain/usecases/update_shop_settings.dart';

/// Provider for fetching shop settings
final shopSettingsProvider =
    FutureProvider.autoDispose<ShopSettings>((ref) async {
  final getShopSettings = getIt<GetShopSettings>();
  final result = await getShopSettings();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (settings) => settings,
  );
});

/// Trims a field and collapses the empty case to null.
///
/// The three settings forms all model optional columns as empty strings, while
/// the database and the receipt generator both distinguish "" from NULL - a
/// null footer prints the default "Terima kasih" line, an empty one prints a
/// blank. Every crossing of that boundary goes through here.
String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// State class for settings form
class SettingsFormState {
  /// The settings as last read from (or written to) the server.
  ///
  /// Null until the first load lands, which is what [isLoaded] reports. Holding
  /// it in the state rather than in a private notifier field is what lets the
  /// screens ask whether anything has actually changed.
  final ShopSettings? original;

  final String name;
  final String address;
  final String phone;
  final String receiptHeader;
  final String receiptFooter;
  final int lowStockThreshold;
  final int paymentProofRetentionDays;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const SettingsFormState({
    this.original,
    this.name = '',
    this.address = '',
    this.phone = '',
    this.receiptHeader = '',
    this.receiptFooter = '',
    this.lowStockThreshold = 5,
    this.paymentProofRetentionDays =
        ShopSettings.defaultPaymentProofRetentionDays,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  /// Whether the settings have arrived and the form can be rendered.
  bool get isLoaded => original != null;

  /// Whether the load failed with nothing to fall back on.
  ///
  /// A save error leaves [original] populated - the form is still usable and
  /// the message belongs in a toast, not in a full-screen error state.
  bool get hasLoadError => error != null && !isLoaded;

  /// Whether the shop identity fields differ from what was loaded.
  ///
  /// Split per section rather than exposed as one flag: editing the receipt
  /// footer must not light up Simpan on the shop profile screen, and it must
  /// not make backing out of that screen ask about discarding changes.
  bool get isShopProfileDirty {
    final o = original;
    if (o == null) return false;
    return _nullIfBlank(name) != _nullIfBlank(o.name) ||
        _nullIfBlank(address) != _nullIfBlank(o.address ?? '') ||
        _nullIfBlank(phone) != _nullIfBlank(o.phone ?? '');
  }

  /// Whether the receipt header or footer differ from what was loaded.
  bool get isReceiptDirty {
    final o = original;
    if (o == null) return false;
    return _nullIfBlank(receiptHeader) != _nullIfBlank(o.receiptHeader ?? '') ||
        _nullIfBlank(receiptFooter) != _nullIfBlank(o.receiptFooter ?? '');
  }

  /// Whether anything on the app-settings screen differs from what was loaded.
  bool get isAppSettingsDirty {
    final o = original;
    if (o == null) return false;
    return lowStockThreshold != o.lowStockThreshold ||
        paymentProofRetentionDays != o.paymentProofRetentionDays;
  }

  SettingsFormState copyWith({
    ShopSettings? original,
    String? name,
    String? address,
    String? phone,
    String? receiptHeader,
    String? receiptFooter,
    int? lowStockThreshold,
    int? paymentProofRetentionDays,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return SettingsFormState(
      original: original ?? this.original,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      paymentProofRetentionDays:
          paymentProofRetentionDays ?? this.paymentProofRetentionDays,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      // Deliberately not `?? this.error`: every state transition either sets a
      // fresh message or clears the last one, and a sticky error would outlive
      // the failure that produced it.
      error: error,
    );
  }

  /// Create form state from ShopSettings entity
  factory SettingsFormState.fromSettings(ShopSettings settings) {
    return SettingsFormState(
      original: settings,
      name: settings.name,
      address: settings.address ?? '',
      phone: settings.phone ?? '',
      receiptHeader: settings.receiptHeader ?? '',
      receiptFooter: settings.receiptFooter ?? '',
      lowStockThreshold: settings.lowStockThreshold,
      paymentProofRetentionDays: settings.paymentProofRetentionDays,
    );
  }
}

/// Notifier for managing settings form state
class SettingsFormNotifier extends StateNotifier<SettingsFormState> {
  final Ref _ref;

  /// Loads immediately on construction.
  ///
  /// The three form screens used to each kick this off from a post-frame
  /// callback with `isLoading` defaulting to false, so the first frame rendered
  /// an empty form, the second a spinner, and only the third the real values -
  /// a visible flash of blank fields on every visit. Starting in the loading
  /// state means a screen never has a frame where it has to draw fields it does
  /// not have values for.
  SettingsFormNotifier(this._ref)
      : super(const SettingsFormState(isLoading: true)) {
    loadSettings();
  }

  /// Initialize form with existing settings
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final getShopSettings = getIt<GetShopSettings>();
      final result = await getShopSettings();
      if (!mounted) return;

      result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
        },
        (settings) {
          state = SettingsFormState.fromSettings(settings);
        },
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update shop name
  void setName(String value) {
    state = state.copyWith(name: value, error: null);
  }

  /// Update shop address
  void setAddress(String value) {
    state = state.copyWith(address: value, error: null);
  }

  /// Update shop phone
  void setPhone(String value) {
    state = state.copyWith(phone: value, error: null);
  }

  /// Update receipt header
  void setReceiptHeader(String value) {
    state = state.copyWith(receiptHeader: value, error: null);
  }

  /// Update receipt footer
  void setReceiptFooter(String value) {
    state = state.copyWith(receiptFooter: value, error: null);
  }

  /// Update low stock threshold.
  ///
  /// Clamped rather than ignored below 1: the stepper and the preset chips are
  /// both bounded inputs, so a value outside the range is a programming error,
  /// not something the user can type. Silently dropping it used to leave the
  /// field and the state showing different numbers.
  void setLowStockThreshold(int value) {
    final clamped = value.clamp(1, 9999);
    state = state.copyWith(lowStockThreshold: clamped, error: null);
  }

  /// Update how long payment proofs are kept.
  ///
  /// Clamped to the range the database CHECK enforces, for the same reason as
  /// the threshold above: both inputs are bounded, so an out-of-range value is
  /// a programming error rather than something a user typed - and letting it
  /// reach Supabase would turn it into a save failure with an opaque message.
  void setPaymentProofRetentionDays(int value) {
    final clamped = value.clamp(
      ShopSettings.minPaymentProofRetentionDays,
      ShopSettings.maxPaymentProofRetentionDays,
    );
    state = state.copyWith(paymentProofRetentionDays: clamped, error: null);
  }

  /// Validate shop profile form
  String? validateShopProfile() {
    if (state.name.trim().isEmpty) {
      return 'Nama toko tidak boleh kosong';
    }
    return null;
  }

  /// Validate app settings form
  String? validateAppSettings() {
    if (state.lowStockThreshold < 1) {
      return 'Batas stok minimum harus minimal 1';
    }
    return null;
  }

  /// Save shop profile settings
  Future<bool> saveShopProfile() async {
    final validationError = validateShopProfile();
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return false;
    }

    return _saveSettings();
  }

  /// Save receipt settings
  Future<bool> saveReceiptSettings() async {
    return _saveSettings();
  }

  /// Save app settings
  Future<bool> saveAppSettings() async {
    final validationError = validateAppSettings();
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return false;
    }

    return _saveSettings();
  }

  /// Internal method to save settings
  Future<bool> _saveSettings() async {
    final original = state.original;
    if (original == null) {
      state = state.copyWith(error: 'Pengaturan belum dimuat');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final updateShopSettings = getIt<UpdateShopSettings>();

      // Built field by field rather than through `original.copyWith`, which
      // coalesces with `??` and therefore cannot express "clear this column".
      // Passing a null address there meant *keep the old address*, so emptying
      // a phone number or a receipt footer appeared to save and came back on
      // the next load. `toJson` does write the nulls; only copyWith swallowed
      // them.
      final updatedSettings = ShopSettings(
        id: original.id,
        name: state.name.trim(),
        // Carried from `original` because nothing on either settings screen
        // edits it - it is chosen once during onboarding. Omitting it here did
        // not leave it alone: the constructor defaulted it to null and `toJson`
        // writes nulls, so saving a receipt footer silently cleared the shop's
        // trade.
        businessType: original.businessType,
        address: _nullIfBlank(state.address),
        phone: _nullIfBlank(state.phone),
        logoUrl: original.logoUrl,
        receiptHeader: _nullIfBlank(state.receiptHeader),
        receiptFooter: _nullIfBlank(state.receiptFooter),
        currency: original.currency,
        lowStockThreshold: state.lowStockThreshold,
        paymentProofRetentionDays: state.paymentProofRetentionDays,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await updateShopSettings(updatedSettings);
      if (!mounted) return false;

      return result.fold(
        (failure) {
          state = state.copyWith(isSaving: false, error: failure.message);
          return false;
        },
        (_) {
          // Rebuilt from what was written, so the trimmed and nulled values the
          // server now holds become the new baseline and the form reads clean.
          state = SettingsFormState.fromSettings(updatedSettings);
          // Invalidate the settings provider to refresh data
          _ref.invalidate(shopSettingsProvider);
          return true;
        },
      );
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

/// Provider for settings form state
final settingsFormProvider =
    StateNotifierProvider.autoDispose<SettingsFormNotifier, SettingsFormState>(
  (ref) => SettingsFormNotifier(ref),
);
