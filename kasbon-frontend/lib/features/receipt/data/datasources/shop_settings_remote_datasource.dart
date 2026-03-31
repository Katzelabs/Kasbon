import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/shop_settings_model.dart';

/// Abstract interface for ShopSettings remote data source
abstract class ShopSettingsRemoteDataSource {
  Future<ShopSettingsModel> getShopSettings();
  Future<void> updateShopSettings(ShopSettingsModel settings);
}

/// Implementation of ShopSettingsRemoteDataSource using Supabase
class ShopSettingsRemoteDataSourceImpl implements ShopSettingsRemoteDataSource {
  final SupabaseClientProvider _provider;

  ShopSettingsRemoteDataSourceImpl(this._provider);

  @override
  Future<ShopSettingsModel> getShopSettings() async {
    try {
      final result = await _provider.client
          .from('shop_settings')
          .select()
          .maybeSingle();

      if (result == null) {
        throw const NotFoundException(
          message: 'Pengaturan toko tidak ditemukan',
        );
      }

      return ShopSettingsModel.fromJson(result);
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil pengaturan toko',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateShopSettings(ShopSettingsModel settings) async {
    try {
      final json = settings.toJson();
      json['user_id'] = _provider.requireUserId;

      await _provider.client
          .from('shop_settings')
          .upsert(json, onConflict: 'user_id');
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal memperbarui pengaturan toko',
        originalError: e,
      );
    }
  }
}
