import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../utils/modern_variants.dart';
import '../data_display/modern_avatar.dart';
import '../data_display/modern_badge.dart';
import '../feedback/modern_dialog.dart';

/// A Modern-styled app bar with consistent theming and convenience constructors
///
/// Example:
/// ```dart
/// ModernAppBar(title: 'Produk')
/// ModernAppBar.back(title: 'Detail Produk', onBack: () => context.pop())
/// ModernAppBar.transparent(title: 'Dashboard')
/// ```
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ModernAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.bottom,
    this.variant = ModernAppBarVariant.elevated,
    this.systemOverlayStyle,
  });

  /// Creates a primary-colored app bar
  const ModernAppBar.primary({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.centerTitle = true,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.bottom,
    this.systemOverlayStyle,
  })  : variant = ModernAppBarVariant.primary,
        backgroundColor = AppColors.primary,
        foregroundColor = AppColors.onPrimary;

  /// Creates a transparent app bar
  const ModernAppBar.transparent({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.centerTitle = true,
    this.foregroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.bottom,
    this.systemOverlayStyle,
  })  : variant = ModernAppBarVariant.transparent,
        backgroundColor = Colors.transparent,
        elevation = 0;

  /// Creates an app bar with a back button
  factory ModernAppBar.back({
    Key? key,
    required String title,
    VoidCallback? onBack,
    List<Widget>? actions,
    bool centerTitle = true,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      leading: _BackButton(onBack: onBack),
      automaticallyImplyLeading: false,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
    );
  }

  /// Creates an app bar with a search field
  factory ModernAppBar.search({
    Key? key,
    required Widget searchField,
    VoidCallback? onBack,
    List<Widget>? actions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
  }) {
    return ModernAppBar(
      key: key,
      titleWidget: searchField,
      leading: onBack != null ? _BackButton(onBack: onBack) : null,
      automaticallyImplyLeading: false,
      actions: actions,
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
    );
  }

  /// Creates an app bar with user info display (for tablet layout)
  ///
  /// Shows notification button and user avatar/info on the right side.
  /// Example:
  /// ```dart
  /// ModernAppBar.withUserInfo(
  ///   title: 'Beranda',
  ///   userName: 'John Doe',
  ///   userRole: 'Kasir',
  ///   onNotificationTap: () => {},
  ///   onProfileTap: () => {},
  /// )
  /// ```
  factory ModernAppBar.withUserInfo({
    Key? key,
    required String title,
    String? userName,
    String? userRole,
    String? userAvatarUrl,
    VoidCallback? onNotificationTap,
    VoidCallback? onProfileTap,
    List<Widget>? actions,
    bool showBackButton = false,
    VoidCallback? onBack,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
  }) {
    final userInfoActions = <Widget>[
      // Custom actions first
      if (actions != null) ...actions,
      // Notification button
      IconButton(
        onPressed: onNotificationTap,
        icon: const Icon(Icons.notifications_outlined),
        color: AppColors.textSecondary,
      ),
      // User info
      const SizedBox(width: AppDimensions.spacing8),
      _UserInfoWidget(
        userName: userName,
        userRole: userRole,
        userAvatarUrl: userAvatarUrl,
        onTap: onProfileTap,
      ),
      const SizedBox(width: AppDimensions.spacing8),
    ];

    return ModernAppBar(
      key: key,
      title: title,
      leading: showBackButton ? _BackButton(onBack: onBack) : null,
      automaticallyImplyLeading: false,
      actions: userInfoActions,
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
    );
  }

  /// Creates an app bar with back button + title (left-aligned) and responsive actions
  ///
  /// Mobile: Back button + title + notification icon with badge
  /// Tablet: Back button + title + notification icon with badge + avatar
  ///
  /// Uses Riverpod providers for user info and notification count.
  ///
  /// Example:
  /// ```dart
  /// ModernAppBar.backWithActions(
  ///   title: 'Detail Produk',
  ///   onBack: () => context.pop(),
  ///   onNotificationTap: () => context.push('/notifications'),
  ///   onProfileTap: () => context.push('/profile'),
  /// )
  /// ```
  factory ModernAppBar.backWithActions({
    Key? key,
    required String title,
    VoidCallback? onBack,
    VoidCallback? onNotificationTap,
    VoidCallback? onProfileTap,
    List<Widget>? additionalActions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      leading: _BackButton(onBack: onBack),
      automaticallyImplyLeading: false,
      actions: [
        if (additionalActions != null) ...additionalActions,
        _ResponsiveActionsWidget(
          onNotificationTap: onNotificationTap,
          onProfileTap: onProfileTap,
        ),
      ],
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
    );
  }

  /// Creates an app bar with title (left-aligned) and responsive actions (no back button)
  ///
  /// For parent/main screens like Dashboard, Products list, etc.
  ///
  /// Mobile: Title + notification icon with badge
  /// Tablet: Title + notification icon with badge + avatar
  ///
  /// Uses Riverpod providers for user info and notification count.
  ///
  /// Example:
  /// ```dart
  /// ModernAppBar.withActions(
  ///   title: 'Produk',
  ///   onNotificationTap: () => context.push('/notifications'),
  ///   onProfileTap: () => context.push('/profile'),
  /// )
  /// ```
  factory ModernAppBar.withActions({
    Key? key,
    required String title,
    VoidCallback? onNotificationTap,
    VoidCallback? onProfileTap,
    List<Widget>? additionalActions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      automaticallyImplyLeading: false,
      actions: [
        if (additionalActions != null) ...additionalActions,
        _ResponsiveActionsWidget(
          onNotificationTap: onNotificationTap,
          onProfileTap: onProfileTap,
        ),
      ],
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
    );
  }

  /// The title text to display
  final String? title;

  /// A custom widget to display as title (overrides [title])
  final Widget? titleWidget;

  /// The leading widget (typically a back button or menu icon)
  final Widget? leading;

  /// Whether to automatically add a leading widget if none specified
  final bool automaticallyImplyLeading;

  /// Action widgets to display on the right side
  final List<Widget>? actions;

  /// Whether to center the title
  final bool centerTitle;

  /// The background color of the app bar
  final Color? backgroundColor;

  /// The foreground color (text and icons)
  final Color? foregroundColor;

  /// The elevation/shadow of the app bar
  final double? elevation;

  /// The shadow color
  final Color? shadowColor;

  /// The surface tint color (Material 3)
  final Color? surfaceTintColor;

  /// A widget to display below the app bar
  final PreferredSizeWidget? bottom;

  /// The visual style variant of the app bar
  final ModernAppBarVariant variant;

  /// The system overlay style for status bar
  final SystemUiOverlayStyle? systemOverlayStyle;

  Color get _backgroundColor {
    if (backgroundColor != null) return backgroundColor!;
    switch (variant) {
      case ModernAppBarVariant.primary:
        return AppColors.primary;
      case ModernAppBarVariant.transparent:
        return Colors.transparent;
      case ModernAppBarVariant.elevated:
      case ModernAppBarVariant.flat:
        return AppColors.surface;
    }
  }

  Color get _foregroundColor {
    if (foregroundColor != null) return foregroundColor!;
    switch (variant) {
      case ModernAppBarVariant.primary:
        return AppColors.onPrimary;
      case ModernAppBarVariant.transparent:
      case ModernAppBarVariant.elevated:
      case ModernAppBarVariant.flat:
        return AppColors.textPrimary;
    }
  }

  double get _elevation {
    if (elevation != null) return elevation!;
    switch (variant) {
      case ModernAppBarVariant.elevated:
        return 2;
      case ModernAppBarVariant.flat:
      case ModernAppBarVariant.primary:
        return 1; // Thin shadow for visual separation
      case ModernAppBarVariant.transparent:
        return 0;
    }
  }

  /// Gets the appropriate system overlay style based on background color.
  ///
  /// Primary variant has dark background, needs light (white) icons.
  /// All other variants have light backgrounds, need dark icons.
  SystemUiOverlayStyle get _effectiveSystemOverlayStyle {
    if (systemOverlayStyle != null) return systemOverlayStyle!;

    final brightness = variant == ModernAppBarVariant.primary
        ? Brightness.light
        : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness,
      // iOS uses opposite convention: statusBarBrightness describes the bar itself
      statusBarBrightness: brightness == Brightness.dark
          ? Brightness.light // iOS: light status bar for dark icons
          : Brightness.dark, // iOS: dark status bar for light icons
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = titleWidget ??
        (title != null
            ? Text(
                title!,
                style: AppTextStyles.h4.copyWith(color: _foregroundColor),
              )
            : null);

    return AppBar(
      title: effectiveTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: _backgroundColor,
      foregroundColor: _foregroundColor,
      elevation: _elevation,
      shadowColor: shadowColor ?? AppColors.shadow,
      surfaceTintColor: surfaceTintColor ?? Colors.transparent,
      bottom: bottom,
      systemOverlayStyle: _effectiveSystemOverlayStyle,
      iconTheme: IconThemeData(
        color: _foregroundColor,
        size: AppDimensions.iconLarge,
      ),
      actionsIconTheme: IconThemeData(
        color: _foregroundColor,
        size: AppDimensions.iconLarge,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        AppDimensions.appBarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// Internal back button widget
class _BackButton extends StatelessWidget {
  const _BackButton({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      tooltip: 'Kembali',
    );
  }
}

/// Internal user info widget for app bar
class _UserInfoWidget extends StatelessWidget {
  const _UserInfoWidget({
    this.userName,
    this.userRole,
    this.userAvatarUrl,
    this.onTap,
  });

  final String? userName;
  final String? userRole;
  final String? userAvatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing8,
          vertical: AppDimensions.spacing4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userName ?? 'User',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  userRole ?? 'Kasir',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.spacing12),
            _buildAvatar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: AppDimensions.avatarMedium,
      height: AppDimensions.avatarMedium,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
        image: userAvatarUrl != null
            ? DecorationImage(
                image: NetworkImage(userAvatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: userAvatarUrl == null
          ? Center(
              child: Text(
                (userName ?? 'U')[0].toUpperCase(),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}

/// Internal widget for responsive actions (notification + avatar on tablet)
class _ResponsiveActionsWidget extends ConsumerWidget {
  const _ResponsiveActionsWidget({
    this.onNotificationTap,
    this.onProfileTap,
  });

  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationCount = ref.watch(notificationCountProvider);
    final userInfo = ref.watch(userInfoProvider);
    final isTabletOrDesktop = context.isTabletOrDesktop;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notification button with badge
        _NotificationButton(
          count: notificationCount,
          onTap: onNotificationTap,
        ),
        // Avatar with popup menu (tablet/desktop only)
        if (isTabletOrDesktop) ...[
          const SizedBox(width: AppDimensions.spacing8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                context.push('/settings');
              } else if (value == 'logout') {
                _handleAppBarLogout(context, ref);
              }
            },
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary, size: 20),
                    SizedBox(width: AppDimensions.spacing8),
                    Text('Pengaturan'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 20),
                    SizedBox(width: AppDimensions.spacing8),
                    Text('Keluar',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
            child: ModernAvatar.small(
              imageUrl: userInfo.avatarUrl,
              initials: userInfo.initials,
            ),
          ),
        ],
        const SizedBox(width: AppDimensions.spacing8),
      ],
    );
  }
}

/// Handles logout from the app bar popup menu
Future<void> _handleAppBarLogout(BuildContext context, WidgetRef ref) async {
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
}

/// Internal notification button with badge
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.count,
    this.onTap,
  });

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.textSecondary,
          tooltip: 'Notifikasi',
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: ModernCounterBadge(count: count),
          ),
      ],
    );
  }
}
