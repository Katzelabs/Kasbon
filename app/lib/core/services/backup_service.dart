import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/query_limits.dart';
import '../errors/exceptions.dart';

/// Backup metadata structure
class BackupMetadataDto {
  final String backupVersion;
  final String backupDate;
  final String appVersion;
  final String deviceInfo;
  final Map<String, int> counts;

  const BackupMetadataDto({
    required this.backupVersion,
    required this.backupDate,
    required this.appVersion,
    required this.deviceInfo,
    required this.counts,
  });

  factory BackupMetadataDto.fromJson(Map<String, dynamic> json) {
    return BackupMetadataDto(
      backupVersion: json['backup_version'] as String? ?? '1.0',
      backupDate: json['backup_date'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      deviceInfo: json['device_info'] as String? ?? '',
      counts: Map<String, int>.from(json['counts'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backup_version': backupVersion,
      'backup_date': backupDate,
      'app_version': appVersion,
      'device_info': deviceInfo,
      'counts': counts,
    };
  }
}

/// Data counts for current database state
class DataCountsDto {
  final int products;
  final int transactions;
  final int categories;
  final int transactionItems;

  const DataCountsDto({
    required this.products,
    required this.transactions,
    required this.categories,
    required this.transactionItems,
  });
}

/// Progress callback for export operations
typedef RestoreProgressCallback = void Function(String step, double progress);

/// Core backup/export service using Supabase
class BackupService {
  static const String _currentBackupVersion = '2.0';

  SupabaseClient get _client => Supabase.instance.client;

  BackupService();

  /// Exports all data to JSON string with metadata
  Future<String> exportToJson() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // Export all tables via Supabase queries (RLS scopes to current user)
      final shopSettings = await _exportTable('shop_settings');
      final categories = await _exportTable('categories');
      final products = await _exportTable('products');
      final transactions = await _exportTable('transactions');
      final transactionItems = await _exportTable('transaction_items');

      final backup = {
        'metadata': {
          'backup_version': _currentBackupVersion,
          'backup_date': DateTime.now().toIso8601String(),
          'app_version': packageInfo.version,
          'device_info': 'Android',
          'counts': {
            'shop_settings': shopSettings.length,
            'categories': categories.length,
            'products': products.length,
            'transactions': transactions.length,
            'transaction_items': transactionItems.length,
          },
        },
        'data': {
          'shop_settings': shopSettings,
          'categories': categories,
          'products': products,
          'transactions': transactions,
          'transaction_items': transactionItems,
        },
      };

      return jsonEncode(backup);
    } catch (e) {
      if (e is BackupException) rethrow;
      throw BackupException(
        message: 'Gagal membuat backup: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Parses backup metadata for preview without importing
  BackupMetadataDto parseBackupInfo(String jsonString) {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonString);

      if (!backup.containsKey('metadata')) {
        throw const BackupException(
          message: 'File backup tidak valid: metadata tidak ditemukan',
          code: 'INVALID_BACKUP',
        );
      }

      return BackupMetadataDto.fromJson(backup['metadata']);
    } catch (e) {
      if (e is BackupException) rethrow;
      throw BackupException(
        message: 'Gagal membaca info backup: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Gets current data counts from Supabase
  Future<DataCountsDto> getDataCounts() async {
    final products = await _countTable('products');
    final transactions = await _countTable('transactions');
    final categories = await _countTable('categories');
    final transactionItems = await _countTable('transaction_items');

    return DataCountsDto(
      products: products,
      transactions: transactions,
      categories: categories,
      transactionItems: transactionItems,
    );
  }

  /// Reads an entire table in chunks.
  ///
  /// A bare `.select()` here returned at most [QueryLimits.supabaseMaxRows]
  /// rows and said nothing about it, so any shop past a thousand
  /// `transaction_items` - a few hundred sales - was handed a backup file that
  /// looked complete, carried a `counts` block agreeing with its own truncated
  /// contents, and was missing everything older. That is the failure mode a
  /// backup exists to prevent.
  ///
  /// Ordered by `id` because paging without an ORDER BY has no defined row
  /// order between requests: Postgres may return the same row on two pages and
  /// skip another entirely. `id` is the primary key, so it is both unique and
  /// indexed, which keeps the deep pages cheap.
  ///
  /// A short page ends the walk. [QueryLimits.backupRowCeiling] throws rather
  /// than returning early - a caller that asked for a backup gets a complete
  /// one or an error, never a quiet subset.
  Future<List<Map<String, dynamic>>> _exportTable(String tableName) async {
    final rows = <Map<String, dynamic>>[];

    while (true) {
      final page = await _client
          .from(tableName)
          .select()
          .order('id')
          .range(rows.length, rows.length + QueryLimits.chunkSize - 1);

      rows.addAll(List<Map<String, dynamic>>.from(page));

      if (page.length < QueryLimits.chunkSize) break;

      if (rows.length >= QueryLimits.backupRowCeiling) {
        throw BackupException(
          message: 'Data $tableName terlalu besar untuk dibackup '
              '(lebih dari ${QueryLimits.backupRowCeiling} baris). '
              'Hubungi dukungan untuk ekspor bertahap.',
          code: 'BACKUP_TOO_LARGE',
        );
      }
    }

    return rows;
  }

  Future<int> _countTable(String tableName) async {
    final result =
        await _client.from(tableName).select().count(CountOption.exact);
    return result.count;
  }
}
