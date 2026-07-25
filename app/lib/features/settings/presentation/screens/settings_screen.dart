import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../../../../config/routes/app_router.dart';

/// Main settings hub screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(shopSettingsProvider);

    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Pengaturan',
        onProfileTap: () {},
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: ModernLoading()),
        error: (error, _) => ModernErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(shopSettingsProvider),
        ),
        data: (settings) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding = context.isMobile
              ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
              : AppDimensions.spacing16;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spacing16),

                // TOKO Section
                SettingsSection(
                  title: 'Toko',
                  children: [
                    SettingsTile.navigation(
                      icon: Icons.store_rounded,
                      iconColor: AppColors.primary,
                      title: 'Profil Toko',
                      subtitle: settings.name,
                      onTap: () => context.go(AppRoutes.settingsShopProfile),
                    ),
                    SettingsTile.navigation(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.info,
                      title: 'Pengaturan Struk',
                      subtitle: 'Header & footer struk',
                      onTap: () => context.go(AppRoutes.settingsReceipt),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // APLIKASI Section
                SettingsSection(
                  title: 'Aplikasi',
                  children: [
                    SettingsTile.navigation(
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.warning,
                      title: 'Pengaturan Aplikasi',
                      subtitle: 'Batas stok rendah: ${settings.lowStockThreshold}',
                      onTap: () => context.go(AppRoutes.settingsApp),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // LAINNYA Section
                SettingsSection(
                  title: 'Lainnya',
                  children: [
                    SettingsTile.navigation(
                      icon: Icons.backup_rounded,
                      iconColor: AppColors.success,
                      title: 'Backup & Restore',
                      subtitle: 'Cadangkan dan pulihkan data',
                      onTap: () => context.go(AppRoutes.settingsBackup),
                    ),
                    SettingsTile.navigation(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.textSecondary,
                      title: 'Tentang Aplikasi',
                      subtitle: 'Versi & informasi',
                      onTap: () => context.go(AppRoutes.settingsAbout),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // AKUN Section
                SettingsSection(
                  title: 'Akun',
                  children: [
                    SettingsTile.destructive(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      subtitle: 'Keluar dari akun Anda',
                      onTap: () async {
                        final confirmed = await ModernDialog.confirm(
                          context,
                          title: 'Keluar dari Akun',
                          message: 'Apakah Anda yakin ingin keluar?',
                          confirmLabel: 'Keluar',
                          isDestructive: true,
                        );
                        if (confirmed == true) {
                          ref
                              .read(authNotifierProvider.notifier)
                              .logout();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing32),
              ],
            ),
          );
        },
      ),
    );
  }
}
