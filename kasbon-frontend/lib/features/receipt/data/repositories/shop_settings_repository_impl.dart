import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/shop_settings_repository.dart';
import '../datasources/shop_settings_remote_datasource.dart';
import '../models/shop_settings_model.dart';

/// Implementation of ShopSettingsRepository
class ShopSettingsRepositoryImpl implements ShopSettingsRepository {
  final ShopSettingsRemoteDataSource _remoteDataSource;

  ShopSettingsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ShopSettings>> getShopSettings() async {
    try {
      final settings = await _remoteDataSource.getShopSettings();
      return Right(settings.toEntity());
    } on NotFoundException {
      // Return default settings if not found
      return Right(ShopSettings.defaultSettings());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, void>> updateShopSettings(
      ShopSettings settings) async {
    try {
      await _remoteDataSource
          .updateShopSettings(ShopSettingsModel.fromEntity(settings));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }
}
