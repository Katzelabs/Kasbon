import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_item.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_item_model.dart';
import '../models/transaction_model.dart';

/// Implementation of TransactionRepository
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource _remoteDataSource;

  TransactionRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, Transaction>> createTransaction(
    Transaction transaction,
    List<TransactionItem> items,
  ) async {
    try {
      final transactionModel = TransactionModel.fromEntity(transaction);
      final itemModels =
          items.map((item) => TransactionItemModel.fromEntity(item)).toList();

      final result = await _remoteDataSource.createTransaction(
        transactionModel,
        itemModels,
      );

      // Return the transaction with items
      return Right(result.toEntity(items: items));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final models = await _remoteDataSource.getTransactions(
        limit: limit,
        offset: offset,
        startDate: startDate,
        endDate: endDate,
      );

      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Transaction>> getTransactionById(String id) async {
    try {
      final transactionModel = await _remoteDataSource.getTransactionById(id);
      final itemModels = await _remoteDataSource.getTransactionItems(id);
      final items = itemModels.map((m) => m.toEntity()).toList();

      return Right(transactionModel.toEntity(items: items));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, int>> getTodayTransactionCount() async {
    try {
      final count = await _remoteDataSource.getTodayTransactionCount();
      return Right(count);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactionsByPaymentStatus(
    String status, {
    int? limit,
    int? offset,
  }) async {
    try {
      final models = await _remoteDataSource.getTransactionsByPaymentStatus(
        status,
        limit: limit,
        offset: offset,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Transaction>> updateTransaction(
    String id, {
    String? paymentStatus,
    DateTime? debtPaidAt,
    String? paymentProofPath,
    DateTime? paymentConfirmedAt,
    String? paymentConfirmedBy,
  }) async {
    try {
      final model = await _remoteDataSource.updateTransaction(
        id,
        paymentStatus: paymentStatus,
        debtPaidAt: debtPaidAt,
        paymentProofPath: paymentProofPath,
        paymentConfirmedAt: paymentConfirmedAt,
        paymentConfirmedBy: paymentConfirmedBy,
      );

      final itemModels = await _remoteDataSource.getTransactionItems(id);
      final items = itemModels.map((m) => m.toEntity()).toList();

      return Right(model.toEntity(items: items));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<String>>> getCustomerNames({
    String? query,
    int limit = 20,
  }) async {
    try {
      final names = await _remoteDataSource.getCustomerNames(
        query: query,
        limit: limit,
      );
      return Right(names);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }
}
