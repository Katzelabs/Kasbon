import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/shop_settings.dart';
import '../repositories/shop_settings_repository.dart';

/// Use case to get shop settings
///
/// Returns shop settings from the database.
/// If settings don't exist, returns default settings.
class GetShopSettings extends UseCaseNoParams<ShopSettings> {
  final ShopSettingsRepository repository;

  GetShopSettings(this.repository);

  @override
  Future<Either<Failure, ShopSettings>> call() async {
    return await repository.getShopSettings();
  }
}
