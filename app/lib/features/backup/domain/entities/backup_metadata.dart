import 'package:equatable/equatable.dart';

/// Represents metadata about a backup file
class BackupMetadata extends Equatable {
  final String filePath;
  final String fileName;
  final DateTime backupDate;
  final String appVersion;
  final String deviceInfo;
  final BackupCounts counts;
  final int fileSizeBytes;

  const BackupMetadata({
    required this.filePath,
    required this.fileName,
    required this.backupDate,
    required this.appVersion,
    required this.deviceInfo,
    required this.counts,
    required this.fileSizeBytes,
  });

  /// Formats file size for display (KB, MB)
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    }
  }

  @override
  List<Object?> get props => [
        filePath,
        fileName,
        backupDate,
        appVersion,
        deviceInfo,
        counts,
        fileSizeBytes,
      ];
}

/// Counts of items in a backup
class BackupCounts extends Equatable {
  final int shopSettings;
  final int categories;
  final int products;
  final int transactions;
  final int transactionItems;

  const BackupCounts({
    required this.shopSettings,
    required this.categories,
    required this.products,
    required this.transactions,
    required this.transactionItems,
  });

  @override
  List<Object?> get props => [
        shopSettings,
        categories,
        products,
        transactions,
        transactionItems,
      ];
}

/// Current data counts in the database
class DataCounts extends Equatable {
  final int products;
  final int transactions;
  final int categories;

  const DataCounts({
    required this.products,
    required this.transactions,
    required this.categories,
  });

  @override
  List<Object?> get props => [products, transactions, categories];
}

/// Information about a backup file for preview
class BackupInfo extends Equatable {
  final DateTime backupDate;
  final String appVersion;
  final int productsCount;
  final int transactionsCount;
  final int categoriesCount;

  const BackupInfo({
    required this.backupDate,
    required this.appVersion,
    required this.productsCount,
    required this.transactionsCount,
    required this.categoriesCount,
  });

  @override
  List<Object?> get props => [
        backupDate,
        appVersion,
        productsCount,
        transactionsCount,
        categoriesCount,
      ];
}
