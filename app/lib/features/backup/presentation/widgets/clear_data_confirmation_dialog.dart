import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/backup_metadata.dart';
import '../providers/backup_provider.dart';

/// Dialog for confirming clear all data operation with text confirmation
class ClearDataConfirmationDialog extends ConsumerStatefulWidget {
  const ClearDataConfirmationDialog({super.key});

  @override
  ConsumerState<ClearDataConfirmationDialog> createState() =>
      _ClearDataConfirmationDialogState();
}

class _ClearDataConfirmationDialogState
    extends ConsumerState<ClearDataConfirmationDialog> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isConfirmEnabled = false;

  static const String _confirmText = 'HAPUS';

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _confirmController.removeListener(_onTextChanged);
    _confirmController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isEnabled = _confirmController.text == _confirmText;
    if (isEnabled != _isConfirmEnabled) {
      setState(() {
        _isConfirmEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataCountsAsync = ref.watch(dataCountsProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85 - viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Delete Icon
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spacing16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.error,
                          size: 48,
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacing16),

                      // Title
                      const Text(
                        'Hapus Semua Data?',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppDimensions.spacing16),

                      // Data Counts Card
                      dataCountsAsync.when(
                        loading: () => const SizedBox(
                          height: 80,
                          child: Center(child: ModernLoading.small()),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (counts) => _buildDataCountsCard(counts),
                      ),

                      const SizedBox(height: AppDimensions.spacing16),

                      // Warning Message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppDimensions.spacing12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: AppDimensions.spacing8),
                                Text(
                                  'PERINGATAN',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacing8),
                            Text(
                              'Semua data akan dihapus permanen. Tindakan ini tidak dapat dibatalkan. Pastikan Anda sudah membuat backup.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacing16),

                      // Confirmation Text Input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ketik "HAPUS" untuk konfirmasi:',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing8),
                          ModernTextField(
                            controller: _confirmController,
                            hint: 'Ketik HAPUS',
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spacing24),
                    ],
                  ),
                ),
              ),

              // Fixed buttons (always visible)
              Row(
                children: [
                  Expanded(
                    child: ModernButton.outline(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: ModernButton.destructive(
                      onPressed: _isConfirmEnabled
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCountsCard(DataCounts counts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        children: [
          _buildCountRow('Produk', counts.products),
          const SizedBox(height: AppDimensions.spacing8),
          _buildCountRow('Transaksi', counts.transactions),
          const SizedBox(height: AppDimensions.spacing8),
          _buildCountRow('Kategori', counts.categories),
        ],
      ),
    );
  }

  Widget _buildCountRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '$count',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
