import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../providers/navigation_sidebar_provider.dart';
import '../../../providers/shell_account_provider.dart';
import '../data_display/modern_avatar.dart';
import '../../utils/modern_variants.dart';

/// Navigation item data for ModernAppShell
class ModernNavItem {
  /// The icon to display when not selected
  final IconData icon;

  /// The icon to display when selected (optional)
  final IconData? activeIcon;

  /// The label text
  final String label;

  /// The route path for navigation
  final String routePath;

  const ModernNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.routePath,
  });
}

/// The four destinations the compact bottom bar can hold.
///
/// Four, not seven, because the bar also carries a notched FAB in its middle.
/// POS, Hutang and Laporan are unreachable from here and live behind the FAB
/// and the dashboard - which is precisely the gap the rail closes from `medium`
/// upward.
const List<ModernNavItem> defaultCompactNavItems = [
  ModernNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Beranda',
    routePath: '/dashboard',
  ),
  ModernNavItem(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Produk',
    routePath: '/products',
  ),
  ModernNavItem(
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    label: 'Transaksi',
    routePath: '/transactions',
  ),
  ModernNavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Pengaturan',
    routePath: '/settings',
  ),
];

/// Every destination, in the order `Ctrl/Cmd+1..7` addresses them.
///
/// The rail shows all seven at `medium` and up. The ordering is load-bearing
/// twice over: it is the visual order of the rail, and it is the keyboard
/// shortcut mapping, so inserting an item renumbers the shortcuts.
const List<ModernNavItem> defaultRailNavItems = [
  ModernNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Beranda',
    routePath: '/dashboard',
  ),
  ModernNavItem(
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale,
    label: 'Kasir',
    routePath: '/pos',
  ),
  ModernNavItem(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Produk',
    routePath: '/products',
  ),
  ModernNavItem(
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    label: 'Transaksi',
    routePath: '/transactions',
  ),
  ModernNavItem(
    icon: Icons.credit_card_off_outlined,
    activeIcon: Icons.credit_card_off,
    label: 'Hutang',
    routePath: '/debts',
  ),
  ModernNavItem(
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    label: 'Laporan',
    routePath: '/reports',
  ),
  ModernNavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Pengaturan',
    routePath: '/settings',
  ),
];

/// Digits 1..7, in the order they map onto [defaultRailNavItems].
///
/// `LogicalKeyboardKey` has no way to derive `digitN` from an index, so the
/// list is spelled out. It is trimmed to the item count at bind time, which is
/// what keeps a custom seven-plus-item list from throwing.
const List<LogicalKeyboardKey> _destinationDigits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
];

/// The app's responsive navigation shell.
///
/// ## Tier → chrome
///
/// | Tier       | Width      | Chrome                                        |
/// |------------|------------|-----------------------------------------------|
/// | `compact`  | < 600dp    | Bottom nav (4 items) + notched FAB            |
/// | `medium`   | 600-899dp  | Collapsed 80dp rail, 7 items, no toggle       |
/// | `expanded` | 900-1299dp | Rail, collapsible 80↔280, default collapsed   |
/// | `large`    | >= 1300dp  | Rail, default expanded to 280dp with labels   |
///
/// `medium` is the behaviour change RESP_04 exists for. An iPad in portrait
/// (834dp) used to get the phone build: a four-item bottom bar with POS,
/// Hutang and Laporan simply missing. It now gets the rail and all seven.
///
/// The paired change is in `ModernShellInsets.shellBottomInset`, which stops
/// reserving 80px below every screen in that band. The two must move together
/// or 600-899dp gets padding for a bar that is no longer drawn.
///
/// Note: the app bar is owned by individual screens via [ModernAppBar]. This
/// shell provides navigation only.
///
/// Example:
/// ```dart
/// ModernAppShell(
///   child: child,
///   currentPath: '/dashboard',
/// )
/// ```
class ModernAppShell extends ConsumerStatefulWidget {
  const ModernAppShell({
    super.key,
    required this.child,
    required this.currentPath,
    this.compactNavItems,
    this.railNavItems,
    this.onNavigate,
    this.showFab = true,
    this.fabIcon = Icons.point_of_sale,
    this.onFabPressed,
  });

  /// The main content widget
  final Widget child;

  /// The current route path
  final String currentPath;

  /// Destinations for the compact bottom bar.
  /// Defaults to [defaultCompactNavItems].
  final List<ModernNavItem>? compactNavItems;

  /// Destinations for the navigation rail, `medium` and up.
  /// Defaults to [defaultRailNavItems].
  final List<ModernNavItem>? railNavItems;

  /// Callback when a navigation item is tapped
  /// If null, uses GoRouter navigation
  final void Function(String routePath)? onNavigate;

  /// Whether to show the center FAB on compact
  final bool showFab;

  /// Icon for the center FAB
  final IconData fabIcon;

  /// Callback when FAB is pressed
  final VoidCallback? onFabPressed;

  @override
  ConsumerState<ModernAppShell> createState() => _ModernAppShellState();
}

class _ModernAppShellState extends ConsumerState<ModernAppShell> {
  List<ModernNavItem> get _compactItems =>
      widget.compactNavItems ?? defaultCompactNavItems;

  List<ModernNavItem> get _railItems =>
      widget.railNavItems ?? defaultRailNavItems;

  int _getNavIndexFromPath(String path, List<ModernNavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (path.startsWith(items[i].routePath)) {
        return i;
      }
    }
    return 0;
  }

  void _onNavigate(String routePath) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(routePath);
    } else {
      context.go(routePath);
    }
  }

  void _onFabTap() {
    if (widget.onFabPressed != null) {
      widget.onFabPressed!();
    } else {
      context.go('/pos');
    }
  }

  void _toggleSidebar(Breakpoint tier) {
    ref.read(navigationSidebarExpandedProvider.notifier).toggle(tier);
  }

  /// Get the actual current path from GoRouter for nested routes
  String _getCurrentPath(BuildContext context) {
    // Try to get the full path from GoRouterState for nested routes
    try {
      final routerState = GoRouterState.of(context);
      return routerState.uri.path;
    } catch (_) {
      // Fallback to widget prop if GoRouterState is not available
      return widget.currentPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get actual current path (handles nested routes correctly)
    final actualPath = _getCurrentPath(context);

    // The window, not the container. This is shell chrome deciding what the
    // whole window looks like - the one case `windowBreakpoint` is for.
    final tier = context.windowBreakpoint;

    final shell = tier.isCompact
        ? _buildCompactShell(actualPath)
        : _buildRailShell(actualPath, tier);

    return _withDestinationShortcuts(shell);
  }

  /// Binds `Ctrl/Cmd+1..7` to the rail destinations.
  ///
  /// Both modifiers are registered rather than branching on the platform: the
  /// app runs on macOS, Windows, Linux and the web, and a user on a Mac with a
  /// PC keyboard reaches for Ctrl. Neither combination collides with a text
  /// field's own bindings.
  ///
  /// The shortcuts stay bound at every tier, including `compact`. A narrow
  /// desktop window still has a keyboard, and the four-item bottom bar is
  /// exactly where the other three destinations are hardest to reach.
  ///
  /// The [Focus] wrapper is load-bearing. Key events walk *up* from the node
  /// holding primary focus; with nothing focused that node is the root scope,
  /// which sits above this widget, and the bindings would never be consulted.
  /// `autofocus` parks focus inside the shell so the chain always passes
  /// through here, and `skipTraversal` keeps it out of the tab order.
  Widget _withDestinationShortcuts(Widget child) {
    final items = _railItems;
    final count = items.length < _destinationDigits.length
        ? items.length
        : _destinationDigits.length;

    final bindings = <ShortcutActivator, VoidCallback>{};
    for (var i = 0; i < count; i++) {
      final path = items[i].routePath;
      void go() => _onNavigate(path);

      bindings[SingleActivator(_destinationDigits[i], control: true)] = go;
      bindings[SingleActivator(_destinationDigits[i], meta: true)] = go;
    }

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: child,
      ),
    );
  }

  Widget _buildCompactShell(String currentPath) {
    final currentIndex = _getNavIndexFromPath(currentPath, _compactItems);

    return Scaffold(
      // Inherits AppColors.background from the theme. The canvas is a cool
      // grey so white cards read as surfaces resting on a page; on a white
      // scaffold they were invisible except for their shadow.
      extendBody: true,
      body: ModernBreakpointScope.fromLayout(child: widget.child),
      bottomNavigationBar: _ModernCompactBottomNav(
        items: _compactItems,
        currentIndex: currentIndex,
        onTap: (index) => _onNavigate(_compactItems[index].routePath),
        showFab: widget.showFab,
        fabIcon: widget.fabIcon,
        onFabTap: _onFabTap,
        isPosSelected: currentPath.startsWith('/pos'),
      ),
    );
  }

  Widget _buildRailShell(String currentPath, Breakpoint tier) {
    final currentIndex = _getNavIndexFromPath(currentPath, _railItems);
    final isExpanded = resolveRailExpanded(
      tier,
      ref.watch(navigationSidebarExpandedProvider),
    );

    // Only `expanded` and `large` have room for a 280dp rail, so `medium`
    // offers no toggle rather than a control that would do nothing.
    final canToggle = tier.atLeast(Breakpoint.expanded);

    return Scaffold(
      // Rail stays white, content area takes the cool canvas - the two zones
      // separate by value rather than by a shadow drawn between two whites.
      body: SafeArea(
        bottom: false, // No bottom chrome at this tier.
        child: Row(
          children: [
            _ModernNavigationRail(
              items: _railItems,
              currentIndex: currentIndex,
              onTap: (index) => _onNavigate(_railItems[index].routePath),
              isExpanded: isExpanded,
              onToggleExpanded: canToggle ? () => _toggleSidebar(tier) : null,
              account: ref.watch(shellAccountProvider),
              isPosActive: currentPath.startsWith('/pos'),
              onKasirTap: _onFabTap,
              onAccountTap: () => _onNavigate('/settings'),
            ),
            // Main content area.
            //
            // Scoped so screens measure the space left over after the rail,
            // not the window. With the rail expanded to 280dp on a 1400dp
            // window, content is 1120dp - `expanded`, not `large`. Reading the
            // window here is what makes a screen lay out for room it does not
            // have.
            Expanded(
              child: ModernBreakpointScope.fromLayout(child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact bottom navigation with center FAB
class _ModernCompactBottomNav extends StatelessWidget {
  const _ModernCompactBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.showFab,
    required this.fabIcon,
    required this.onFabTap,
    required this.isPosSelected,
  });

  final List<ModernNavItem> items;
  final int currentIndex;
  final void Function(int index) onTap;
  final bool showFab;
  final IconData fabIcon;
  final VoidCallback onFabTap;
  final bool isPosSelected;

  @override
  Widget build(BuildContext context) {
    if (!showFab) {
      return _buildSimpleBottomNav();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Wrap BottomAppBar in Container with BoxShadow for upward shadow
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.up,
          ),
          child: BottomAppBar(
            height: AppDimensions.bottomNavHeight,
            padding: EdgeInsets.zero,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: Colors.white,
            elevation: 0, // Disable Flutter's elevation
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // First half of items
                ...List.generate(
                  (items.length / 2).floor(),
                  (index) => _buildNavItem(index),
                ),
                // Space for FAB
                const SizedBox(width: AppDimensions.fabSize + 16),
                // Second half of items
                ...List.generate(
                  (items.length / 2).ceil(),
                  (index) => _buildNavItem(index + (items.length / 2).floor()),
                ),
              ],
            ),
          ),
        ),
        // Center FAB
        Positioned(
          left: 0,
          right: 0,
          bottom: AppDimensions.bottomNavHeight / 2 - 8,
          child: Center(
            // The glow is drawn on a wrapper rather than via FAB elevation:
            // Material's own shadow is neutral grey, which dulls the primary
            // blue. A hue-matched glow keeps the button reading as lit.
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow(
                  isPosSelected ? AppColors.primaryDark : AppColors.primary,
                  opacity: isPosSelected ? 0.42 : 0.32,
                ),
              ),
              child: FloatingActionButton(
                onPressed: onFabTap,
                backgroundColor:
                    isPosSelected ? AppColors.primaryDark : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                highlightElevation: 0,
                shape: const CircleBorder(),
                child: Icon(fabIcon, size: AppDimensions.iconLarge),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleBottomNav() {
    // Wrap BottomNavigationBar in Container with BoxShadow for upward shadow
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.up,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        backgroundColor: Colors.white,
        elevation: 0, // Disable Flutter's elevation
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon ?? item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    if (index >= items.length) return const SizedBox.shrink();

    final item = items[index];
    final isSelected = currentIndex == index;

    // Flexible, so the row can never overflow. There is slack at 375dp with
    // 'Pengaturan' at the default text scale, but not much - a 320dp screen or
    // the 1.2 scale the app clamps to eats it, and four items plus a 72dp FAB
    // notch leave nowhere for the excess to go. Where there is room this lays
    // out identically to an unconstrained child.
    return Flexible(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: AppDimensions.iconLarge,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.navLabel.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The navigation rail shown at `medium` and above.
///
/// Hand-rolled rather than Material's [NavigationRail], deliberately. The
/// active row here is a solid `primaryContainer` fill (see [_buildNavItem]),
/// collapsed rows carry tooltips, and rows have a hover colour tuned to this
/// palette. `NavigationRail` supplies none of the three and offers nothing in
/// exchange - it does not collapse to labels-on-demand, and its indicator is
/// a pill behind the icon only.
class _ModernNavigationRail extends StatelessWidget {
  const _ModernNavigationRail({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.isExpanded,
    required this.isPosActive,
    required this.onKasirTap,
    required this.onAccountTap,
    this.account,
    this.onToggleExpanded,
  });

  final List<ModernNavItem> items;
  final int currentIndex;
  final void Function(int index) onTap;
  final bool isExpanded;

  /// Whether POS is the current route, so the Kasir action can echo the
  /// compact FAB's pressed state.
  final bool isPosActive;

  final VoidCallback onKasirTap;
  final VoidCallback onAccountTap;

  /// Signed-in identity, or null when there is no session.
  final ShellAccount? account;

  /// Null at `medium`, where a 280dp rail would not fit.
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final width = isExpanded
        ? AppDimensions.sidebarExpandedWidth
        : AppDimensions.sidebarWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        // A hairline, not a shadow. The rail no longer needs to cast onto the
        // content area now that the canvas behind it is tinted - the value
        // difference does the separating, and an edge reads crisper.
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      // The rows are laid out at the destination width from the first frame
      // and the box slides over them, rather than the rows being squeezed
      // through every width in between. Without this, an 80→280 expansion
      // spends 200ms laying an icon, a 16dp gap and a label into 23dp of row -
      // which is not merely ugly, it is a RenderFlex overflow on every frame
      // of the animation.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: Column(
            children: [
              // Logo area
              _buildLogoArea(),
              // Navigation items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildNavItem(index),
                ),
              ),
              // Footer: the Kasir shortcut and the account row.
              _buildFooter(),
              // Toggle button
              if (onToggleExpanded != null) _buildToggleButton(),
              const SizedBox(height: AppDimensions.spacing16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoArea() {
    return Container(
      height: AppDimensions.appBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.22),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: AppDimensions.iconLarge,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Text(
                'KASBON',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = items[index];
    final isSelected = currentIndex == index;

    final foreground = isSelected ? AppColors.primary : AppColors.textSecondary;

    final content = Material(
      // A solid container tint rather than 10% primary. At one-tenth alpha the
      // active row was barely distinguishable from its neighbours, so the rail
      // gave no answer to "where am I?" at a glance.
      color: isSelected ? AppColors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        hoverColor: AppColors.surfaceVariant,
        splashColor: AppColors.primaryContainer.withValues(alpha: 0.6),
        child: Container(
          height: AppDimensions.navItemHeight,
          padding: EdgeInsets.symmetric(
            horizontal:
                isExpanded ? AppDimensions.spacing16 : AppDimensions.spacing12,
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                color: foreground,
                size: AppDimensions.iconLarge,
              ),
              if (isExpanded) ...[
                const SizedBox(width: AppDimensions.spacing16),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: foreground,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing4),
      // Collapsed, the rail is a column of unlabelled glyphs. A tooltip is the
      // only thing naming them, so it is not optional here.
      child: isExpanded
          ? content
          : Tooltip(
              message: item.label,
              waitDuration: const Duration(milliseconds: 400),
              child: content,
            ),
    );
  }

  /// The Kasir shortcut and the account row.
  ///
  /// Kasir is duplicated here on purpose. On compact it is the notched FAB -
  /// permanently visible, one tap from any screen - and the rail replacing the
  /// bottom bar must not quietly demote the app's most-used action to one row
  /// among seven. The rail item stays as the *destination*; this is the
  /// *action*, tinted the same primary as the FAB it stands in for.
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing12,
        AppDimensions.spacing12,
        AppDimensions.spacing12,
        AppDimensions.spacing8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKasirAction(),
          const SizedBox(height: AppDimensions.spacing8),
          _buildAccountRow(),
        ],
      ),
    );
  }

  Widget _buildKasirAction() {
    final background = isPosActive ? AppColors.primaryDark : AppColors.primary;

    final content = Material(
      color: background,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onKasirTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        splashColor: Colors.white.withValues(alpha: 0.18),
        child: Container(
          height: AppDimensions.minTouchTarget,
          padding: EdgeInsets.symmetric(
            horizontal:
                isExpanded ? AppDimensions.spacing16 : AppDimensions.spacing12,
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.point_of_sale,
                color: Colors.white,
                size: AppDimensions.iconMedium,
              ),
              if (isExpanded) ...[
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Text(
                    'Kasir',
                    style: AppTextStyles.button.copyWith(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return isExpanded
        ? content
        : Tooltip(
            message: 'Buka kasir',
            waitDuration: const Duration(milliseconds: 400),
            child: content,
          );
  }

  Widget _buildAccountRow() {
    // No session, or Supabase not initialised. The row still navigates to
    // settings, so the rail's shape does not change under it.
    final name = account?.name ?? 'Akun';
    final email = account?.email;

    final avatar = ModernAvatar.initials(
      account?.initials ?? '?',
      size: ModernSize.small,
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.primary,
    );

    final content = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onAccountTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        hoverColor: AppColors.surfaceVariant,
        child: Container(
          height: AppDimensions.minTouchTarget,
          padding: EdgeInsets.symmetric(
            horizontal:
                isExpanded ? AppDimensions.spacing12 : AppDimensions.spacing8,
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              avatar,
              if (isExpanded) ...[
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email != null && email != name)
                        Text(
                          email,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return isExpanded
        ? content
        : Tooltip(
            message: email == null || email == name ? name : '$name\n$email',
            waitDuration: const Duration(milliseconds: 400),
            child: content,
          );
  }

  Widget _buildToggleButton() {
    return Tooltip(
      message: isExpanded ? 'Ciutkan menu' : 'Lebarkan menu',
      child: IconButton(
        onPressed: onToggleExpanded,
        icon: Icon(
          isExpanded
              ? Icons.keyboard_double_arrow_left_rounded
              : Icons.keyboard_double_arrow_right_rounded,
          color: AppColors.textTertiary,
          size: AppDimensions.iconMedium,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppDimensions.minTouchTarget),
          shape: const CircleBorder(),
          hoverColor: AppColors.surfaceVariant,
        ),
      ),
    );
  }
}
