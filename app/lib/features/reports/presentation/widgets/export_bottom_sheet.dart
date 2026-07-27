import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/services/export/export_result.dart';
import '../../../../core/services/file_export/file_export_service.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/date_range_provider.dart';
import '../providers/export_provider.dart';

/// Bottom sheet offering the available export formats.
class ExportBottomSheet extends ConsumerWidget {
  const ExportBottomSheet({super.key});

  /// Open the sheet.
  static Future<void> show(BuildContext context) {
    return ModernBottomSheet.show<void>(
      context,
      title: 'Ekspor Laporan',
      child: const ExportBottomSheet(),
    );
  }

  /// Save the file, then hand it to the system share sheet.
  ///
  /// Saving first means the export survives a cancelled share - the user still
  /// has the file, and the toast tells them where it went.
  ///
  /// In a browser the save *is* the delivery: the bytes go straight to the
  /// downloads folder. Following it with a share would be a second copy of the
  /// same file at best - `Printing.sharePdf` on web triggers its own download
  /// or print dialog - so the share step is skipped where files have no
  /// address to share.
  Future<void> _deliver(
    BuildContext context,
    ExportResult result,
  ) async {
    final saved = await FileExportService.saveBytes(
      result.bytes,
      result.fileName,
    );

    if (!context.mounted) return;

    if (FileExportService.hasAddressableFiles) {
      if (result.mimeType == ExportResult.pdfMimeType) {
        // Printing's sheet adds a print/preview option, which a PDF report
        // wants and a spreadsheet does not.
        await Printing.sharePdf(bytes: result.bytes, filename: result.fileName);
      } else if (saved.hasPath) {
        // Sharing a spreadsheet needs a file on disk.
        await Share.shareXFiles(
          [
            XFile(saved.path!, mimeType: result.mimeType, name: result.fileName)
          ],
          subject: result.fileName,
        );
      }
    }

    if (!context.mounted) return;

    if (result.isTruncated) {
      ModernToast.warning(
        context,
        '${result.omittedRowCount} baris tidak dimuat. '
        'Persempit rentang tanggal untuk data lengkap.',
      );
    } else {
      ModernToast.success(
        context,
        FileExportService.hasAddressableFiles
            ? 'Tersimpan: ${saved.fileName}'
            : 'Diunduh: ${saved.fileName}',
      );
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) async {
    final result =
        await ref.read(exportControllerProvider.notifier).export(format);

    if (!context.mounted) return;

    if (result == null) {
      final message = ref.read(exportControllerProvider).errorMessage;
      ModernToast.error(context, message ?? 'Gagal membuat berkas ekspor');
      return;
    }

    try {
      await _deliver(context, result);
    } catch (e) {
      if (!context.mounted) return;
      ModernToast.error(context, 'Gagal menyimpan atau membagikan berkas');
      return;
    }

    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportState = ref.watch(exportControllerProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data periode: ${dateRange.label}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        if (exportState.isBusy)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing32,
            ),
            child: Center(
              child: Column(
                children: [
                  const ModernLoading(),
                  const SizedBox(height: AppDimensions.spacing12),
                  Text(
                    exportState.progressLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final format in ExportFormat.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
              child: _FormatTile(
                format: format,
                onTap: () => _run(context, ref, format),
              ),
            ),
        const SizedBox(height: AppDimensions.spacing8),
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  final ExportFormat format;
  final VoidCallback onTap;

  const _FormatTile({required this.format, required this.onTap});

  IconData get _icon => switch (format) {
        ExportFormat.excelWorkbook => Icons.table_chart_rounded,
        ExportFormat.pdfSalesReport => Icons.picture_as_pdf_rounded,
        ExportFormat.pdfProductReport => Icons.inventory_2_rounded,
        ExportFormat.pdfReceiptArchive => Icons.receipt_long_rounded,
      };

  Color get _color => switch (format) {
        ExportFormat.excelWorkbook => AppColors.success,
        ExportFormat.pdfSalesReport => AppColors.error,
        ExportFormat.pdfProductReport => AppColors.info,
        ExportFormat.pdfReceiptArchive => AppColors.accentCyan,
      };

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(_icon, color: _color, size: AppDimensions.iconMedium),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  format.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
