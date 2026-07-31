import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/features/auth/domain/usecases/mark_onboarding_complete.dart';
import 'package:kasbon_pos/features/categories/domain/entities/category.dart';
import 'package:kasbon_pos/features/categories/domain/repositories/category_repository.dart';
import 'package:kasbon_pos/features/categories/domain/usecases/create_category.dart';
import 'package:kasbon_pos/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/domain/entities/product_filter.dart';
import 'package:kasbon_pos/features/products/domain/repositories/product_repository.dart';
import 'package:kasbon_pos/features/products/domain/usecases/create_product.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/receipt/domain/repositories/shop_settings_repository.dart';
import 'package:kasbon_pos/features/receipt/domain/usecases/get_shop_settings.dart';
import 'package:kasbon_pos/features/settings/domain/usecases/update_shop_settings.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_repositories.dart';

/// An in-memory stand-in for everything the wizard writes to.
///
/// Hand-written rather than mocktail for the three repositories the wizard
/// actually calls, because the assertions are about *what was written* - a
/// recorded value reads better in a test than an argument captor, and the
/// interfaces here are small enough to implement outright.
class FakeOnboardingBackend {
  /// When true, saving the shop fails - the branch that must keep the user on
  /// step 1 rather than advancing over a write that did not happen.
  bool failShopSave = false;

  String? savedShopName;
  String? savedBusinessType;
  final List<String> createdCategoryNames = [];
  final List<CreateProductParams> createdProducts = [];
  bool onboardingMarked = false;

  late final _shopSettings = _FakeShopSettingsRepository(this);
  late final _categories = _FakeCategoryRepository(this);
  late final _products = _FakeProductRepository(this);
  late final _auth = MockAuthRepository();

  OnboardingNotifier buildNotifier() {
    when(() => _auth.markOnboardingComplete()).thenAnswer((_) async {
      onboardingMarked = true;
      return const Right(null);
    });

    return OnboardingNotifier(
      getShopSettings: GetShopSettings(_shopSettings),
      updateShopSettings: UpdateShopSettings(_shopSettings),
      createCategory: CreateCategory(_categories),
      createProduct: CreateProduct(_products),
      markOnboardingComplete: MarkOnboardingComplete(_auth),
    );
  }
}

/// Overrides pointing the wizard at [backend], or at a fresh one.
List<Override> onboardingOverrides([FakeOnboardingBackend? backend]) {
  final target = backend ?? FakeOnboardingBackend();
  return <Override>[
    onboardingProvider.overrideWith((ref) => target.buildNotifier()),
  ];
}

class _FakeShopSettingsRepository implements ShopSettingsRepository {
  _FakeShopSettingsRepository(this._backend);

  final FakeOnboardingBackend _backend;

  @override
  Future<Either<Failure, ShopSettings>> getShopSettings() async {
    // Matches the real repository, which answers not-found with the default
    // entity rather than a failure.
    return Right(ShopSettings.defaultSettings());
  }

  @override
  Future<Either<Failure, void>> updateShopSettings(
    ShopSettings settings,
  ) async {
    if (_backend.failShopSave) {
      return const Left(DatabaseFailure(message: 'Gagal menyimpan'));
    }
    _backend.savedShopName = settings.name;
    _backend.savedBusinessType = settings.businessType;
    return const Right(null);
  }
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository(this._backend);

  final FakeOnboardingBackend _backend;

  @override
  Future<Either<Failure, Category>> createCategory(String name) async {
    _backend.createdCategoryNames.add(name);
    final now = DateTime(2026, 7, 31);
    return Right(Category(
      id: 'cat-${_backend.createdCategoryNames.length}',
      name: name,
      createdAt: now,
      updatedAt: now,
    ));
  }

  @override
  Future<Either<Failure, List<Category>>> getAllCategories() async =>
      const Right([]);

  @override
  Future<Either<Failure, Category>> getCategoryById(String id) async =>
      const Left(NotFoundFailure(message: 'not used'));
}

/// Only [createProduct] is reachable from the wizard; the rest of
/// [ProductRepository] is inherited from a mock so this fake stays readable.
class _FakeProductRepository extends Mock implements ProductRepository {
  _FakeProductRepository(this._backend);

  final FakeOnboardingBackend _backend;

  @override
  Future<Either<Failure, Product>> createProduct(Product product) async {
    _backend.createdProducts.add(CreateProductParams(
      name: product.name,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      stock: product.stock,
      categoryId: product.categoryId,
    ));
    return Right(product);
  }

  @override
  Future<Either<Failure, PaginatedResult<Product>>> getProductsPaginated(
    ProductFilter filter,
  ) async =>
      const Right(PaginatedResult(
        items: <Product>[],
        totalCount: 0,
        currentPage: 1,
        pageSize: 20,
      ));
}
