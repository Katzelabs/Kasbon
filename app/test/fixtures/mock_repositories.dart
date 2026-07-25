import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kasbon_pos/core/errors/failures.dart';
import 'package:kasbon_pos/core/entities/paginated_result.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/products/domain/entities/product_filter.dart';
import 'package:kasbon_pos/features/products/domain/repositories/product_repository.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction_item.dart';
import 'package:kasbon_pos/features/transactions/domain/repositories/transaction_repository.dart';

/// Mock implementation of ProductRepository using Mocktail
class MockProductRepository extends Mock implements ProductRepository {}

/// Mock implementation of TransactionRepository using Mocktail
class MockTransactionRepository extends Mock implements TransactionRepository {}

/// Register fallback values for mocktail
void registerMocktailFallbackValues() {
  // Register fallback values for Product
  registerFallbackValue(Product(
    id: 'fallback',
    sku: 'SKU-FALLBACK',
    name: 'Fallback Product',
    costPrice: 0,
    sellingPrice: 0,
    stock: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));

  // Register fallback values for ProductFilter
  registerFallbackValue(const ProductFilter());

  // Register fallback values for Transaction
  registerFallbackValue(Transaction(
    id: 'fallback',
    transactionNumber: 'TRX-FALLBACK',
    subtotal: 0,
    total: 0,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.paid,
    transactionDate: DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));

  // Register fallback values for List<TransactionItem>
  registerFallbackValue(<TransactionItem>[]);
}

/// Helper extension for stubbing ProductRepository methods
extension MockProductRepositoryExtension on MockProductRepository {
  /// Stubs getAllProducts to return success with given products
  void stubGetAllProductsSuccess(List<Product> products) {
    when(() => getAllProducts()).thenAnswer((_) async => Right(products));
  }

  /// Stubs getAllProducts to return failure
  void stubGetAllProductsFailure(Failure failure) {
    when(() => getAllProducts()).thenAnswer((_) async => Left(failure));
  }

  /// Stubs getProductsPaginated to return success
  void stubGetProductsPaginatedSuccess(List<Product> products, {int total = 0}) {
    when(() => getProductsPaginated(any())).thenAnswer((_) async => Right(
          PaginatedResult(
            items: products,
            totalCount: total > 0 ? total : products.length,
            currentPage: 1,
            pageSize: 20,
          ),
        ));
  }

  /// Stubs getProductsPaginated to return failure
  void stubGetProductsPaginatedFailure(Failure failure) {
    when(() => getProductsPaginated(any())).thenAnswer((_) async => Left(failure));
  }

  /// Stubs getProductById to return success
  void stubGetProductByIdSuccess(Product product) {
    when(() => getProductById(any())).thenAnswer((_) async => Right(product));
  }

  /// Stubs getProductById to return failure
  void stubGetProductByIdFailure(Failure failure) {
    when(() => getProductById(any())).thenAnswer((_) async => Left(failure));
  }

  /// Stubs searchProducts to return success
  void stubSearchProductsSuccess(List<Product> products) {
    when(() => searchProducts(any())).thenAnswer((_) async => Right(products));
  }

  /// Stubs createProduct to return success
  void stubCreateProductSuccess(Product product) {
    when(() => createProduct(any())).thenAnswer((_) async => Right(product));
  }

  /// Stubs updateProduct to return success
  void stubUpdateProductSuccess(Product product) {
    when(() => updateProduct(any())).thenAnswer((_) async => Right(product));
  }

  /// Stubs deleteProduct to return success
  void stubDeleteProductSuccess() {
    when(() => deleteProduct(any())).thenAnswer((_) async => const Right(unit));
  }

  /// Stubs getLowStockProducts to return success
  void stubGetLowStockProductsSuccess(List<Product> products) {
    when(() => getLowStockProducts()).thenAnswer((_) async => Right(products));
  }
}

/// Helper extension for stubbing TransactionRepository methods
extension MockTransactionRepositoryExtension on MockTransactionRepository {
  /// Stubs getTransactions to return success
  void stubGetTransactionsSuccess(List<Transaction> transactions) {
    when(() => getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => Right(transactions));
  }

  /// Stubs getTransactions to return failure
  void stubGetTransactionsFailure(Failure failure) {
    when(() => getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => Left(failure));
  }

  /// Stubs getTransactionById to return success
  void stubGetTransactionByIdSuccess(Transaction transaction) {
    when(() => getTransactionById(any()))
        .thenAnswer((_) async => Right(transaction));
  }

  /// Stubs getTransactionById to return failure
  void stubGetTransactionByIdFailure(Failure failure) {
    when(() => getTransactionById(any())).thenAnswer((_) async => Left(failure));
  }

  /// Stubs createTransaction to return success
  void stubCreateTransactionSuccess(Transaction transaction) {
    when(() => createTransaction(any(), any()))
        .thenAnswer((_) async => Right(transaction));
  }

  /// Stubs createTransaction to return failure
  void stubCreateTransactionFailure(Failure failure) {
    when(() => createTransaction(any(), any()))
        .thenAnswer((_) async => Left(failure));
  }

  /// Stubs getTodayTransactionCount to return success
  void stubGetTodayTransactionCountSuccess(int count) {
    when(() => getTodayTransactionCount()).thenAnswer((_) async => Right(count));
  }

  /// Stubs getTransactionsByPaymentStatus to return success
  void stubGetTransactionsByPaymentStatusSuccess(List<Transaction> transactions) {
    when(() => getTransactionsByPaymentStatus(any()))
        .thenAnswer((_) async => Right(transactions));
  }

  /// Stubs updateTransaction to return success
  void stubUpdateTransactionSuccess(Transaction transaction) {
    when(() => updateTransaction(
          any(),
          paymentStatus: any(named: 'paymentStatus'),
          debtPaidAt: any(named: 'debtPaidAt'),
        )).thenAnswer((_) async => Right(transaction));
  }
}
