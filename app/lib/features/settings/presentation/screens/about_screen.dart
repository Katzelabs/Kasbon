import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/constants/support_contacts.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/brand/kasbon_mark.dart';
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
      ),
      body: Builder(
        builder: (context) {
          // Calculate bottom padding based on device type to account for bottom nav
          final bottomPadding =
              AppDimensions.spacing16 + context.shellBottomInset;

          // Prose width, like the settings hub: the contact and legal rows
          // are the same one-line shape and gain nothing from a wider column.
          // The sections and the header carried their own 16dp inset, which is
          // now the content column's, so both are handed zero.
          return ModernContentColumn.reading(
            child: SingleChildScrollView(
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
                    padding: EdgeInsets.zero,
                    title: 'Hubungi Kami',
                    children: [
                      SettingsTile.externalLink(
                        icon: Icons.chat_rounded,
                        iconColor: AppColors.whatsapp,
                        title: 'WhatsApp',
                        // The number itself, not "Kirim pesan via WhatsApp":
                        // a support row that names its destination can be
                        // acted on without tapping it, which matters when the
                        // app is the thing that is broken.
                        subtitle: SupportContacts.whatsAppDisplay,
                        onTap: () => _launchWhatsApp(context),
                      ),
                      SettingsTile.externalLink(
                        icon: Icons.email_rounded,
                        iconColor: AppColors.info,
                        title: 'Email',
                        subtitle: SupportContacts.supportEmail,
                        onTap: () => _launchEmail(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Legal section
                  SettingsSection(
                    padding: EdgeInsets.zero,
                    title: 'Legal',
                    children: [
                      SettingsTile.externalLink(
                        icon: Icons.description_rounded,
                        iconColor: AppColors.textSecondary,
                        title: 'Syarat & Ketentuan',
                        onTap: () =>
                            _launchUrl(context, SupportContacts.termsUrl),
                      ),
                      SettingsTile.externalLink(
                        icon: Icons.privacy_tip_rounded,
                        iconColor: AppColors.textSecondary,
                        title: 'Kebijakan Privasi',
                        onTap: () =>
                            _launchUrl(context, SupportContacts.privacyUrl),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spacing32),

                  // Copyright.
                  //
                  // Stamped from the clock rather than typed: the literal here
                  // said 2024 well into 2026, which is the one line on this
                  // screen whose whole job is to look current.
                  Text(
                    '© ${DateTime.now().year} KASBON. Hak Cipta Dilindungi.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppDimensions.spacing16),
                ],
              ),
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
    return Column(
      children: [
        // The app icon, drawn the way it ships. No glow: on a settings page the
        // tile is an identifying detail, not the product introducing itself.
        const KasbonLogoTile(size: 80, glow: false),
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
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    await _launch(
      context,
      SupportContacts.whatsAppUri,
      failureMessage: 'Tidak dapat membuka WhatsApp',
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    await _launch(
      context,
      SupportContacts.supportEmailUri,
      // `mailto:` has no external-application equivalent to fall back on, so
      // it goes out with the platform default.
      mode: LaunchMode.platformDefault,
      failureMessage: 'Tidak dapat membuka email',
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    await _launch(
      context,
      Uri.parse(urlString),
      failureMessage: 'Tidak dapat membuka link',
    );
  }

  /// One launch path for all four rows.
  ///
  /// `canLaunchUrl` is consulted but not trusted as a veto: on the web it
  /// answers for a scheme rather than for a handler, and on Android it needs a
  /// `<queries>` entry to answer honestly at all - so a false there is a
  /// "probably not", and the attempt is still worth making. The error only
  /// surfaces once the launch itself has actually failed.
  Future<void> _launch(
    BuildContext context,
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
    required String failureMessage,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(url, mode: mode);
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      ModernToast.error(context, failureMessage);
    }
  }
}
