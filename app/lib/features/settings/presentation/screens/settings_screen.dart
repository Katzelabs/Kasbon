import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/constants/support_contacts.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../shared/providers/providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../receipt/domain/entities/shop_settings.dart';
import '../providers/about_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/settings_columns.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Main settings hub screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(shopSettingsProvider);

    // Calculate bottom padding based on device type to account for bottom nav
    final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;

    // A settings *row* is prose-shaped: an icon, a title and a one-line
    // subtitle, none of which get easier to read for being 2000px wide. So the
    // rows stay at reading width - what changes with the window is how many
    // columns of groups there are beside each other. Below `expanded` that is
    // one, and the clamp is the reading width it has always been; at `expanded`
    // and up two columns of groups fit inside the standard 1080dp column, which
    // is roughly two reading widths once the gutter is paid for.
    //
    // The tier is read here, outside `ModernContentColumn`, because the column
    // re-scopes to its own clamped width - asking inside would be asking about
    // the answer.
    final twoColumn = context.isAtLeast(Breakpoint.expanded);

    // The sections used to carry their own 16dp inset, which is now the
    // column's job, so they are handed `EdgeInsets.zero` and the tier padding
    // applies once.
    return Scaffold(
      appBar: ModernAppBar.withActions(title: 'Pengaturan'),
      body: ModernContentColumn(
        width: twoColumn ? ContentWidth.standard : ContentWidth.reading,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(shopSettingsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spacing16),

                // Who is signed in. Settings is the only screen in the app
                // where the account is the subject rather than the chrome, and
                // until now the email appeared nowhere at all - the avatar in
                // the header was a hardcoded "P" for every user.
                //
                // It spans both columns: it is the page's subject, not one of
                // the groups.
                const _AccountHeader(),

                // A failed load costs two subtitles, not the screen. The rows
                // below are all navigation and work regardless, so the error
                // goes in a strip that offers a retry rather than replacing
                // everything with a full-page error state.
                if (settingsAsync.hasError) ...[
                  const SizedBox(height: AppDimensions.spacing16),
                  _SettingsLoadError(
                    onRetry: () => ref.invalidate(shopSettingsProvider),
                  ),
                ],

                const SizedBox(height: AppDimensions.spacing24),

                SettingsColumns(
                  // What the owner configures.
                  start: [
                    _shopSection(context, settingsAsync),
                    _appSection(context, settingsAsync),
                    _dataSection(context),
                  ],
                  // What the app is, and who is signed in.
                  end: [
                    _aboutSection(context),
                    _accountSection(context, ref),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TOKO - the shop's own details.
  Widget _shopSection(
    BuildContext context,
    AsyncValue<ShopSettings> settingsAsync,
  ) {
    return SettingsSection(
      padding: EdgeInsets.zero,
      title: 'Toko',
      children: [
        SettingsTile.navigation(
          icon: Icons.store_rounded,
          iconColor: AppColors.primary,
          title: 'Profil Toko',
          subtitleWidget: _SettingsSubtitle(
            settingsAsync: settingsAsync,
            value: _shopProfileSummary,
          ),
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
    );
  }

  /// APLIKASI - how the app behaves.
  Widget _appSection(
    BuildContext context,
    AsyncValue<ShopSettings> settingsAsync,
  ) {
    return SettingsSection(
      padding: EdgeInsets.zero,
      title: 'Aplikasi',
      children: [
        SettingsTile.navigation(
          icon: Icons.tune_rounded,
          iconColor: AppColors.warning,
          title: 'Pengaturan Aplikasi',
          subtitleWidget: _SettingsSubtitle(
            settingsAsync: settingsAsync,
            value: (s) => 'Batas stok rendah: ${s.lowStockThreshold}',
          ),
          onTap: () => context.go(AppRoutes.settingsApp),
        ),
      ],
    );
  }

  /// DATA.
  ///
  /// Backup used to sit under "Lainnya" beside the about page, which filed the
  /// one screen that can destroy every row the user owns next to a version
  /// number.
  Widget _dataSection(BuildContext context) {
    return SettingsSection(
      padding: EdgeInsets.zero,
      title: 'Data',
      children: [
        SettingsTile.navigation(
          icon: Icons.backup_rounded,
          iconColor: AppColors.success,
          title: 'Backup & Restore',
          subtitle: 'Cadangkan dan pulihkan data',
          onTap: () => context.go(AppRoutes.settingsBackup),
        ),
      ],
    );
  }

  /// TENTANG - what the app is.
  Widget _aboutSection(BuildContext context) {
    return SettingsSection(
      padding: EdgeInsets.zero,
      title: 'Tentang',
      children: [
        SettingsTile.navigation(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.accentCyan,
          title: 'Tentang Aplikasi',
          subtitle: 'Bantuan, kontak & legal',
          onTap: () => context.go(AppRoutes.settingsAbout),
        ),
        // The policy is also a row on the about page, but it is named here too
        // on purpose. Both stores review the app by looking for the policy from
        // Settings, and a reviewer who has to guess that "Tentang Aplikasi"
        // hides it is a reviewer who may decide it is missing. It is the one
        // legal document the app is required to surface.
        SettingsTile.externalLink(
          icon: Icons.privacy_tip_outlined,
          iconColor: AppColors.textSecondary,
          title: 'Kebijakan Privasi',
          subtitle: 'Data apa yang disimpan & cara menghapusnya',
          onTap: () => ExternalLink.openUrl(
            context,
            SupportContacts.privacyUrl,
          ),
        ),
        // The version is the first thing asked for when someone reports a
        // problem, and it was two taps deep.
        SettingsTile.info(
          icon: Icons.verified_outlined,
          iconColor: AppColors.textSecondary,
          title: 'Versi Aplikasi',
          trailing: const _VersionLabel(),
        ),
      ],
    );
  }

  /// AKUN - the two ways out of it.
  Widget _accountSection(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      padding: EdgeInsets.zero,
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
              ref.read(authNotifierProvider.notifier).logout();
            }
          },
        ),
        // Required by both stores - Play wants an in-app route and a web one,
        // Apple wants in-app deletion from anything that creates accounts. It
        // sits below "Keluar" and nowhere else: a destructive row filed
        // anywhere but the account section is a row somebody taps by mistake.
        SettingsTile.destructive(
          icon: Icons.person_remove_rounded,
          title: 'Hapus Akun',
          subtitle: 'Hapus akun & seluruh data permanen',
          onTap: () => _confirmAccountDeletion(context),
        ),
      ],
    );
  }

  /// Runs the delete-account flow and handles the two ways out of it.
  ///
  /// Nothing is shown on success: the account is gone, the datasource has
  /// already signed out, and the router is mid-redirect to `/login` - a toast
  /// fired here would be attached to a screen that is being torn down. The
  /// failure cases never reach this method either; the dialog keeps them,
  /// because it is the only thing that can still show them against the right
  /// field.
  Future<void> _confirmAccountDeletion(BuildContext context) async {
    final outcome = await DeleteAccountDialog.show(context);

    if (outcome == DeleteAccountOutcome.backupRequested && context.mounted) {
      context.go(AppRoutes.settingsBackup);
    }
  }

  /// What the Profil Toko row reports underneath its title.
  ///
  /// The shop name alone said nothing about whether the profile was finished,
  /// and a blank address and phone are exactly what makes a printed receipt
  /// look unfinished. Naming what is missing turns the row into a prompt.
  static String _shopProfileSummary(ShopSettings settings) {
    final missing = <String>[
      if ((settings.address ?? '').trim().isEmpty) 'alamat',
      if ((settings.phone ?? '').trim().isEmpty) 'telepon',
    ];

    if (missing.isEmpty) return settings.name;
    return '${settings.name} · Lengkapi ${missing.join(' & ')}';
  }
}

/// The signed-in account, at the top of the hub.
class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userInfoProvider);

    return ModernCard.filled(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          ModernAvatar.large(
            imageUrl: user.avatarUrl,
            initials: user.initials,
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  user.email ?? 'Belum masuk',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtitle that is a skeleton line until the settings arrive.
///
/// Only two rows on this screen depend on the server, so the hub no longer
/// hides all seven behind a spinner while one request is in flight.
class _SettingsSubtitle extends StatelessWidget {
  const _SettingsSubtitle({
    required this.settingsAsync,
    required this.value,
  });

  final AsyncValue<ShopSettings> settingsAsync;
  final String Function(ShopSettings) value;

  @override
  Widget build(BuildContext context) {
    final settings = settingsAsync.valueOrNull;

    if (settings == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing2),
        child: ModernSkeleton(
          // A skeleton that keeps shimmering after the request has already
          // failed is promising something that is not coming.
          enabled: !settingsAsync.hasError,
          child: const ModernSkeletonBox.text(width: 140),
        ),
      );
    }

    return Text(
      value(settings),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Inline notice that the shop settings could not be read.
class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.error,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Text(
              'Gagal memuat data toko',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          ModernButton.text(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

/// The app version, as the trailing value of its row.
class _VersionLabel extends ConsumerWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfo = ref.watch(appInfoProvider);

    return Text(
      appInfo.valueOrNull?.fullVersion ?? '—',
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}
