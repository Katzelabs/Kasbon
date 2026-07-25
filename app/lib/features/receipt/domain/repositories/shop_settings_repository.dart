import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/shop_settings.dart';

/// Abstract repository for ShopSettings
abstract class ShopSettingsRepository {
  /// Get the shop settings
  ///
  /// Returns default settings if not found in database.
  Future<Either<Failure, ShopSettings>> getShopSettings();

  /// Update shop settings
  Future<Either<Failure, void>> updateShopSettings(ShopSettings settings);
}
