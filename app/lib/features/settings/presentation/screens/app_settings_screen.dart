import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/settings_provider.dart';
import '../widgets/unsaved_changes_guard.dart';

/// Screen for app settings (low stock threshold, etc.)
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  /// The thresholds worth one tap.
  ///
  /// A UMKM stall restocks in units of a handful, so these three cover most
  /// shops outright and the stepper handles the rest. The screen used to ask
  /// for the number as free text, which bought four validation rules
  /// ("harus diisi", "angka yang valid", "lebih dari 0", "maksimal 9999") for
  /// a value that is nearly always 3, 5 or 10.
  static const List<int> _presets = [3, 5, 10];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(settingsFormProvider);
    final formNotifier = ref.read(settingsFormProvider.notifier);
    final isDirty = formState.isAppSettingsDirty;

    return UnsavedChangesGuard(
      isDirty: isDirty,
      child: Scaffold(
        appBar: ModernAppBar.backWithActions(
          title: 'Pengaturan Aplikasi',
          onBack: () => UnsavedChangesGuard.maybePop(context, isDirty: isDirty),
        ),
        body: _buildBody(ref, formState, formNotifier),
      ),
    );
  }

  Widget _buildBody(
    WidgetRef ref,
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    if (formState.isLoading) {
      return const Center(child: ModernLoading());
    }

    if (formState.hasLoadError) {
      return ModernErrorState(
        message: formState.error!,
        onRetry: formNotifier.loadSettings,
      );
    }

    final threshold = formState.lowStockThreshold;
    final isDirty = formState.isAppSettingsDirty;

    return Builder(
      builder: (context) {
        // Calculate bottom padding based on device type to account for bottom nav
        final bottomPadding =
            AppDimensions.spacing16 + context.shellBottomInset;

        // One card holding one setting and a save button - a form, so
        // it gets form width rather than stretching a 200-character
        // description line across the window.
        return ModernContentColumn.form(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: AppDimensions.spacing16,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock notification settings card
                ModernCard.elevated(
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(AppDimensions.spacing8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMedium),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.primary,
                              size: AppDimensions.iconMedium,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notifikasi Stok',
                                  style: AppTextStyles.h4,
                                ),
                                const SizedBox(height: AppDimensions.spacing4),
                                Text(
                                  'Atur batas minimum stok untuk peringatan',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                      const ModernDivider(),
                      const SizedBox(height: AppDimensions.spacing16),

                      // Description
                      Text(
                        'Produk dengan stok di bawah batas minimum akan ditampilkan di daftar peringatan pada dashboard.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing20),

                      // The value itself: a bounded stepper rather than a text
                      // field. The old field parsed with `int.tryParse(value)
                      // ?? 1`, so clearing it wrote 1 into the state while the
                      // box sat empty - and the example below then explained a
                      // threshold the user had never chosen.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Batas Stok Minimum',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ModernQuantityStepper(
                            value: threshold,
                            minValue: 1,
                            maxValue: 9999,
                            onChanged: formNotifier.setLowStockThreshold,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing16),

                      // One-tap presets for the common cases.
                      Wrap(
                        spacing: AppDimensions.spacing8,
                        runSpacing: AppDimensions.spacing8,
                        children: [
                          for (final preset in _presets)
                            ModernChip.filter(
                              label: '$preset',
                              selected: threshold == preset,
                              onSelected: (_) =>
                                  formNotifier.setLowStockThreshold(preset),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing16),

                      // Info card
                      Container(
                        padding:
                            const EdgeInsets.all(AppDimensions.spacing12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMedium),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.info,
                              size: AppDimensions.iconMedium,
                            ),
                            const SizedBox(width: AppDimensions.spacing12),
                            Expanded(
                              child: Text(
                                'Produk dengan stok $threshold atau kurang akan muncul di peringatan.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing24),

                // Save button
                ModernButton.primary(
                  fullWidth: true,
                  isLoading: formState.isSaving,
                  onPressed: isDirty
                      ? () => _saveSettings(context, ref, formNotifier)
                      : null,
                  child: Text(isDirty ? 'Simpan Pengaturan' : 'Tersimpan'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSettings(
    BuildContext context,
    WidgetRef ref,
    SettingsFormNotifier formNotifier,
  ) async {
    // No input validation left to run here: the stepper and the presets are
    // both bounded, so an out-of-range threshold is not reachable from the UI.
    final success = await formNotifier.saveAppSettings();
    if (!context.mounted) return;

    if (success) {
      ModernToast.success(context, 'Pengaturan berhasil disimpan');
      context.pop();
    } else {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
