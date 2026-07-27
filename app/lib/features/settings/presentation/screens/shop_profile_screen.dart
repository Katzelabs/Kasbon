import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/settings_provider.dart';

/// Screen for editing shop profile (name, address, phone)
class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
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
          _nameController.text = state.name;
          _addressController.text = state.address;
          _phoneController.text = state.phone;
        }
      });
    }

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Profil Toko',
        onBack: () => context.pop(),
        onProfileTap: () {},
      ),
      body: formState.isLoading
          ? const Center(child: ModernLoading())
          : formState.error != null && !_initialized
              ? ModernErrorState(
                  message: formState.error!,
                  onRetry: () => formNotifier.loadSettings(),
                )
              : Builder(
                  builder: (context) {
                    // Calculate bottom padding based on device type to account for bottom nav
                    final bottomPadding =
                        AppDimensions.spacing16 + context.shellBottomInset;

                    return SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: AppDimensions.spacing16,
                        right: AppDimensions.spacing16,
                        top: AppDimensions.spacing16,
                        bottom: bottomPadding,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Form fields card
                            ModernCard.elevated(
                              padding: const EdgeInsets.all(AppDimensions.spacing16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Shop name field (required)
                                  ModernTextField(
                                    label: 'Nama Toko',
                                    hint: 'Masukkan nama toko',
                                    controller: _nameController,
                                    leading: const Icon(Icons.store_rounded),
                                    onChanged: (value) => formNotifier.setName(value),
                                    validator: _validateName,
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                  const SizedBox(height: AppDimensions.spacing16),

                                  // Shop address field (optional)
                                  ModernTextField(
                                    label: 'Alamat Toko',
                                    hint: 'Masukkan alamat toko (opsional)',
                                    controller: _addressController,
                                    leading: const Icon(Icons.location_on_rounded),
                                    onChanged: (value) =>
                                        formNotifier.setAddress(value),
                                    maxLines: 2,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: AppDimensions.spacing16),

                                  // Shop phone field (optional)
                                  ModernTextField(
                                    label: 'Nomor Telepon',
                                    hint: 'Masukkan nomor telepon (opsional)',
                                    controller: _phoneController,
                                    leading: const Icon(Icons.phone_rounded),
                                    keyboardType: TextInputType.phone,
                                    onChanged: (value) =>
                                        formNotifier.setPhone(value),
                                    validator: _validatePhone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9+\-\s]'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacing24),

                            // Save button
                            ModernButton.primary(
                              fullWidth: true,
                              isLoading: formState.isSaving,
                              onPressed: () => _saveProfile(context, formNotifier),
                              child: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama toko tidak boleh kosong';
    }
    if (value.trim().length < 2) {
      return 'Nama toko minimal 2 karakter';
    }
    if (value.trim().length > 100) {
      return 'Nama toko maksimal 100 karakter';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    // Remove spaces and dashes for validation
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanPhone.length < 8) {
      return 'Nomor telepon minimal 8 digit';
    }
    if (cleanPhone.length > 15) {
      return 'Nomor telepon maksimal 15 digit';
    }
    // Check if it starts with valid prefix (0 or +62 for Indonesia)
    if (!RegExp(r'^(\+62|0)[0-9]+$').hasMatch(cleanPhone)) {
      return 'Format nomor telepon tidak valid';
    }
    return null;
  }

  Future<void> _saveProfile(
    BuildContext context,
    SettingsFormNotifier formNotifier,
  ) async {
    // Validate form first
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final success = await formNotifier.saveShopProfile();

    if (success && context.mounted) {
      ModernToast.success(context, 'Profil toko berhasil disimpan');
      context.pop();
    } else if (!success && context.mounted) {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
