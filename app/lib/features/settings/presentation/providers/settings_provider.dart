import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/domain/usecases/get_shop_settings.dart';
import '../../domain/usecases/update_shop_settings.dart';

/// Provider for fetching shop settings
final shopSettingsProvider = FutureProvider.autoDispose<ShopSettings>((ref) async {
  final getShopSettings = getIt<GetShopSettings>();
  final result = await getShopSettings();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (settings) => settings,
  );
});

/// State class for settings form
class SettingsFormState {
  final String name;
  final String address;
  final String phone;
  final String receiptHeader;
  final String receiptFooter;
  final int lowStockThreshold;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const SettingsFormState({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.receiptHeader = '',
    this.receiptFooter = '',
    this.lowStockThreshold = 5,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  SettingsFormState copyWith({
    String? name,
    String? address,
    String? phone,
    String? receiptHeader,
    String? receiptFooter,
    int? lowStockThreshold,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return SettingsFormState(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  /// Create form state from ShopSettings entity
  factory SettingsFormState.fromSettings(ShopSettings settings) {
    return SettingsFormState(
      name: settings.name,
      address: settings.address ?? '',
      phone: settings.phone ?? '',
      receiptHeader: settings.receiptHeader ?? '',
      receiptFooter: settings.receiptFooter ?? '',
      lowStockThreshold: settings.lowStockThreshold,
    );
  }
}

/// Notifier for managing settings form state
class SettingsFormNotifier extends StateNotifier<SettingsFormState> {
  final Ref _ref;
  ShopSettings? _originalSettings;

  SettingsFormNotifier(this._ref) : super(const SettingsFormState());

  /// Initialize form with existing settings
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final getShopSettings = getIt<GetShopSettings>();
      final result = await getShopSettings();

      result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
        },
        (settings) {
          _originalSettings = settings;
          state = SettingsFormState.fromSettings(settings);
        },
      );
    } catch (e) {
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

  /// Update low stock threshold
  void setLowStockThreshold(int value) {
    if (value >= 1) {
      state = state.copyWith(lowStockThreshold: value, error: null);
    }
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
    if (_originalSettings == null) {
      state = state.copyWith(error: 'Pengaturan belum dimuat');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final updateShopSettings = getIt<UpdateShopSettings>();

      final updatedSettings = _originalSettings!.copyWith(
        name: state.name.trim(),
        address: state.address.trim().isEmpty ? null : state.address.trim(),
        phone: state.phone.trim().isEmpty ? null : state.phone.trim(),
        receiptHeader: state.receiptHeader.trim().isEmpty ? null : state.receiptHeader.trim(),
        receiptFooter: state.receiptFooter.trim().isEmpty ? null : state.receiptFooter.trim(),
        lowStockThreshold: state.lowStockThreshold,
        updatedAt: DateTime.now(),
      );

      final result = await updateShopSettings(updatedSettings);

      return result.fold(
        (failure) {
          state = state.copyWith(isSaving: false, error: failure.message);
          return false;
        },
        (_) {
          _originalSettings = updatedSettings;
          state = state.copyWith(isSaving: false);
          // Invalidate the settings provider to refresh data
          _ref.invalidate(shopSettingsProvider);
          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

/// Provider for settings form state
final settingsFormProvider = StateNotifierProvider.autoDispose<SettingsFormNotifier, SettingsFormState>(
  (ref) => SettingsFormNotifier(ref),
);
