import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/settings_provider.dart';
import '../widgets/unsaved_changes_guard.dart';

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

  /// Whether the controllers have been filled from the loaded settings.
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Fills the controllers the first time the settings are available.
  ///
  /// Called from `build` immediately before the form subtree is constructed for
  /// the first time, which is the one moment where writing to a controller is
  /// free: no `TextField` is listening yet, so there is nothing to notify
  /// mid-build.
  ///
  /// The old arrangement loaded from a post-frame callback with `isLoading`
  /// defaulting to false, so the form rendered empty, then as a spinner, then
  /// finally with values - a blank-field flash on every visit.
  void _seedControllers(SettingsFormState state) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = state.name;
    _addressController.text = state.address;
    _phoneController.text = state.phone;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(settingsFormProvider);
    final formNotifier = ref.read(settingsFormProvider.notifier);
    final isDirty = formState.isShopProfileDirty;

    return UnsavedChangesGuard(
      isDirty: isDirty,
      child: Scaffold(
        appBar: ModernAppBar.backWithActions(
          title: 'Profil Toko',
          onBack: () => UnsavedChangesGuard.maybePop(context, isDirty: isDirty),
        ),
        body: _buildBody(formState, formNotifier),
      ),
    );
  }

  Widget _buildBody(
    SettingsFormState formState,
    SettingsFormNotifier formNotifier,
  ) {
    if (formState.isLoading) {
      return const Center(child: ModernLoading());
    }

    // This branch used to read `formState.error != null && !_initialized`, and
    // `_initialized` was set to true before the load was even started - so the
    // condition could never be true, and a failed load rendered a blank form
    // with no message and no way to retry.
    if (formState.hasLoadError) {
      return ModernErrorState(
        message: formState.error!,
        onRetry: formNotifier.loadSettings,
      );
    }

    _seedControllers(formState);
    final isDirty = formState.isShopProfileDirty;

    return Builder(
      builder: (context) {
        // Calculate bottom padding based on device type to account for bottom nav
        final bottomPadding =
            AppDimensions.spacing16 + context.shellBottomInset;

        // Three fields and a save button. Form width, so the
        // inputs stay a length the eye can track from label to
        // value instead of spanning the whole window.
        return ModernContentColumn.form(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: AppDimensions.spacing16,
              bottom: bottomPadding,
            ),
            child: Form(
              key: _formKey,
              // Single column, so no reordering is needed - the group
              // is here to bound traversal to the form. Without it
              // Tab leaves the last field for the app bar's account
              // menu rather than reaching Simpan.
              child: FocusTraversalGroup(
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
                            onChanged: formNotifier.setName,
                            validator: _validateName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                          ),
                          const SizedBox(height: AppDimensions.spacing16),

                          // Shop address field (optional)
                          ModernTextField(
                            label: 'Alamat Toko',
                            hint: 'Masukkan alamat toko (opsional)',
                            controller: _addressController,
                            leading: const Icon(Icons.location_on_rounded),
                            onChanged: formNotifier.setAddress,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            // Says why the field is worth filling in. Both
                            // optional fields here are printed on every
                            // receipt, which is not obvious from the label.
                            helperText: 'Ditampilkan pada struk',
                          ),
                          const SizedBox(height: AppDimensions.spacing16),

                          // Shop phone field (optional)
                          ModernTextField(
                            label: 'Nomor Telepon',
                            hint: 'Masukkan nomor telepon (opsional)',
                            controller: _phoneController,
                            leading: const Icon(Icons.phone_rounded),
                            keyboardType: TextInputType.phone,
                            onChanged: formNotifier.setPhone,
                            validator: _validatePhone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\-\s]'),
                              ),
                            ],
                            helperText: 'Ditampilkan pada struk',
                            // Last field in the form, so the keyboard's action
                            // key should finish the job rather than dropping
                            // focus and leaving Simpan under the keyboard.
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (isDirty) _saveProfile(context, formNotifier);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),

                    // Save button.
                    //
                    // Disabled until something actually changes: an enabled
                    // Simpan on an untouched form invites a pointless round
                    // trip, and it makes the button useless as a signal that
                    // there is work outstanding.
                    ModernButton.primary(
                      fullWidth: true,
                      isLoading: formState.isSaving,
                      onPressed: isDirty
                          ? () => _saveProfile(context, formNotifier)
                          : null,
                      child: Text(isDirty ? 'Simpan' : 'Tersimpan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    if (!context.mounted) return;

    if (success) {
      ModernToast.success(context, 'Profil toko berhasil disimpan');
      // Safe to pop directly: the save reset the baseline, so the guard has
      // nothing to warn about.
      context.pop();
    } else {
      final error = ref.read(settingsFormProvider).error;
      if (error != null) {
        ModernToast.error(context, error);
      }
    }
  }
}
