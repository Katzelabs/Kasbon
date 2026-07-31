import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/image_storage/image_storage_service.dart';
import '../../core/services/image_storage/supabase_image_storage_service.dart';
import '../../core/services/payment_proof/payment_proof_storage.dart';
import '../../core/services/payment_proof/supabase_payment_proof_storage.dart';
import '../../core/services/supabase_client_provider.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/mark_onboarding_complete.dart';
import '../../features/auth/domain/usecases/request_password_reset.dart';
import '../../features/auth/domain/usecases/resend_sign_up_otp.dart';
import '../../features/auth/domain/usecases/reset_password.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/verify_sign_up_otp.dart';
import '../../features/backup/data/repositories/backup_repository_impl.dart';
import '../../features/backup/domain/repositories/backup_repository.dart';
import '../../features/backup/domain/usecases/create_backup.dart';
import '../../features/backup/domain/usecases/get_backup_info.dart';
import '../../features/backup/domain/usecases/get_data_counts.dart';
import '../../features/backup/domain/usecases/get_last_backup.dart';
import '../../features/backup/domain/usecases/clear_all_data.dart';
import '../../features/backup/domain/usecases/restore_backup.dart';
import '../../features/categories/data/datasources/category_remote_datasource.dart';
import '../../features/categories/data/repositories/category_repository_impl.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/categories/domain/usecases/create_category.dart';
import '../../features/categories/domain/usecases/get_all_categories.dart';
import '../../features/products/data/datasources/product_remote_datasource.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/usecases/create_product.dart';
import '../../features/products/domain/usecases/delete_product.dart';
import '../../features/products/domain/usecases/get_all_products.dart';
import '../../features/products/domain/usecases/get_paginated_products.dart';
import '../../features/products/domain/usecases/get_product.dart';
import '../../features/products/domain/usecases/search_products.dart';
import '../../features/products/domain/usecases/update_product.dart';
import '../../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/get_dashboard_summary.dart';
import '../../features/receipt/data/datasources/shop_settings_remote_datasource.dart';
import '../../features/receipt/data/repositories/shop_settings_repository_impl.dart';
import '../../features/receipt/domain/repositories/shop_settings_repository.dart';
import '../../features/receipt/domain/usecases/get_shop_settings.dart';
import '../../features/settings/domain/usecases/update_shop_settings.dart';
import '../../features/reports/data/datasources/analytics_remote_datasource.dart';
import '../../features/reports/data/datasources/profit_remote_datasource.dart';
import '../../features/reports/data/datasources/report_remote_datasource.dart';
import '../../features/reports/data/repositories/analytics_repository_impl.dart';
import '../../features/reports/data/repositories/profit_report_repository_impl.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/analytics_repository.dart';
import '../../features/reports/domain/repositories/profit_report_repository.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/debt/domain/usecases/get_unpaid_debts.dart';
import '../../features/debt/domain/usecases/mark_debt_paid.dart';
import '../../features/reports/domain/usecases/compare_periods.dart';
import '../../features/reports/domain/usecases/get_category_distribution.dart';
import '../../features/reports/domain/usecases/get_daily_sales.dart';
import '../../features/reports/domain/usecases/get_hourly_heatmap.dart';
import '../../features/reports/domain/usecases/get_payment_distribution.dart';
import '../../features/reports/domain/usecases/get_product_movement.dart';
import '../../features/reports/domain/usecases/get_product_profitability.dart';
import '../../features/reports/domain/usecases/get_profit_summary.dart';
import '../../features/reports/domain/usecases/get_sales_summary.dart';
import '../../features/reports/domain/usecases/get_sales_trend.dart';
import '../../features/reports/domain/usecases/get_top_customers.dart';
import '../../features/reports/domain/usecases/get_top_products.dart';
import '../../features/reports/domain/usecases/get_top_profitable_products.dart';
import '../../features/transactions/data/datasources/transaction_remote_datasource.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/attach_payment_proof.dart';
import '../../features/transactions/domain/usecases/create_transaction.dart';
import '../../features/transactions/domain/usecases/get_customer_names.dart';
import '../../features/transactions/domain/usecases/get_transaction.dart';
import '../../features/transactions/domain/usecases/get_transactions.dart';

/// Global service locator instance
final GetIt getIt = GetIt.instance;

/// Logger instance for debugging
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Initialize all dependencies
///
/// This should be called at app startup before runApp()
Future<void> configureDependencies() async {
  // Register logger
  getIt.registerLazySingleton<Logger>(() => logger);

  // ===========================================
  // CORE SERVICES
  // ===========================================

  getIt.registerLazySingleton<SupabaseClientProvider>(
    () => SupabaseClientProvider(),
  );

  // ===========================================
  // IMAGE STORAGE SERVICE
  // ===========================================
  // Named directly rather than through a platform factory: Supabase Storage
  // serves every platform, so there is nothing left to choose between.
  getIt.registerLazySingleton<ImageStorageService>(
    () => SupabaseImageStorageService(getIt<SupabaseClientProvider>()),
  );

  // ===========================================
  // PAYMENT PROOF STORAGE
  // ===========================================
  // Separate from ImageStorageService on purpose: that bucket is public and
  // hands back a URL synchronously, this one is private and has to sign.
  getIt.registerLazySingleton<PaymentProofStorage>(
    () => SupabasePaymentProofStorage(getIt<SupabaseClientProvider>()),
  );

  // ===========================================
  // AUTH FEATURE
  // ===========================================

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
  );

  getIt.registerLazySingleton(() => SignIn(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => SignUp(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => SignOut(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetCurrentUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => VerifySignUpOtp(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => ResendSignUpOtp(getIt<AuthRepository>()));
  getIt.registerLazySingleton(
    () => RequestPasswordReset(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(() => ResetPassword(getIt<AuthRepository>()));
  getIt.registerLazySingleton(
    () => MarkOnboardingComplete(getIt<AuthRepository>()),
  );

  // ===========================================
  // PRODUCTS FEATURE
  // ===========================================

  getIt.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(getIt<ProductRemoteDataSource>()),
  );

  getIt.registerLazySingleton(() => GetAllProducts(getIt<ProductRepository>()));
  getIt.registerLazySingleton(() => GetProduct(getIt<ProductRepository>()));
  getIt.registerLazySingleton(() => SearchProducts(getIt<ProductRepository>()));
  getIt.registerLazySingleton(() => CreateProduct(getIt<ProductRepository>()));
  getIt.registerLazySingleton(() => UpdateProduct(getIt<ProductRepository>()));
  getIt.registerLazySingleton(() => DeleteProduct(
        getIt<ProductRepository>(),
        getIt<ImageStorageService>(),
      ));
  getIt.registerLazySingleton(
      () => GetPaginatedProducts(getIt<ProductRepository>()));

  // ===========================================
  // CATEGORIES FEATURE
  // ===========================================

  getIt.registerLazySingleton<CategoryRemoteDataSource>(
    () => CategoryRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(getIt<CategoryRemoteDataSource>()),
  );

  getIt.registerLazySingleton(
      () => GetAllCategories(getIt<CategoryRepository>()));
  getIt
      .registerLazySingleton(() => CreateCategory(getIt<CategoryRepository>()));

  // ===========================================
  // TRANSACTIONS FEATURE
  // ===========================================

  getIt.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(getIt<TransactionRemoteDataSource>()),
  );

  getIt.registerLazySingleton(
      () => CreateTransaction(getIt<TransactionRepository>()));
  getIt.registerLazySingleton(
      () => GetTransactionById(getIt<TransactionRepository>()));
  getIt.registerLazySingleton(
      () => GetTransactions(getIt<TransactionRepository>()));

  getIt.registerLazySingleton(() => AttachPaymentProof(
        getIt<TransactionRepository>(),
        getIt<PaymentProofStorage>(),
      ));
  getIt.registerLazySingleton(
      () => GetCustomerNames(getIt<TransactionRepository>()));

  // ===========================================
  // DEBT FEATURE
  // ===========================================

  getIt.registerLazySingleton(
      () => GetUnpaidDebts(getIt<TransactionRepository>()));
  getIt.registerLazySingleton(
      () => MarkDebtPaid(getIt<TransactionRepository>()));

  // ===========================================
  // DASHBOARD FEATURE
  // ===========================================

  getIt.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(getIt<DashboardRemoteDataSource>()),
  );

  getIt.registerLazySingleton(
    () => GetDashboardSummary(getIt<DashboardRepository>()),
  );

  // ===========================================
  // RECEIPT / SHOP SETTINGS FEATURE
  // ===========================================

  getIt.registerLazySingleton<ShopSettingsRemoteDataSource>(
    () => ShopSettingsRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<ShopSettingsRepository>(
    () => ShopSettingsRepositoryImpl(getIt<ShopSettingsRemoteDataSource>()),
  );

  getIt.registerLazySingleton(
    () => GetShopSettings(getIt<ShopSettingsRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateShopSettings(getIt<ShopSettingsRepository>()),
  );

  // ===========================================
  // REPORTS / PROFIT FEATURE
  // ===========================================

  getIt.registerLazySingleton<ProfitRemoteDataSource>(
    () => ProfitRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );
  getIt.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );
  getIt.registerLazySingleton<AnalyticsRemoteDataSource>(
    () => AnalyticsRemoteDataSourceImpl(getIt<SupabaseClientProvider>()),
  );

  getIt.registerLazySingleton<ProfitReportRepository>(
    () => ProfitReportRepositoryImpl(getIt<ProfitRemoteDataSource>()),
  );
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(getIt<ReportRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AnalyticsRepository>(
    () => AnalyticsRepositoryImpl(getIt<AnalyticsRemoteDataSource>()),
  );

  getIt.registerLazySingleton(
    () => GetProfitSummary(getIt<ProfitReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetTopProfitableProducts(getIt<ProfitReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetProductProfitability(getIt<ProfitReportRepository>()),
  );

  getIt.registerLazySingleton(
    () => GetSalesSummary(getIt<ReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetTopProducts(getIt<ReportRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetDailySales(getIt<ReportRepository>()),
  );

  // Period comparison reuses the sales summary RPC rather than its own, so it
  // depends on ReportRepository like the free-tier reports do.
  getIt.registerLazySingleton(
    () => ComparePeriods(getIt<ReportRepository>()),
  );

  // ===========================================
  // ADVANCED ANALYTICS (TASK_019)
  // ===========================================

  getIt.registerLazySingleton(
    () => GetSalesTrend(getIt<AnalyticsRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetCategoryDistribution(getIt<AnalyticsRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetPaymentDistribution(getIt<AnalyticsRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetHourlyHeatmap(getIt<AnalyticsRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetTopCustomers(getIt<AnalyticsRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetProductMovement(getIt<AnalyticsRepository>()),
  );

  // ===========================================
  // BACKUP FEATURE
  // ===========================================

  getIt.registerLazySingleton<BackupService>(
    () => BackupService(),
  );

  getIt.registerLazySingleton<BackupRepository>(
    () => BackupRepositoryImpl(getIt<BackupService>()),
  );

  getIt.registerLazySingleton(() => CreateBackup(getIt<BackupRepository>()));
  getIt.registerLazySingleton(() => RestoreBackup(getIt<BackupRepository>()));
  getIt.registerLazySingleton(() => GetBackupInfo(getIt<BackupRepository>()));
  getIt.registerLazySingleton(() => GetLastBackup(getIt<BackupRepository>()));
  getIt.registerLazySingleton(() => GetDataCounts(getIt<BackupRepository>()));
  getIt.registerLazySingleton(() => ClearAllData(getIt<BackupRepository>()));

  logger.i('Dependencies configured successfully (Supabase mode)');
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
