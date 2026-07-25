import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_gradients.dart';
import '../../../../config/theme/app_shadows.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../providers/navigation_sidebar_provider.dart';

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

/// Default navigation items for the KASBON app
const List<ModernNavItem> defaultMobileNavItems = [
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

const List<ModernNavItem> defaultTabletNavItems = [
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

/// A Modern responsive navigation shell for the app
///
/// Features:
/// - Responsive layout (mobile bottom nav / tablet sidebar)
/// - Customizable navigation items
/// - Center FAB for mobile POS access
///
/// Note: App bar is now handled by individual screens using [ModernAppBar].
/// This shell only provides navigation (bottom nav for mobile, sidebar for tablet).
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
    this.mobileNavItems,
    this.tabletNavItems,
    this.onNavigate,
    this.showFab = true,
    this.fabIcon = Icons.point_of_sale,
    this.onFabPressed,
  });

  /// The main content widget
  final Widget child;

  /// The current route path
  final String currentPath;

  /// Navigation items for mobile layout
  /// Defaults to [defaultMobileNavItems]
  final List<ModernNavItem>? mobileNavItems;

  /// Navigation items for tablet layout
  /// Defaults to [defaultTabletNavItems]
  final List<ModernNavItem>? tabletNavItems;

  /// Callback when a navigation item is tapped
  /// If null, uses GoRouter navigation
  final void Function(String routePath)? onNavigate;

  /// Whether to show the center FAB on mobile
  final bool showFab;

  /// Icon for the center FAB
  final IconData fabIcon;

  /// Callback when FAB is pressed
  final VoidCallback? onFabPressed;

  @override
  ConsumerState<ModernAppShell> createState() => _ModernAppShellState();
}

class _ModernAppShellState extends ConsumerState<ModernAppShell> {
  List<ModernNavItem> get _mobileItems =>
      widget.mobileNavItems ?? defaultMobileNavItems;

  List<ModernNavItem> get _tabletItems =>
      widget.tabletNavItems ?? defaultTabletNavItems;

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

  void _toggleSidebar() {
    ref.read(navigationSidebarExpandedProvider.notifier).state =
        !ref.read(navigationSidebarExpandedProvider);
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

    if (context.isMobile) {
      return _buildMobileShell(actualPath);
    }
    return _buildTabletShell(actualPath);
  }

  Widget _buildMobileShell(String currentPath) {
    final currentIndex = _getNavIndexFromPath(currentPath, _mobileItems);

    return Scaffold(
      // Inherits AppColors.background from the theme. The canvas is a cool
      // grey so white cards read as surfaces resting on a page; on a white
      // scaffold they were invisible except for their shadow.
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _ModernMobileBottomNav(
        items: _mobileItems,
        currentIndex: currentIndex,
        onTap: (index) => _onNavigate(_mobileItems[index].routePath),
        showFab: widget.showFab,
        fabIcon: widget.fabIcon,
        onFabTap: _onFabTap,
        isPosSelected: currentPath.startsWith('/pos'),
      ),
    );
  }

  Widget _buildTabletShell(String currentPath) {
    final currentIndex = _getNavIndexFromPath(currentPath, _tabletItems);
    final isSidebarExpanded = ref.watch(navigationSidebarExpandedProvider);

    return Scaffold(
      // Rail stays white, content area takes the cool canvas - the two zones
      // separate by value rather than by a shadow drawn between two whites.
      body: SafeArea(
        bottom: false, // Typically not needed for tablet
        child: Row(
          children: [
            // Sidebar
            _ModernTabletSidebar(
              items: _tabletItems,
              currentIndex: currentIndex,
              onTap: (index) => _onNavigate(_tabletItems[index].routePath),
              isExpanded: isSidebarExpanded,
              onToggleExpanded: _toggleSidebar,
            ),
            // Main content area
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

}

/// Mobile bottom navigation with center FAB
class _ModernMobileBottomNav extends StatelessWidget {
  const _ModernMobileBottomNav({
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

    return InkWell(
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tablet sidebar navigation
class _ModernTabletSidebar extends StatelessWidget {
  const _ModernTabletSidebar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.isExpanded,
    this.onToggleExpanded,
  });

  final List<ModernNavItem> items;
  final int currentIndex;
  final void Function(int index) onTap;
  final bool isExpanded;
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
          // Toggle button
          if (onToggleExpanded != null) _buildToggleButton(),
          const SizedBox(height: AppDimensions.spacing16),
        ],
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

    final foreground =
        isSelected ? AppColors.primary : AppColors.textSecondary;

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
