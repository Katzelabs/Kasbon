import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/about_provider.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Screen showing app information and external links
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfoAsync = ref.watch(appInfoProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Tentang Aplikasi',
        onBack: () => context.pop(),
        onProfileTap: () {},
      ),
      body: Builder(
        builder: (context) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding = context.isMobile
              ? AppDimensions.bottomNavHeight + AppDimensions.spacing16
              : AppDimensions.spacing16;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              top: AppDimensions.spacing16,
              bottom: bottomPadding,
            ),
            child: Column(
              children: [
                // App logo and info
                _buildAppHeader(context, appInfoAsync),

                const SizedBox(height: AppDimensions.spacing32),

                // Contact section
                SettingsSection(
                  title: 'Hubungi Kami',
                  children: [
                    SettingsTile.externalLink(
                      icon: Icons.chat_rounded,
                      iconColor: AppColors.whatsapp,
                      title: 'WhatsApp',
                      subtitle: 'Kirim pesan via WhatsApp',
                      onTap: () => _launchWhatsApp(context),
                    ),
                    SettingsTile.externalLink(
                      icon: Icons.email_rounded,
                      iconColor: AppColors.info,
                      title: 'Email',
                      subtitle: 'support@kasbon.app',
                      onTap: () => _launchEmail(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing24),

                // Legal section
                SettingsSection(
                  title: 'Legal',
                  children: [
                    SettingsTile.externalLink(
                      icon: Icons.description_rounded,
                      iconColor: AppColors.textSecondary,
                      title: 'Syarat & Ketentuan',
                      onTap: () => _launchUrl(context, 'https://kasbon.app/terms'),
                    ),
                    SettingsTile.externalLink(
                      icon: Icons.privacy_tip_rounded,
                      iconColor: AppColors.textSecondary,
                      title: 'Kebijakan Privasi',
                      onTap: () => _launchUrl(context, 'https://kasbon.app/privacy'),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing32),

                // Copyright
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing16,
                  ),
                  child: Text(
                    '© 2024 KASBON. Hak Cipta Dilindungi.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppHeader(
    BuildContext context,
    AsyncValue<AppInfo> appInfoAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Column(
        children: [
          // App icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),

          // App name
          Text(
            'KASBON',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),

          // Tagline
          Text(
            'Kasir Digital untuk UMKM Indonesia',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Version
          appInfoAsync.when(
            data: (info) => ModernBadge.neutral(
              label: 'Versi ${info.fullVersion}',
            ),
            loading: () => const SizedBox(
              height: 24,
              width: 80,
              child: ModernLoading.small(),
            ),
            error: (_, __) => const ModernBadge.neutral(
              label: 'Versi 1.0.0',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phoneNumber = '6281234567890'; // Replace with actual number
    const message = 'Halo, saya ingin bertanya tentang aplikasi KASBON';
    final url = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ModernToast.error(context, 'Tidak dapat membuka WhatsApp');
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final url = Uri.parse('mailto:support@kasbon.app?subject=Bantuan KASBON');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ModernToast.error(context, 'Tidak dapat membuka email');
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ModernToast.error(context, 'Tidak dapat membuka link');
      }
    }
  }
}
