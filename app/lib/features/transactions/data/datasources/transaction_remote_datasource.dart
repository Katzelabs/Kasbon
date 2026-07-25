import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/transaction_item_model.dart';
import '../models/transaction_model.dart';

/// Abstract interface for Transaction remote data source
abstract class TransactionRemoteDataSource {
  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
    List<TransactionItemModel> items,
  );
  Future<List<TransactionModel>> getTransactions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<TransactionModel> getTransactionById(String id);
  Future<List<TransactionItemModel>> getTransactionItems(String transactionId);
  Future<int> getTodayTransactionCount();
  Future<TransactionModel?> getTransactionByNumber(String transactionNumber);
  Future<List<TransactionModel>> getTransactionsByPaymentStatus(String status);
  Future<TransactionModel> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
  });
}

/// Implementation of TransactionRemoteDataSource using Supabase
class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final SupabaseClientProvider _provider;

  TransactionRemoteDataSourceImpl(this._provider);

  @override
  Future<TransactionModel> createTransaction(
    TransactionModel transaction,
    List<TransactionItemModel> items,
  ) async {
    try {
      final userId = _provider.requireUserId;

      // Use RPC for atomic transaction creation
      final result = await _provider.client.rpc('create_pos_transaction', params: {
        'p_user_id': userId,
        'p_transaction': transaction.toJson(),
        'p_items': items.map((i) => i.toJson()).toList(),
      });

      // The RPC returns the created transaction ID
      final txnId = result as String;
      return await getTransactionById(txnId);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal membuat transaksi',
        originalError: e,
      );
    }
  }

  @override
  Future<List<TransactionModel>> getTransactions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _provider.client
          .from('transactions')
          .select();

      if (startDate != null) {
        query = query.gte('transaction_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('transaction_date', endDate.toIso8601String());
      }

      dynamic result;
      var ordered = query.order('transaction_date', ascending: false);

      if (limit != null && offset != null) {
        result = await ordered.range(offset, offset + limit - 1);
      } else if (limit != null) {
        result = await ordered.limit(limit);
      } else {
        result = await ordered;
      }

      return (result as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil daftar transaksi',
        originalError: e,
      );
    }
  }

  @override
  Future<TransactionModel> getTransactionById(String id) async {
    try {
      final result = await _provider.client
          .from('transactions')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (result == null) {
        throw const NotFoundException(message: 'Transaksi tidak ditemukan');
      }

      return TransactionModel.fromJson(result);
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil transaksi',
        originalError: e,
      );
    }
  }

  @override
  Future<List<TransactionItemModel>> getTransactionItems(
      String transactionId) async {
    try {
      final result = await _provider.client
          .from('transaction_items')
          .select()
          .eq('transaction_id', transactionId);

      return result
          .map((json) => TransactionItemModel.fromJson(json))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil item transaksi',
        originalError: e,
      );
    }
  }

  @override
  Future<int> getTodayTransactionCount() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final result = await _provider.client
          .from('transactions')
          .select()
          .gte('transaction_date', startOfDay.toIso8601String())
          .lt('transaction_date', endOfDay.toIso8601String())
          .count(CountOption.exact);

      return result.count;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil jumlah transaksi hari ini',
        originalError: e,
      );
    }
  }

  @override
  Future<TransactionModel?> getTransactionByNumber(
      String transactionNumber) async {
    try {
      final result = await _provider.client
          .from('transactions')
          .select()
          .eq('transaction_number', transactionNumber)
          .maybeSingle();

      if (result == null) return null;
      return TransactionModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil transaksi',
        originalError: e,
      );
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionsByPaymentStatus(
      String status) async {
    try {
      var query = _provider.client
          .from('transactions')
          .select()
          .eq('payment_status', status);

      if (status == 'debt') {
        query = query.isFilter('debt_paid_at', null);
      }

      final result = await query.order('transaction_date', ascending: false);

      return (result as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil transaksi berdasarkan status',
        originalError: e,
      );
    }
  }

  @override
  Future<TransactionModel> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
  }) async {
    try {
      final updateMap = <String, dynamic>{};
      if (paymentStatus != null) {
        updateMap['payment_status'] = paymentStatus;
      }
      if (debtPaidAt != null) {
        updateMap['debt_paid_at'] = debtPaidAt.toIso8601String();
      }

      final result = await _provider.client
          .from('transactions')
          .update(updateMap)
          .eq('id', id)
          .select()
          .single();

      return TransactionModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal memperbarui transaksi',
        originalError: e,
      );
    }
  }
}
