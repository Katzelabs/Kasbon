import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/services/file_export/file_export_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/backup_provider.dart';
import '../widgets/backup_section.dart';
import '../widgets/backup_success_dialog.dart';
import '../widgets/clear_data_confirmation_dialog.dart';
import '../widgets/clear_progress_dialog.dart';
import '../widgets/danger_zone_section.dart';
import '../widgets/restore_confirmation_dialog.dart';
import '../widgets/restore_progress_dialog.dart';
import '../widgets/restore_section.dart';

/// Main backup and restore screen
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Backup & Restore',
        onProfileTap: () => {},
      ),
      body: Builder(
        builder: (context) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding =
              AppDimensions.spacing16 + context.shellBottomInset;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: AppDimensions.spacing16,
              right: AppDimensions.spacing16,
              top: AppDimensions.spacing16,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Backup Section
                BackupSection(
                  isCreatingBackup: backupState.isCreatingBackup,
                  onCreateBackup: _handleCreateBackup,
                ),

                // Restore Section
                //
                // Hidden in a browser: restoring reads the file the user
                // picks, and `file_picker` on web returns bytes with a null
                // path - there is nothing for the restore path to open. The
                // section would be a button that can only ever fail.
                if (AppPlatform.hasFileSystem) ...[
                  const SizedBox(height: AppDimensions.spacing24),
                  RestoreSection(
                    onSelectFile: _handleSelectFile,
                  ),
                ],

                const SizedBox(height: AppDimensions.spacing24),

                // Danger Zone Section
                DangerZoneSection(
                  onClearAllData: _handleClearAllData,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCreateBackup() async {
    String? selectedDirectory;

    // Choosing a folder only means something where the app writes to one. In a
    // browser the download destination is the user's own setting, so asking
    // would offer a choice the app cannot honour - and cancelling that dialog
    // would abandon a backup the browser was perfectly able to save.
    if (FileExportService.hasAddressableFiles) {
      try {
        selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Pilih Folder untuk Backup',
        );
      } catch (e) {
        // Directory picker not supported, will use default
      }

      // If user cancelled the picker, ask if they want to use default
      if (selectedDirectory == null && mounted) {
        final useDefault = await _showUseDefaultDirectoryDialog();
        if (useDefault != true) {
          // User cancelled or dismissed the dialog
          return;
        }
        // useDefault == true means use default directory (selectedDirectory
        // stays null); useDefault == false is handled above.
      }
    }

    final notifier = ref.read(backupProvider.notifier);
    final metadata = await notifier.createBackup(directoryPath: selectedDirectory);

    if (metadata != null && mounted) {
      // Show success dialog
      final shouldShare = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => BackupSuccessDialog(metadata: metadata),
      );

      // Sharing needs a real file on disk. On web the backup is a browser
      // download with no path, and XFile(null) throws - the file is already in
      // the user's downloads, so there is nothing to share anyway.
      if (shouldShare == true && mounted && metadata.hasFilePath) {
        // Share the backup file
        await Share.shareXFiles(
          [XFile(metadata.filePath!)],
          subject: 'Backup KASBON - ${metadata.fileName}',
        );
      }

      // Refresh last backup info
      ref.invalidate(lastBackupProvider);
    } else if (mounted) {
      final error = ref.read(backupProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
        notifier.clearError();
      }
    }
  }

  /// Shows a dialog asking if user wants to use default directory
  ///
  /// Returns true only if the user opted into the default folder; cancelling
  /// or dismissing both return false.
  Future<bool?> _showUseDefaultDirectoryDialog() {
    return ModernDialog.confirm(
      context,
      title: 'Gunakan Folder Default?',
      message:
          'Anda belum memilih folder. Backup akan disimpan di folder Download/KASBON_Backup.',
      confirmLabel: 'Gunakan Default',
      cancelLabel: 'Batal',
    );
  }

  Future<void> _handleSelectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (mounted) {
          ModernToast.error(context, 'Gagal membaca file');
        }
        return;
      }

      // Load backup info
      final notifier = ref.read(backupProvider.notifier);
      final success = await notifier.loadBackupInfo(filePath);

      if (!success && mounted) {
        final error = ref.read(backupProvider).error;
        ModernToast.error(context, error ?? 'File backup tidak valid');
        notifier.clearError();
        return;
      }

      // Show confirmation dialog
      if (mounted) {
        final state = ref.read(backupProvider);
        if (state.selectedBackupInfo != null &&
            state.selectedFilePath != null) {
          final shouldRestore = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => RestoreConfirmationDialog(
              backupInfo: state.selectedBackupInfo!,
            ),
          );

          if (shouldRestore == true) {
            await _handleRestore(state.selectedFilePath!);
          } else {
            notifier.clearSelectedBackup();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal memilih file');
      }
    }
  }

  Future<void> _handleRestore(String filePath) async {
    // Show progress dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const RestoreProgressDialog(),
    );

    // Wait a frame for dialog to mount
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Now start the restore
    final notifier = ref.read(backupProvider.notifier);
    final success = await notifier.restoreBackup(filePath);

    if (mounted) {
      // Close progress dialog using root navigator
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        ModernToast.success(context, 'Data berhasil di-restore!');
        // Refresh data counts and last backup
        ref.invalidate(dataCountsProvider);
        ref.invalidate(lastBackupProvider);
      } else {
        final error = ref.read(backupProvider).error;
        ModernToast.error(context, error ?? 'Gagal me-restore data');
        notifier.clearError();
      }
    }
  }

  Future<void> _handleClearAllData() async {
    // Show confirmation dialog
    final shouldClear = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClearDataConfirmationDialog(),
    );

    if (shouldClear != true || !mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const ClearProgressDialog(),
    );

    // Wait a frame for dialog to mount
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Now start the clear operation
    final notifier = ref.read(backupProvider.notifier);
    final success = await notifier.clearAllData();

    if (mounted) {
      // Close progress dialog using root navigator
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        ModernToast.success(context, 'Semua data berhasil dihapus!');
        // Refresh data counts and last backup
        ref.invalidate(dataCountsProvider);
        ref.invalidate(lastBackupProvider);
      } else {
        final error = ref.read(backupProvider).error;
        ModernToast.error(context, error ?? 'Gagal menghapus data');
        notifier.clearError();
      }
    }
  }
}
