import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/settings_provider.dart';

/// Screen for app settings (low stock threshold, etc.)
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _thresholdController = TextEditingController();
  bool _initialized = false;
  String? _thresholdError;

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  String? _validateThreshold(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Batas stok minimum harus diisi';
    }

    final intValue = int.tryParse(value);
    if (intValue == null) {
      return 'Masukkan angka yang valid';
    }

    if (intValue < 1) {
      return 'Batas stok minimum harus lebih dari 0';
    }

    if (intValue > 9999) {
      return 'Batas stok maksimum adalah 9999';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(settingsFormProvider);
    final formNotifier = ref.read(settingsFormProvider.notifier);

    // Load settings on first build
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await formNotifier.loadSettings();
        if (mounted) {
          final state = ref.read(settingsFormProvider);
          _thresholdController.text = state.lowStockThreshold.toString();
        }
      });
    }

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Pengaturan Aplikasi',
        onBack: () => context.pop(),
        onProfileTap: () {},
      ),
      body: formState.isLoading
          ? const Center(child: ModernLoading())
          : Form(
              key: _formKey,
              child: Builder(
                builder: (context) {
                  // Calculate bottom padding based on device type to account for bottom nav
                  final bottomPadding = context.isMobile
                      ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
                      : AppDimensions.spacing16;

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: AppDimensions.spacing16,
                      right: AppDimensions.spacing16,
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
                                    padding: const EdgeInsets.all(
                                        AppDimensions.spacing8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha:0.1),
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
                              const SizedBox(height: AppDimensions.spacing16),

                              // Low stock threshold field
                              ModernTextField(
                                label: 'Batas Stok Minimum',
                                hint: 'Masukkan angka (minimal 1)',
                                controller: _thresholdController,
                                leading: const Icon(Icons.inventory_2_rounded),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  // Clear error when user types
                                  if (_thresholdError != null) {
                                    setState(() {
                                      _thresholdError = _validateThreshold(value);
                                    });
                                  }
                                  final intValue = int.tryParse(value) ?? 1;
                                  formNotifier.setLowStockThreshold(intValue);
                                },
                                errorText: _thresholdError ??
                                    (formState.error != null &&
                                            formState.error!.contains('stok')
                                        ? formState.error
                                        : null),
                              ),
                              const SizedBox(height: AppDimensions.spacing16),

                              // Info card
                              Container(
                                padding:
                                    const EdgeInsets.all(AppDimensions.spacing12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMedium),
                                  border: Border.all(
                                    color: AppColors.info.withValues(alpha:0.3),
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
                                        'Contoh: Jika diatur ke ${formState.lowStockThreshold}, produk dengan stok ${formState.lowStockThreshold - 1 >= 0 ? formState.lowStockThreshold - 1 : 0} atau kurang akan muncul di peringatan.',
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
                          onPressed: () => _saveSettings(context, formNotifier),
                          child: const Text('Simpan Pengaturan'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _saveSettings(
    BuildContext context,
    SettingsFormNotifier formNotifier,
  ) async {
    // Validate the threshold input
    final validationError = _validateThreshold(_thresholdController.text);
    if (validationError != null) {
      setState(() {
        _thresholdError = validationError;
      });
      ModernToast.error(context, validationError);
      return;
    }

    // Clear any previous validation error
    setState(() {
      _thresholdError = null;
    });

    final success = await formNotifier.saveAppSettings();

    if (success && context.mounted) {
      ModernToast.success(context, 'Pengaturan berhasil disimpan');
      context.pop();
    } else if (!success && context.mounted) {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
