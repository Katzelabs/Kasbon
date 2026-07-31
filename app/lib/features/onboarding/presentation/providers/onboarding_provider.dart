import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../auth/domain/usecases/mark_onboarding_complete.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/usecases/create_category.dart';
import '../../../products/domain/usecases/create_product.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/domain/usecases/get_shop_settings.dart';
import '../../../settings/domain/usecases/update_shop_settings.dart';
import '../../domain/entities/business_type.dart';

/// Which step of the wizard is on screen.
enum OnboardingStep { shop, categories, product }

/// State of the onboarding wizard.
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.shop,
    this.shopName = '',
    this.businessType,
    this.selectedCategories = const <String>{},
    this.createdCategories = const <Category>[],
    this.isSaving = false,
    this.errorMessage,
  });

  final OnboardingStep step;
  final String shopName;
  final BusinessType? businessType;

  /// Category names ticked on step 2.
  final Set<String> selectedCategories;

  /// What step 2 actually created, so step 3 can offer them in a picker
  /// without another round trip.
  final List<Category> createdCategories;

  final bool isSaving;
  final String? errorMessage;

  /// Step 1 is the only one that blocks. Everything after it is skippable, so
  /// a user who wants to get to the till can.
  bool get canLeaveShopStep => shopName.trim().length >= 2 && businessType != null;

  OnboardingState copyWith({
    OnboardingStep? step,
    String? shopName,
    BusinessType? businessType,
    Set<String>? selectedCategories,
    List<Category>? createdCategories,
    bool? isSaving,
    String? errorMessage,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      shopName: shopName ?? this.shopName,
      businessType: businessType ?? this.businessType,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      createdCategories: createdCategories ?? this.createdCategories,
      isSaving: isSaving ?? this.isSaving,
      // Not merged with `??`: every step opens by clearing the last failure,
      // and an error that outlived the attempt that produced it would be shown
      // against the next one.
      errorMessage: errorMessage,
    );
  }
}

/// Drives the onboarding wizard.
///
/// Writes at the end of each step rather than all at once at the end. A user
/// who abandons on step 2 still has a named shop, which is the single thing
/// the app cannot function without - `shop_settings.name` is NOT NULL and
/// nothing else creates that row.
///
/// Every write goes through a use case that already exists. Nothing here talks
/// to Supabase: `UpdateShopSettings` upserts on `user_id` so it creates the row
/// as readily as it edits one, and `CreateCategory` is find-or-create, so
/// stepping backwards and forwards cannot leave duplicates behind.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier({
    required GetShopSettings getShopSettings,
    required UpdateShopSettings updateShopSettings,
    required CreateCategory createCategory,
    required CreateProduct createProduct,
    required MarkOnboardingComplete markOnboardingComplete,
  })  : _getShopSettings = getShopSettings,
        _updateShopSettings = updateShopSettings,
        _createCategory = createCategory,
        _createProduct = createProduct,
        _markOnboardingComplete = markOnboardingComplete,
        super(const OnboardingState());

  final GetShopSettings _getShopSettings;
  final UpdateShopSettings _updateShopSettings;
  final CreateCategory _createCategory;
  final CreateProduct _createProduct;
  final MarkOnboardingComplete _markOnboardingComplete;

  void setShopName(String value) {
    state = state.copyWith(shopName: value);
  }

  void setBusinessType(BusinessType type) {
    // Re-tick the new trade's starters. Anything the user typed themselves is
    // kept: switching from Warung Makan to Kedai Kopi should not silently
    // delete "Gorengan".
    final custom = state.selectedCategories.where(
      (name) => !(state.businessType?.starterCategories.contains(name) ?? false),
    );

    state = state.copyWith(
      businessType: type,
      selectedCategories: {...type.starterCategories, ...custom},
    );
  }

  void toggleCategory(String name) {
    final next = Set<String>.from(state.selectedCategories);
    if (!next.remove(name)) next.add(name);
    state = state.copyWith(selectedCategories: next);
  }

  void addCustomCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      selectedCategories: {...state.selectedCategories, trimmed},
    );
  }

  void goToStep(OnboardingStep step) {
    state = state.copyWith(step: step, errorMessage: null);
  }

  /// Persist the shop and advance. False leaves the user on step 1.
  Future<bool> saveShopAndContinue() async {
    if (!state.canLeaveShopStep) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    // Read first: the row may already exist if the user came back through the
    // wizard, and writing a bare entity would blank the columns they had
    // filled in elsewhere. `getShopSettings` never returns not-found - it
    // answers with `ShopSettings.defaultSettings()` - so this is safe for a
    // brand-new account too.
    final existing = await _getShopSettings();

    final current = existing.fold<ShopSettings?>((_) => null, (s) => s);
    if (current == null) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Gagal memuat pengaturan toko',
      );
      return false;
    }

    final result = await _updateShopSettings(
      current.copyWith(
        name: state.shopName.trim(),
        businessType: state.businessType!.id,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isSaving: false,
          step: OnboardingStep.categories,
        );
        return true;
      },
    );
  }

  /// Create the ticked categories and advance.
  ///
  /// One call per category: there are four or five of them, and a batch
  /// endpoint would mean widening the repository, the datasource and both
  /// interfaces to save a few hundred milliseconds once per account.
  Future<bool> saveCategoriesAndContinue() async {
    if (state.selectedCategories.isEmpty) {
      state = state.copyWith(step: OnboardingStep.product, errorMessage: null);
      return true;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    final created = <Category>[];
    for (final name in state.selectedCategories) {
      final result = await _createCategory(CreateCategoryParams(name: name));

      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      }
      result.fold((_) {}, created.add);
    }

    state = state.copyWith(
      isSaving: false,
      step: OnboardingStep.product,
      createdCategories: created,
    );
    return true;
  }

  /// Create the first product. Skipped by passing nothing - see
  /// [finish].
  Future<bool> saveProduct({
    required String name,
    required double costPrice,
    required double sellingPrice,
    required int stock,
    String? categoryId,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    final result = await _createProduct(CreateProductParams(
      name: name.trim(),
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      stock: stock,
      categoryId: categoryId,
    ));

    return result.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isSaving: false);
        return true;
      },
    );
  }

  /// Stamp the account as onboarded.
  ///
  /// Must succeed *before* the caller navigates: the router gate reads this
  /// marker, so leaving the wizard without it sends the user straight back
  /// here.
  Future<bool> finish() async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    final result = await _markOnboardingComplete();

    return result.fold(
      (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isSaving: false);
        return true;
      },
    );
  }
}

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(
    getShopSettings: getIt<GetShopSettings>(),
    updateShopSettings: getIt<UpdateShopSettings>(),
    createCategory: getIt<CreateCategory>(),
    createProduct: getIt<CreateProduct>(),
    markOnboardingComplete: getIt<MarkOnboardingComplete>(),
  ),
);
