import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../../../receipt/domain/repositories/shop_settings_repository.dart';

/// Use case to update shop settings
///
/// Takes updated ShopSettings and persists to database.
class UpdateShopSettings extends UseCase<void, ShopSettings> {
  final ShopSettingsRepository repository;

  UpdateShopSettings(this.repository);

  @override
  Future<Either<Failure, void>> call(ShopSettings params) async {
    return await repository.updateShopSettings(params);
  }
}
