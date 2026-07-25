import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/backup_metadata.dart';
import '../../domain/usecases/clear_all_data.dart';
import '../../domain/usecases/create_backup.dart';
import '../../domain/usecases/get_data_counts.dart';
import '../../domain/usecases/get_backup_info.dart';
import '../../domain/usecases/get_last_backup.dart';
import '../../domain/usecases/restore_backup.dart';

/// Provider for current data counts
final dataCountsProvider = FutureProvider.autoDispose<DataCounts>((ref) async {
  final getDataCounts = getIt<GetDataCounts>();
  final result = await getDataCounts(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (counts) => counts,
  );
});

/// Provider for last backup info
final lastBackupProvider = FutureProvider.autoDispose<BackupMetadata?>((ref) async {
  final getLastBackup = getIt<GetLastBackup>();
  final result = await getLastBackup(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (metadata) => metadata,
  );
});

/// State for backup operations
class BackupState {
  final bool isCreatingBackup;
  final bool isRestoring;
  final String? restoreStep;
  final double restoreProgress;
  final bool isClearing;
  final String? clearStep;
  final double clearProgress;
  final String? error;
  final BackupMetadata? lastCreatedBackup;
  final BackupInfo? selectedBackupInfo;
  final String? selectedFilePath;

  const BackupState({
    this.isCreatingBackup = false,
    this.isRestoring = false,
    this.restoreStep,
    this.restoreProgress = 0.0,
    this.isClearing = false,
    this.clearStep,
    this.clearProgress = 0.0,
    this.error,
    this.lastCreatedBackup,
    this.selectedBackupInfo,
    this.selectedFilePath,
  });

  BackupState copyWith({
    bool? isCreatingBackup,
    bool? isRestoring,
    String? restoreStep,
    double? restoreProgress,
    bool? isClearing,
    String? clearStep,
    double? clearProgress,
    String? error,
    BackupMetadata? lastCreatedBackup,
    BackupInfo? selectedBackupInfo,
    String? selectedFilePath,
    bool clearError = false,
    bool clearLastCreatedBackup = false,
    bool clearSelectedBackupInfo = false,
    bool clearSelectedFilePath = false,
    bool clearClearStep = false,
  }) {
    return BackupState(
      isCreatingBackup: isCreatingBackup ?? this.isCreatingBackup,
      isRestoring: isRestoring ?? this.isRestoring,
      restoreStep: restoreStep ?? this.restoreStep,
      restoreProgress: restoreProgress ?? this.restoreProgress,
      isClearing: isClearing ?? this.isClearing,
      clearStep: clearClearStep ? null : (clearStep ?? this.clearStep),
      clearProgress: clearProgress ?? this.clearProgress,
      error: clearError ? null : (error ?? this.error),
      lastCreatedBackup: clearLastCreatedBackup ? null : (lastCreatedBackup ?? this.lastCreatedBackup),
      selectedBackupInfo: clearSelectedBackupInfo ? null : (selectedBackupInfo ?? this.selectedBackupInfo),
      selectedFilePath: clearSelectedFilePath ? null : (selectedFilePath ?? this.selectedFilePath),
    );
  }
}

/// Notifier for managing backup/restore operations
class BackupNotifier extends StateNotifier<BackupState> {
  final CreateBackup _createBackup;
  final RestoreBackup _restoreBackup;
  final GetBackupInfo _getBackupInfo;
  final ClearAllData _clearAllData;

  BackupNotifier({
    required CreateBackup createBackup,
    required RestoreBackup restoreBackup,
    required GetBackupInfo getBackupInfo,
    required ClearAllData clearAllData,
  })  : _createBackup = createBackup,
        _restoreBackup = restoreBackup,
        _getBackupInfo = getBackupInfo,
        _clearAllData = clearAllData,
        super(const BackupState());

  /// Creates a backup
  /// If [directoryPath] is provided, saves to that directory instead of default
  Future<BackupMetadata?> createBackup({String? directoryPath}) async {
    state = state.copyWith(
      isCreatingBackup: true,
      clearError: true,
      clearLastCreatedBackup: true,
    );

    final result = await _createBackup(
      CreateBackupParams(directoryPath: directoryPath),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isCreatingBackup: false,
          error: failure.message,
        );
        return null;
      },
      (metadata) {
        state = state.copyWith(
          isCreatingBackup: false,
          lastCreatedBackup: metadata,
        );
        return metadata;
      },
    );
  }

  /// Loads backup info for preview
  Future<bool> loadBackupInfo(String filePath) async {
    state = state.copyWith(
      clearError: true,
      clearSelectedBackupInfo: true,
      clearSelectedFilePath: true,
    );

    final result = await _getBackupInfo(GetBackupInfoParams(filePath: filePath));

    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (info) {
        state = state.copyWith(
          selectedBackupInfo: info,
          selectedFilePath: filePath,
        );
        return true;
      },
    );
  }

  /// Restores from a backup file
  Future<bool> restoreBackup(String filePath) async {
    state = state.copyWith(
      isRestoring: true,
      restoreStep: 'Memulai restore...',
      restoreProgress: 0.0,
      clearError: true,
    );

    final result = await _restoreBackup(
      RestoreBackupParams(
        filePath: filePath,
        onProgress: (step, progress) {
          state = state.copyWith(
            restoreStep: step,
            restoreProgress: progress,
          );
        },
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isRestoring: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isRestoring: false,
          restoreStep: null,
          restoreProgress: 0.0,
          clearSelectedBackupInfo: true,
          clearSelectedFilePath: true,
        );
        return true;
      },
    );
  }

  /// Clears the selected backup info
  void clearSelectedBackup() {
    state = state.copyWith(
      clearSelectedBackupInfo: true,
      clearSelectedFilePath: true,
    );
  }

  /// Clears error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clears last created backup
  void clearLastCreatedBackup() {
    state = state.copyWith(clearLastCreatedBackup: true);
  }

  /// Clears all data from the database
  Future<bool> clearAllData() async {
    state = state.copyWith(
      isClearing: true,
      clearStep: 'Memulai penghapusan...',
      clearProgress: 0.0,
      clearError: true,
    );

    final result = await _clearAllData(
      ClearAllDataParams(
        onProgress: (step, progress) {
          state = state.copyWith(
            clearStep: step,
            clearProgress: progress,
          );
        },
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isClearing: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isClearing: false,
          clearClearStep: true,
          clearProgress: 0.0,
        );
        return true;
      },
    );
  }
}

/// Provider for backup notifier
final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier(
    createBackup: getIt<CreateBackup>(),
    restoreBackup: getIt<RestoreBackup>(),
    getBackupInfo: getIt<GetBackupInfo>(),
    clearAllData: getIt<ClearAllData>(),
  );
});
