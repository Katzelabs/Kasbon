import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/query_limits.dart';
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
  Future<List<TransactionModel>> getTransactionsByPaymentStatus(
    String status, {
    int? limit,
    int? offset,
  });
  Future<TransactionModel> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
    String? paymentProofPath,
    DateTime? paymentConfirmedAt,
    String? paymentConfirmedBy,
  });

  /// Write NULL over `payment_proof_path`.
  ///
  /// Its own method because [updateTransaction] cannot express this: null there
  /// means "leave this column alone", which is what stops two concurrent
  /// writers clobbering each other's fields. Overloading null to also mean
  /// "erase" would make the two indistinguishable.
  Future<TransactionModel> clearPaymentProof(String id);

  /// Distinct customer names for the current user, most recently used first.
  Future<List<String>> getCustomerNames({String? query, int limit});
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
      // `id` as a tiebreaker, for the same reason as in
      // `getTransactionsByPaymentStatus`: `transaction_date` is not unique, and
      // rows tied on it have no stable position across the `.range()` requests
      // the history list makes while scrolling.
      var ordered = query
          .order('transaction_date', ascending: false)
          .order('id', ascending: false);

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
          .eq('transaction_id', transactionId)
          .limit(QueryLimits.transactionItemsCap);

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
    String status, {
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _provider.client
          .from('transactions')
          .select()
          .eq('payment_status', status);

      if (status == 'debt') {
        query = query.isFilter('debt_paid_at', null);
      }

      // Ordered by date and then by id. The date alone is not a total order -
      // two sales in the same second tie - and a tie has no defined position
      // between two `.range()` requests, so a paging caller could see one row
      // twice and miss another. `id` breaks the tie deterministically.
      final ordered = query
          .order('transaction_date', ascending: false)
          .order('id', ascending: false);

      final dynamic result;
      if (limit != null) {
        final start = offset ?? 0;
        result = await ordered.range(start, start + limit - 1);
      } else {
        result = await ordered;
      }

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
    String? paymentProofPath,
    DateTime? paymentConfirmedAt,
    String? paymentConfirmedBy,
  }) async {
    try {
      // Each field is only sent when the caller named it, so two callers
      // touching different fields on the same row cannot clobber each other.
      // A whole-model update here would have the proof upload - which finishes
      // seconds after the sale - write back a stale copy of every other column.
      final updateMap = <String, dynamic>{};
      if (paymentStatus != null) {
        updateMap['payment_status'] = paymentStatus;
      }
      if (debtPaidAt != null) {
        updateMap['debt_paid_at'] = debtPaidAt.toIso8601String();
      }
      if (paymentProofPath != null) {
        updateMap['payment_proof_path'] = paymentProofPath;
      }
      if (paymentConfirmedAt != null) {
        updateMap['payment_confirmed_at'] = paymentConfirmedAt.toIso8601String();
      }
      if (paymentConfirmedBy != null) {
        updateMap['payment_confirmed_by'] = paymentConfirmedBy;
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

  @override
  Future<TransactionModel> clearPaymentProof(String id) async {
    try {
      // Only this one column. The confirmation fields stay: the cashier did
      // look at the customer's screen, and removing the photograph removes the
      // evidence, not the fact that a human affirmed the money arrived.
      final result = await _provider.client
          .from('transactions')
          .update({'payment_proof_path': null})
          .eq('id', id)
          .select()
          .single();

      return TransactionModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal menghapus bukti pembayaran',
        originalError: e,
      );
    }
  }

  @override
  Future<List<String>> getCustomerNames({String? query, int limit = 20}) async {
    try {
      // An RPC rather than a select: PostgREST has no DISTINCT, so the
      // alternative is pulling every transaction back and deduping on the
      // client - which grows with the shop's history to answer a question
      // whose answer is a handful of names.
      final result = await _provider.client.rpc(
        'get_customer_names',
        params: {'p_query': query, 'p_limit': limit},
      );

      return (result as List<dynamic>).cast<String>();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal memuat nama pelanggan',
        originalError: e,
      );
    }
  }
}
