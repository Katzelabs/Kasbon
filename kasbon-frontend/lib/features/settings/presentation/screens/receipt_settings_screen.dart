import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/settings_provider.dart';

/// Screen for customizing receipt header and footer
class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen> {
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  bool _initialized = false;

  // Validation state
  String? _headerError;
  String? _footerError;

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  /// Validates header and footer fields
  /// Returns true if all fields are valid
  bool _validateFields() {
    bool isValid = true;

    // Header validation - max 100 characters
    if (_headerController.text.length > 100) {
      setState(() => _headerError = 'Header maksimal 100 karakter');
      isValid = false;
    } else {
      setState(() => _headerError = null);
    }

    // Footer validation - max 100 characters
    if (_footerController.text.length > 100) {
      setState(() => _footerError = 'Footer maksimal 100 karakter');
      isValid = false;
    } else {
      setState(() => _footerError = null);
    }

    return isValid;
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
          _headerController.text = state.receiptHeader;
          _footerController.text = state.receiptFooter;
        }
      });
    }

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Pengaturan Struk',
        onBack: () => context.pop(),
        onProfileTap: () {},
      ),
      body: formState.isLoading
          ? const Center(child: ModernLoading())
          : context.isMobile
              ? _buildMobileLayout(formState, formNotifier)
              : _buildTabletLayout(formState, formNotifier),
    );
  }

  /// Mobile layout: Preview on top, form fields below
  Widget _buildMobileLayout(
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
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
          // Preview on top for mobile
          _buildReceiptPreview(formState),
          const SizedBox(height: AppDimensions.spacing24),

          // Form card below preview
          _buildFormCard(formNotifier),
          const SizedBox(height: AppDimensions.spacing24),

          // Save button
          ModernButton.primary(
            fullWidth: true,
            isLoading: formState.isSaving,
            onPressed: () => _saveSettings(context, formNotifier),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  /// Tablet layout: 2 columns - form left, preview right
  Widget _buildTabletLayout(
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Form fields
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormCard(formNotifier),
                const SizedBox(height: AppDimensions.spacing24),
                ModernButton.primary(
                  fullWidth: true,
                  isLoading: formState.isSaving,
                  onPressed: () => _saveSettings(context, formNotifier),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing24),
          // Right column: Preview
          Expanded(
            child: _buildReceiptPreview(formState),
          ),
        ],
      ),
    );
  }

  /// Builds the form card with header and footer fields
  Widget _buildFormCard(SettingsFormNotifier formNotifier) {
    return ModernCard.elevated(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kustomisasi Struk',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Receipt header field
          ModernTextField(
            label: 'Header Struk',
            hint: 'Teks yang ditampilkan di bagian atas struk',
            controller: _headerController,
            leading: const Icon(Icons.vertical_align_top_rounded),
            errorText: _headerError,
            onChanged: (value) {
              formNotifier.setReceiptHeader(value);
              _validateFields();
            },
            maxLines: 3,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // Receipt footer field
          ModernTextField(
            label: 'Footer Struk',
            hint: 'Teks yang ditampilkan di bagian bawah struk',
            controller: _footerController,
            leading: const Icon(Icons.vertical_align_bottom_rounded),
            errorText: _footerError,
            onChanged: (value) {
              formNotifier.setReceiptFooter(value);
              _validateFields();
            },
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview(SettingsFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pratinjau Struk',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ModernCard.outlined(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Shop name
              Text(
                formState.name.isEmpty ? 'Nama Toko' : formState.name,
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing8),

              // Header preview
              if (formState.receiptHeader.isNotEmpty) ...[
                Text(
                  formState.receiptHeader,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing8),
              ],

              // Divider
              const ModernDivider(),
              const SizedBox(height: AppDimensions.spacing8),

              // Sample items
              _buildPreviewItem('Produk A', 'Rp 25.000'),
              _buildPreviewItem('Produk B', 'Rp 15.000'),
              const SizedBox(height: AppDimensions.spacing8),
              const ModernDivider(),
              const SizedBox(height: AppDimensions.spacing8),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Rp 40.000',
                    style: AppTextStyles.priceMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),

              // Footer preview
              if (formState.receiptFooter.isNotEmpty) ...[
                const ModernDivider(),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  formState.receiptFooter,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewItem(String name, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: AppTextStyles.bodyMedium),
          Text(price, style: AppTextStyles.priceSmall),
        ],
      ),
    );
  }

  Future<void> _saveSettings(
    BuildContext context,
    SettingsFormNotifier formNotifier,
  ) async {
    // Validate fields before saving
    if (!_validateFields()) {
      return;
    }

    final success = await formNotifier.saveReceiptSettings();

    if (success && context.mounted) {
      ModernToast.success(context, 'Pengaturan struk berhasil disimpan');
      context.pop();
    } else if (!success && context.mounted) {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
