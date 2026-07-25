import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/get_transaction.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/usecases/get_shop_settings.dart';

/// Data class containing receipt information
class ReceiptData {
  /// The transaction for this receipt
  final Transaction transaction;

  /// Shop settings for receipt header/footer
  final ShopSettings shopSettings;

  /// Generated receipt text (42-char wide format)
  final String receiptText;

  const ReceiptData({
    required this.transaction,
    required this.shopSettings,
    required this.receiptText,
  });
}

/// Provider to fetch and generate receipt data
///
/// Takes a transaction ID and:
/// 1. Fetches the transaction with all items
/// 2. Fetches shop settings (with fallback to defaults)
/// 3. Generates the receipt text
///
/// Usage:
/// ```dart
/// final receiptAsync = ref.watch(receiptProvider(transactionId));
/// receiptAsync.when(
///   data: (receiptData) => ReceiptPreviewWidget(receiptText: receiptData.receiptText),
///   loading: () => ModernLoading(),
///   error: (error, _) => ModernErrorState(message: error.toString()),
/// );
/// ```
final receiptProvider = FutureProvider.autoDispose
    .family<ReceiptData, String>((ref, transactionId) async {
  // Fetch transaction with items
  final getTransaction = getIt<GetTransactionById>();
  final transactionResult = await getTransaction(
    GetTransactionByIdParams(id: transactionId),
  );

  final transaction = transactionResult.fold(
    (failure) => throw Exception(failure.message),
    (transaction) => transaction,
  );

  // Fetch shop settings (with default fallback)
  final getShopSettings = getIt<GetShopSettings>();
  final settingsResult = await getShopSettings();

  final shopSettings = settingsResult.fold(
    (failure) => ShopSettings.defaultSettings(),
    (settings) => settings,
  );

  // Generate receipt text
  final receiptText = ReceiptGenerator.generate(
    transaction: transaction,
    shopSettings: shopSettings,
  );

  return ReceiptData(
    transaction: transaction,
    shopSettings: shopSettings,
    receiptText: receiptText,
  );
});

/// Provider to generate receipt text for a given transaction
///
/// Used when you already have the transaction object (e.g., on success screen).
/// Uses default shop settings for simplicity.
///
/// Usage:
/// ```dart
/// final receiptText = ref.watch(receiptTextFromTransactionProvider(transaction));
/// ```
final receiptTextFromTransactionProvider = Provider.autoDispose
    .family<String, Transaction>((ref, transaction) {
  // Use default settings for immediate receipt generation
  final shopSettings = ShopSettings.defaultSettings();

  return ReceiptGenerator.generate(
    transaction: transaction,
    shopSettings: shopSettings,
  );
});
