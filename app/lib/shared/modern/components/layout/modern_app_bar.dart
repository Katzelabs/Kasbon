import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../utils/modern_variants.dart';
import '../data_display/modern_avatar.dart';
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
    this.showDivider,
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
    this.showDivider,
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
    this.showDivider,
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
    bool? showDivider,
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
      showDivider: showDivider,
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
    bool? showDivider,
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
      showDivider: showDivider,
    );
  }

  /// Creates an app bar with back button + title (left-aligned) and an
  /// account menu.
  ///
  /// Renders identically at every breakpoint: back button + title + avatar.
  /// Uses Riverpod providers for user info.
  ///
  /// Example:
  /// ```dart
  /// ModernAppBar.backWithActions(
  ///   title: 'Detail Produk',
  ///   onBack: () => context.pop(),
  /// )
  /// ```
  factory ModernAppBar.backWithActions({
    Key? key,
    required String title,
    VoidCallback? onBack,
    List<Widget>? additionalActions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
    bool? showDivider,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      leading: _BackButton(onBack: onBack),
      automaticallyImplyLeading: false,
      actions: [
        if (additionalActions != null) ...additionalActions,
        const _AccountMenu(),
      ],
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
      showDivider: showDivider,
    );
  }

  /// Creates an app bar with title (left-aligned) and an account menu, with no
  /// back button.
  ///
  /// For parent/main screens like Dashboard, Products list, etc.
  ///
  /// [additionalActions] land to the *left* of the avatar, which is where a
  /// screen's own primary action belongs off a phone: the header is the one
  /// piece of chrome that spans the whole content area, so an action placed
  /// there is in the same corner on every screen instead of hovering over
  /// whatever the body happens to be showing. Actions that only make sense with
  /// a pointer and a toolbar hide themselves at `compact` and leave the phone's
  /// floating button alone - see `ProductAddAction` and `PosCartAction`.
  ///
  /// Uses Riverpod providers for user info.
  ///
  /// Example:
  /// ```dart
  /// ModernAppBar.withActions(
  ///   title: 'Produk',
  ///   additionalActions: const [ProductAddAction()],
  /// )
  /// ```
  factory ModernAppBar.withActions({
    Key? key,
    required String title,
    List<Widget>? additionalActions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
    bool? showDivider,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      automaticallyImplyLeading: false,
      actions: [
        if (additionalActions != null) ...additionalActions,
        const _AccountMenu(),
      ],
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
      showDivider: showDivider,
    );
  }

  /// Creates the header for a split-view pane.
  ///
  /// A pane is not a route, so it has nothing to go back to and no business
  /// carrying the account menu - that belongs to the window, once, and a
  /// two-pane layout showing it twice is the giveaway that a screen was
  /// dropped into a pane without being told.
  ///
  /// [onClose] appears only where closing means something: a detail pane that
  /// can be dismissed back to the list. A permanent pane passes nothing and
  /// gets a title alone.
  ///
  /// For RESP_07. Nothing calls it yet, which is deliberate - a factory added
  /// with the split views would have arrived alongside the screens that need
  /// it and been designed around whichever came first.
  factory ModernAppBar.pane({
    Key? key,
    required String title,
    VoidCallback? onClose,
    List<Widget>? actions,
    Color? backgroundColor,
    Color? foregroundColor,
    ModernAppBarVariant variant = ModernAppBarVariant.flat,
    bool? showDivider,
  }) {
    return ModernAppBar(
      key: key,
      title: title,
      automaticallyImplyLeading: false,
      actions: [
        if (actions != null) ...actions,
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Tutup',
          ),
      ],
      centerTitle: false,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      variant: variant,
      showDivider: showDivider,
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

  /// Whether to draw a hairline along the bar's bottom edge.
  ///
  /// Null resolves per variant - see [_showsDivider].
  final bool? showDivider;

  /// Whether this bar closes itself off from the body with a hairline.
  ///
  /// On by default for the two variants that sit on [AppColors.surface]. Those
  /// bars are white, and so is every card directly under them, so without an
  /// edge the header and the first row of content read as one surface - most
  /// visibly on a wide window, where the bar is 1300dp of white with a title in
  /// the corner. The `flat` variant carries no shadow at all (see [_elevation]),
  /// which is precisely why it needs the line.
  ///
  /// Off for `primary` and `transparent`: a coloured bar already separates by
  /// hue, and a transparent one is drawn over a gradient header it is meant to
  /// disappear into - a hairline across that is a seam, not a separator.
  bool get _showsDivider {
    if (showDivider != null) return showDivider!;
    switch (variant) {
      case ModernAppBarVariant.elevated:
      case ModernAppBarVariant.flat:
        return true;
      case ModernAppBarVariant.primary:
      case ModernAppBarVariant.transparent:
        return false;
    }
  }

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
        // The white bar now sits above a tinted canvas, so the two separate by
        // value on their own. The old 1dp shadow drew a grey smudge under the
        // header on every screen to solve a problem that no longer exists.
        return 0;
      case ModernAppBarVariant.transparent:
        return 0;
    }
  }

  /// Gets the appropriate system overlay style based on background color.
  ///
  /// Primary variant has dark background, needs light (white) icons.
  /// All other variants have light backgrounds, need dark icons.
  ///
  /// Null on web and desktop, where there is no system status bar to style.
  /// `AppBar` pushes this to `SystemChrome` on every build, so returning a
  /// style there would be a platform call per frame that changes nothing.
  SystemUiOverlayStyle? get _effectiveSystemOverlayStyle {
    if (!AppPlatform.usesSystemOverlayStyle) return null;

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
                // h3 rather than h4: a screen title is the page's primary
                // heading and the mockups set it noticeably larger than body
                // chrome. At 18sp it competed with ordinary card headings.
                style: AppTextStyles.h3.copyWith(color: _foregroundColor),
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
      // A border on the bar's own shape rather than a divider widget in
      // [bottom]: `bottom` adds to `preferredSize`, so a 1dp line there would
      // push every screen's content down by a pixel and make the header 65dp on
      // some screens and 64dp on others. The shape paints inside the height the
      // bar already has, below `bottom` when one is present.
      shape: _showsDivider
          ? const Border(bottom: BorderSide(color: AppColors.border))
          : null,
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

/// Internal widget for the account menu shown at the end of the app bar
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Previously this returned an empty box below the tablet breakpoint, so
    // the mobile header carried a title and nothing else - and profile/logout
    // were reachable only by navigating to the Pengaturan tab.
    //
    // It also used to take an `onProfileTap` callback that it never read.
    // Twenty-four screens dutifully passed one - `() {}` or a `// TODO:
    // Navigate to profile` - and every one of them was wiring a handler to
    // nothing.
    final userInfo = ref.watch(userInfoProvider);

    return Padding(
      padding: const EdgeInsets.only(right: AppDimensions.spacing8),
      child: PopupMenuButton<String>(
        tooltip: 'Akun',
        onSelected: (value) {
          if (value == 'settings') {
            context.go(AppRoutes.settings);
          } else if (value == 'logout') {
            _handleAppBarLogout(context, ref);
          }
        },
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        itemBuilder: (context) => [
          // Who this menu is going to sign out. The avatar alone is two
          // letters; on a shared till it is worth being able to check the
          // account before using the item below it.
          if (userInfo.isSignedIn)
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userInfo.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    userInfo.email!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          if (userInfo.isSignedIn) const PopupMenuDivider(),
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
                Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                SizedBox(width: AppDimensions.spacing8),
                Text('Keluar', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
        child: SizedBox.square(
          // The avatar itself is smaller than a comfortable tap; pad it out to
          // the minimum target rather than relying on PopupMenuButton's default.
          dimension: AppDimensions.minTouchTarget,
          child: Center(
            child: ModernAvatar.small(
              imageUrl: userInfo.avatarUrl,
              initials: userInfo.initials,
            ),
          ),
        ),
      ),
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
