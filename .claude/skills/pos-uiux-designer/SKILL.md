---
name: pos-uiux-designer
description: Analyze UI screenshots/mockups and implement or improve Flutter UI/UX for KASBON POS app. Use when user provides design images, asks for UI improvements, wants to implement new screens, or needs UI/UX review. Specializes in POS (Point of Sale) application patterns.
allowed-tools: Read, Glob, Grep, Edit, Write
---

# POS UI/UX Designer Skill

## Purpose

This skill helps analyze UI designs (screenshots, mockups, images) and implement or improve Flutter UI/UX specifically for the KASBON POS application targeting Indonesian UMKM (small businesses).

## When to Use This Skill

- User provides a screenshot/image of a UI design to implement
- User asks to improve existing UI/UX
- User wants to redesign a screen
- User asks for POS-specific UI patterns
- User wants UI review or accessibility check

## Image Analysis Process

When analyzing a UI screenshot or design:

### Step 1: Identify Components
- Layout structure (grid, list, cards, tabs)
- Navigation elements (bottom nav, app bar, drawer)
- Interactive elements (buttons, inputs, toggles)
- Data display (tables, charts, lists)
- Visual hierarchy (headers, sections, emphasis)

### Step 2: Extract Design Tokens
- **Colors**: Primary, secondary, background, text colors
- **Typography**: Font sizes, weights, hierarchy
- **Spacing**: Padding, margins, gaps (estimate in 8dp units)
- **Shadows/Elevation**: Card elevation, button shadows
- **Border radius**: Corner rounding patterns

### Step 3: Map to Flutter Widgets
- Identify appropriate Flutter widgets for each element
- Consider Material Design 3 components
- Plan widget composition and nesting

### Step 4: Implement with KASBON Theme
- Apply KASBON color palette
- Use consistent spacing system
- Ensure offline-first indicators
- Add proper touch targets

---

## KASBON Design System

**IMPORTANT:** Always import from `package:kasbon/config/theme/theme.dart` which exports all theme classes.

### Color Palette (AppColors)

Located at: `lib/config/theme/app_colors.dart`

```dart
import 'package:kasbon/config/theme/theme.dart';

// Primary Colors (Blue - Trust, Professional for POS)
AppColors.primary           // Color(0xFF2563EB) - Main brand blue
AppColors.primaryLight      // Color(0xFF60A5FA) - Light blue
AppColors.primaryDark       // Color(0xFF1D4ED8) - Dark blue
AppColors.primaryContainer  // Color(0xFFDBEAFE) - Blue container bg
AppColors.onPrimary         // Colors.white
AppColors.onPrimaryContainer // Color(0xFF1E40AF)

// Interactive States
AppColors.primaryHover      // Color(0xFF3B82F6)
AppColors.primaryPressed    // Color(0xFF1D4ED8)
AppColors.primaryDisabled   // Color(0xFFBFDBFE)

// Secondary Colors (Navy Blue - Professional)
AppColors.secondary         // Color(0xFF1E3A8A) - Navy blue
AppColors.secondaryLight    // Color(0xFF3B5998)
AppColors.secondaryDark     // Color(0xFF152A63)
AppColors.secondaryContainer // Color(0xFFD6E0F5)
AppColors.onSecondary       // Colors.white

// Status Colors
AppColors.success           // Color(0xFF10B981) - Green
AppColors.successLight      // Color(0xFFD1FAE5)
AppColors.warning           // Color(0xFFF59E0B) - Amber
AppColors.warningLight      // Color(0xFFFEF3C7)
AppColors.error             // Color(0xFFEF4444) - Red
AppColors.errorLight        // Color(0xFFFEE2E2)
AppColors.info              // Color(0xFF3B82F6) - Blue
AppColors.infoLight         // Color(0xFFDBEAFE)

// Neutral Colors
AppColors.background        // Color(0xFFF5F5F5) - Light gray bg
AppColors.surface           // Color(0xFFFFFFFF) - White surface
AppColors.surfaceVariant    // Color(0xFFF0F0F0) - Muted surface
AppColors.surfaceMuted      // Color(0xFFF8FAFC)
AppColors.card              // Color(0xFFFFFFFF) - Card background

// Text Colors
AppColors.textPrimary       // Color(0xFF1F2937) - Dark gray
AppColors.textSecondary     // Color(0xFF6B7280) - Medium gray
AppColors.textTertiary      // Color(0xFF9CA3AF) - Light gray
AppColors.textDisabled      // Color(0xFFD1D5DB)
AppColors.textOnPrimary     // Colors.white
AppColors.textOnSecondary   // Colors.white

// Border Colors
AppColors.border            // Color(0xFFE5E7EB)
AppColors.borderLight       // Color(0xFFF3F4F6)
AppColors.divider           // Color(0xFFE5E7EB)

// Shadow & Overlay
AppColors.shadow            // Color(0x1A000000)
AppColors.overlay           // Color(0x80000000)

// Shimmer Colors (for loading states)
AppColors.shimmerBase       // Color(0xFFE5E7EB)
AppColors.shimmerHighlight  // Color(0xFFF3F4F6)

// Category Colors (for product categories)
AppColors.categoryColors    // List of 8 colors for categories
```

### Spacing & Dimensions (AppDimensions)

Located at: `lib/config/theme/app_dimensions.dart`

```dart
import 'package:kasbon/config/theme/theme.dart';

// Spacing Scale (4dp grid)
AppDimensions.spacing2      // 2.0
AppDimensions.spacing4      // 4.0
AppDimensions.spacing8      // 8.0
AppDimensions.spacing12     // 12.0
AppDimensions.spacing16     // 16.0 (default)
AppDimensions.spacing20     // 20.0
AppDimensions.spacing24     // 24.0
AppDimensions.spacing32     // 32.0
AppDimensions.spacing40     // 40.0
AppDimensions.spacing48     // 48.0

// Border Radius
AppDimensions.radiusSmall   // 4.0
AppDimensions.radiusMedium  // 8.0
AppDimensions.radiusLarge   // 12.0
AppDimensions.radiusXLarge  // 16.0
AppDimensions.radiusRound   // 999.0 (pill shape)

// Button Heights
AppDimensions.buttonHeightSmall  // 32.0
AppDimensions.buttonHeightMedium // 44.0
AppDimensions.buttonHeightLarge  // 52.0

// Touch Targets (accessibility)
AppDimensions.minTouchTarget // 48.0

// Icon Sizes
AppDimensions.iconSmall     // 16.0
AppDimensions.iconMedium    // 20.0
AppDimensions.iconLarge     // 24.0
AppDimensions.iconXLarge    // 32.0

// Avatar Sizes
AppDimensions.avatarSmall   // 32.0
AppDimensions.avatarMedium  // 40.0
AppDimensions.avatarLarge   // 56.0

// Card Dimensions
AppDimensions.cardElevation // 2.0
AppDimensions.cardPadding   // 16.0

// Input Fields
AppDimensions.inputHeight           // 48.0
AppDimensions.inputBorderWidth      // 1.0
AppDimensions.inputFocusBorderWidth // 2.0

// Product Card
AppDimensions.productCardWidth       // 160.0
AppDimensions.productCardImageHeight // 100.0

// Badge Sizes
AppDimensions.badgeHeight            // 24.0
AppDimensions.badgePaddingHorizontal // 8.0
AppDimensions.counterBadgeSize       // 20.0

// Divider
AppDimensions.dividerThickness       // 1.0
```

### Typography (AppTextStyles)

Located at: `lib/config/theme/app_text_styles.dart`

```dart
import 'package:kasbon/config/theme/theme.dart';

// Font Families
AppTextStyles.fontFamily     // 'Roboto'
AppTextStyles.fontFamilyMono // 'RobotoMono' (for prices)

// Headings
AppTextStyles.h1  // 32sp, bold, height: 1.2
AppTextStyles.h2  // 24sp, bold, height: 1.25
AppTextStyles.h3  // 20sp, w600, height: 1.3
AppTextStyles.h4  // 18sp, w600, height: 1.35

// Body Text
AppTextStyles.bodyLarge   // 16sp, regular, height: 1.5
AppTextStyles.bodyMedium  // 14sp, regular, height: 1.5
AppTextStyles.bodySmall   // 12sp, regular, height: 1.5, textSecondary

// Labels
AppTextStyles.labelLarge  // 14sp, w500, height: 1.4
AppTextStyles.labelMedium // 12sp, w500, height: 1.4
AppTextStyles.labelSmall  // 10sp, w500, height: 1.4, letterSpacing: 0.5

// Price Styles (Monospace - RobotoMono)
AppTextStyles.priceLarge  // 24sp, w600, height: 1.2
AppTextStyles.priceMedium // 18sp, w600, height: 1.3
AppTextStyles.priceSmall  // 14sp, w500, height: 1.4

// Button Text
AppTextStyles.button      // 16sp, w600, height: 1.25, letterSpacing: 0.5
AppTextStyles.buttonSmall // 14sp, w600, height: 1.25, letterSpacing: 0.5

// Caption
AppTextStyles.caption     // 11sp, regular, height: 1.4, textTertiary
```

---

## Modern Widget Library (REQUIRED)

**CRITICAL:** Always use Modern widgets from `lib/shared/modern/`. DO NOT use legacy widgets from `lib/shared/widgets/`.

**Import:**
```dart
import 'package:kasbon_pos/shared/modern/modern.dart';
```

### Buttons

```dart
// ModernButton - Main button component with variants
ModernButton.primary(child: Text('Bayar'), onPressed: () {})      // Filled primary
ModernButton.secondary(child: Text('Simpan'), onPressed: () {})   // Filled secondary
ModernButton.outline(child: Text('Batal'), onPressed: () {})      // Border only
ModernButton.text(child: Text('Lihat'), onPressed: () {})         // Text only
ModernButton.destructive(child: Text('Hapus'), onPressed: () {})  // Red/danger

// Convenience factory with label
ModernButton.label(label: 'Simpan', onPressed: () {})

// Button sizes: ModernSize.small, .medium, .large
ModernButton.primary(
  child: Text('Checkout'),
  size: ModernSize.large,
  leadingIcon: Icons.shopping_cart,
  fullWidth: true,
  isLoading: isLoading,
  onPressed: onCheckout,
)

// ModernIconButton - Icon-only buttons
ModernIconButton(icon: Icons.add, onPressed: () {})
ModernIconButton.filled(icon: Icons.delete, onPressed: () {})
ModernIconButton.tonal(icon: Icons.edit, onPressed: () {})
ModernIconButton.outlined(icon: Icons.share, onPressed: () {})

// ModernQuantityStepper - +/- quantity control
ModernQuantityStepper(
  value: 3,
  onIncrement: () {},
  onDecrement: () {},
  min: 1,
  max: 99,
)
```

### Cards

```dart
// ModernCard - Base card with variants
ModernCard.elevated(child: content)   // With shadow
ModernCard.outlined(child: content)   // With border
ModernCard.filled(child: content)     // Filled bg

ModernCard.elevated(
  padding: EdgeInsets.all(AppDimensions.spacing16),
  onTap: onCardTap,
  child: Column(...),
)

// ModernGradientCard - For dashboard stats
ModernGradientCard.primary(child: revenueStats)  // Orange gradient
ModernGradientCard.success(child: profitStats)   // Green gradient
ModernGradientCard.warning(child: alertStats)    // Amber gradient
ModernGradientCard.error(child: errorStats)      // Red gradient

// ModernListTile - For list item display
ModernListTile(
  title: 'Product Name',
  subtitle: 'Rp 50.000',
  leading: ModernAvatar(fallbackText: 'P'),
  trailing: ModernBadge.success(label: 'Tersedia'),
  onTap: onProductTap,
)
```

### Inputs

```dart
// ModernTextField - Standard text input
ModernTextField(
  label: 'Nama Produk',
  hint: 'Masukkan nama produk',
  controller: nameController,
  prefixIcon: Icons.inventory,
  errorText: errors['name'],
  onChanged: (value) {},
)

// ModernTextField.password - Password input with visibility toggle
ModernTextField.password(
  label: 'Password',
  controller: passwordController,
)

// ModernCurrencyField - Currency input with Rp formatting
ModernCurrencyField(
  label: 'Harga Jual',
  controller: priceController,
  onChanged: (value) {},
)

// ModernSearchField - Search input with icon
ModernSearchField(
  hint: 'Cari produk...',
  onChanged: (query) => search(query),
  onClear: () => clearSearch(),
)

// ModernDropdown - Generic dropdown
ModernDropdown<String>(
  label: 'Kategori',
  value: selectedCategory,
  items: categories,
  onChanged: (value) => selectCategory(value),
)
```

### Badges & Data Display

```dart
// ModernBadge - Status badges with semantic colors
ModernBadge.success(label: 'Lunas')       // Green
ModernBadge.warning(label: 'Stok Rendah') // Amber
ModernBadge.error(label: 'Gagal')         // Red
ModernBadge.info(label: 'Baru')           // Blue
ModernBadge.neutral(label: 'Draft')       // Gray

ModernBadge.success(
  label: 'Tersinkron',
  icon: Icons.cloud_done,
  showDot: true,
)

// ModernCounterBadge - Notification count badge
ModernCounterBadge(count: 5, child: Icon(Icons.shopping_cart))

// ModernChip - Selection chip
ModernChip(
  label: 'Makanan',
  isSelected: true,
  onTap: () => selectCategory('Makanan'),
)

// ModernAvatar - Avatar with fallback
ModernAvatar(
  imageUrl: product.imageUrl,
  fallbackText: 'P',
  size: ModernSize.medium,
)
```

### Feedback

```dart
// ModernLoading - Loading indicators
ModernLoading()                          // Default circular
ModernLoading.small()                    // 16px
ModernLoading.medium()                   // 24px
ModernLoading.large()                    // 40px
ModernLoading.small(color: Colors.white) // Custom color
ModernLoading.overlay(message: 'Memproses...')  // Full-screen overlay

// ModernEmptyState - Empty state display
ModernEmptyState(
  icon: Icons.inventory_2_outlined,
  title: 'Belum Ada Produk',
  message: 'Tambahkan produk pertama Anda',
  actionLabel: 'Tambah Produk',
  onAction: () => addProduct(),
)

// ModernErrorState - Error state display
ModernErrorState(
  message: 'Gagal memuat data',
  onRetry: () => reload(),
)

// ModernShimmer - Skeleton loading placeholder
ModernShimmer.box(width: 100, height: 100)
ModernShimmer.circle(size: 40)

// ModernDialog - Dialogs
ModernDialog.confirm(
  context: context,
  title: 'Hapus Produk?',
  message: 'Produk akan dihapus permanen',
  confirmLabel: 'Hapus',
  onConfirm: onDelete,
)
ModernDialog.alert(context: context, title: 'Info', message: 'Berhasil')
ModernDialog.error(context: context, message: 'Terjadi kesalahan')
ModernDialog.success(context: context, message: 'Berhasil disimpan')

// ModernToast - Toast notifications
ModernToast.success(context: context, message: 'Berhasil disimpan')
ModernToast.error(context: context, message: 'Gagal menyimpan')
ModernToast.warning(context: context, message: 'Stok hampir habis')
ModernToast.info(context: context, message: 'Data diperbarui')
```

### Layout

```dart
// ModernAppShell - Responsive navigation container
ModernAppShell(
  child: child,
  currentPath: currentPath,
  showFab: true,
  onFabPressed: () => context.go('/pos'),
)

// ModernAppBar - Feature-rich app bar
ModernAppBar.simple(title: 'Produk')
ModernAppBar.withBack(title: 'Detail', context: context)
ModernAppBar.withSearch(title: 'Produk', onSearch: onSearch, searchHint: 'Cari...')
ModernAppBar.withActions(title: 'Dashboard', actions: [...])
ModernAppBar.withUserInfo(userName: 'Toko ABC', userRole: 'Admin')

// ModernSectionHeader - Section title with optional action
ModernSectionHeader(
  title: 'Produk Terlaris',
  actionLabel: 'Lihat Semua',
  onAction: () => viewAll(),
)

// ModernSummaryRow - Key-value row (for totals, details)
ModernSummaryRow(label: 'Subtotal', value: 'Rp 150.000')
ModernSummaryRow.total(label: 'TOTAL', value: 'Rp 150.000')

// ModernDivider - Consistent divider
ModernDivider()
ModernDivider(indent: 16)
```

---

## POS-Specific UI Patterns

### 1. POS/Cashier Screen Layout

**Recommended Structure:**
```
┌─────────────────────────────────────────────────┐
│  App Bar: Store name, sync status, menu        │
├─────────────────────┬───────────────────────────┤
│                     │                           │
│   Product Grid      │      Cart Panel           │
│   (Scrollable)      │      (Fixed)              │
│                     │                           │
│   - Category tabs   │   - Cart items list       │
│   - Product cards   │   - Quantity controls     │
│   - Quick search    │   - Subtotal/Total        │
│                     │   - Discount button       │
│                     │   - Payment button        │
│                     │                           │
├─────────────────────┴───────────────────────────┤
│  Bottom: Numpad (optional) / Quick actions      │
└─────────────────────────────────────────────────┘
```

**For Portrait/Phone:**
```
┌─────────────────────┐
│  App Bar            │
├─────────────────────┤
│  Category Tabs      │
├─────────────────────┤
│                     │
│   Product Grid      │
│   (Expandable)      │
│                     │
├─────────────────────┤
│  Cart Summary Bar   │
│  [Items: 3] [Total] │
│  [Lihat Keranjang]  │
└─────────────────────┘
```

### 2. Product Card Design

```dart
// Compact product card for POS grid
Container(
  width: 100,
  height: 120,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [/* subtle shadow */],
  ),
  child: Column(
    children: [
      // Product image or icon (60px)
      // Product name (2 lines max)
      // Price (bold, primary color)
    ],
  ),
)
```

### 3. Cart Item Design

```dart
// Cart item row
ListTile(
  leading: /* product thumbnail */,
  title: Text(productName),
  subtitle: Text(priceFormatted),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(icon: Icon(Icons.remove)),
      Text(quantity),
      IconButton(icon: Icon(Icons.add)),
    ],
  ),
)
```

### 4. Transaction Summary

```dart
// Bottom summary panel
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [/* top shadow */],
  ),
  child: Column(
    children: [
      Row(/* Subtotal */),
      Row(/* Discount (if any) */),
      Divider(),
      Row(/* TOTAL - large, bold */),
      SizedBox(height: 16),
      ElevatedButton(/* BAYAR / Pay button - full width, primary */),
    ],
  ),
)
```

### 5. Dashboard Cards

```dart
// Stats card
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: accentColor),
          Spacer(),
          // Trend indicator (optional)
        ],
      ),
      SizedBox(height: 8),
      Text(value, style: headline2),
      Text(label, style: bodySmall),
    ],
  ),
)
```

---

## Offline-First UI Patterns

### Sync Status Indicator

Always show sync status in app bar or prominent location:

```dart
// Sync status badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: isOnline ? Colors.green[100] : Colors.orange[100],
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        isOnline ? Icons.cloud_done : Icons.cloud_off,
        size: 16,
        color: isOnline ? Colors.green : Colors.orange,
      ),
      SizedBox(width: 4),
      Text(
        isOnline ? 'Tersinkron' : 'Offline',
        style: TextStyle(fontSize: 12),
      ),
    ],
  ),
)
```

### Pending Sync Indicator

Show count of items waiting to sync:

```dart
// Pending badge
if (pendingCount > 0)
  Badge(
    label: Text('$pendingCount'),
    child: Icon(Icons.sync),
  )
```

### Offline Action Feedback

```dart
// When action performed offline
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Transaksi disimpan. Akan disinkronkan saat online.'),
    backgroundColor: Colors.orange,
  ),
);
```

---

## Accessibility Guidelines

### Touch Targets
- All interactive elements: minimum 48x48dp
- Buttons: prefer 48dp height, 56dp for primary actions
- Spacing between targets: minimum 8dp

### Color Contrast
- Text on white: use textPrimary (#1F2937) or darker
- Text on primary: use white
- Error states: red with icon, not just color

### Text
- Minimum body text: 14sp
- Important values (prices, totals): 16sp or larger
- Use medium/bold for emphasis, not just color

### Focus States
- All interactive elements need visible focus indicator
- Use default Flutter focus or customize with border

---

## Implementation Guidelines

### File Structure

When creating new screens, follow this structure:

```
lib/features/<feature>/presentation/
├── screens/
│   └── <screen>_screen.dart
├── widgets/
│   ├── <feature>_card.dart
│   ├── <feature>_list.dart
│   └── <feature>_form.dart
└── providers/
    └── <feature>_provider.dart
```

### Widget Composition

1. **Extract reusable widgets** - If a component is used 2+ times, extract it
2. **Use const constructors** - For static widgets, use const
3. **Keep build methods small** - Max 50 lines, extract to methods/widgets
4. **Responsive layouts** - Use LayoutBuilder or MediaQuery for adaptability

### State Management

Use Riverpod patterns:
```dart
// For UI state
@riverpod
class ScreenController extends _$ScreenController {
  // State logic
}

// In widget
final state = ref.watch(screenControllerProvider);
```

### Use Modern Widgets (REQUIRED)

**Always prefer Modern widgets over raw Flutter widgets:**

```dart
import 'package:kasbon_pos/shared/modern/modern.dart';
import 'package:kasbon_pos/config/theme/theme.dart';

// Buttons - Use ModernButton instead of ElevatedButton/OutlinedButton
ModernButton.primary(child: Text('Bayar'), onPressed: onPay)      // Primary action
ModernButton.outline(child: Text('Batal'), onPressed: onCancel)   // Secondary action
ModernButton.text(child: Text('Lihat Semua'), onPressed: onViewAll) // Text link
ModernButton.destructive(child: Text('Hapus'), onPressed: onDelete) // Danger action

// Inputs - Use Modern*Field instead of TextField
ModernTextField(label: 'Nama', controller: ctrl)              // Standard input
ModernCurrencyField(label: 'Harga', controller: priceCtrl)    // Currency input
ModernSearchField(hint: 'Cari...', onChanged: onSearch)       // Search input

// Cards - Use ModernCard instead of Card
ModernCard.elevated(child: content)   // With shadow
ModernCard.outlined(child: content)   // With border
ModernGradientCard.primary(child: stats) // Dashboard stats

// Badges - Use ModernBadge for status indicators
ModernBadge.success(label: 'Lunas')   // Payment status
ModernBadge.warning(label: 'Hutang')  // Debt status

// Feedback - Use Modern feedback widgets
ModernLoading()                       // Loading spinner
ModernEmptyState(...)                 // Empty state
ModernErrorState(...)                 // Error state
ModernDialog.confirm(...)             // Confirmation dialog
ModernToast.success(...)              // Toast notification

// Layout - Use Modern layout components
ModernSectionHeader(title: 'Produk')  // Section headers
ModernSummaryRow(label: 'Total', value: 'Rp 100.000')  // Summary rows
ModernDivider()                       // Consistent divider
```

### Raw Flutter Widgets (Only When No Shared Alternative)

```dart
// These are OK to use directly:
Scaffold           // Screen structure
GridView           // Product grids
ListView           // Scrollable lists
Column/Row         // Layout
Switch             // Toggles
DropdownButtonFormField  // Dropdowns
SnackBar           // Via ScaffoldMessenger
AlertDialog        // Confirmations
```

---

## Bahasa Indonesia UI Text

### Common Labels

```
// Navigation
Beranda          - Home/Dashboard
Kasir            - POS/Cashier
Produk           - Products
Transaksi        - Transactions
Laporan          - Reports
Pengaturan       - Settings

// Actions
Simpan           - Save
Batal            - Cancel
Hapus            - Delete
Edit             - Edit
Tambah           - Add
Cari             - Search
Bayar            - Pay
Selesai          - Done/Complete

// Status
Berhasil         - Success
Gagal            - Failed
Memuat...        - Loading...
Kosong           - Empty
Tersinkron       - Synced
Offline          - Offline
Menunggu         - Pending

// Transaction
Keranjang        - Cart
Subtotal         - Subtotal
Diskon           - Discount
Total            - Total
Tunai            - Cash
Hutang           - Debt/Credit
Lunas            - Paid
Belum Lunas      - Unpaid

// Product
Stok             - Stock
Harga Jual       - Selling Price
Harga Modal      - Cost Price
Kategori         - Category
```

### Number Formatting

```dart
// Currency
'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}'
// Result: Rp 150.000

// Date
DateFormat('dd MMM yyyy', 'id_ID').format(date)
// Result: 25 Des 2024

// Time
DateFormat('HH:mm', 'id_ID').format(time)
// Result: 14:30
```

---

## Screen Templates

### Empty State - Use ModernEmptyState

```dart
import 'package:kasbon_pos/shared/modern/modern.dart';

// Use the Modern widget
ModernEmptyState(
  icon: Icons.inventory_2_outlined,
  title: 'Belum Ada Produk',
  message: 'Tambahkan produk pertama untuk memulai berjualan',
  actionLabel: 'Tambah Produk',
  onAction: () => context.push('/products/add'),
)
```

### Loading State - Use ModernLoading

```dart
// Simple loading
ModernLoading()

// Sizes
ModernLoading.small()
ModernLoading.medium()
ModernLoading.large()

// Full-screen overlay
ModernLoading.overlay(message: 'Memproses...')

// Centered with text
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ModernLoading(),
      SizedBox(height: AppDimensions.spacing16),
      Text('Memuat...', style: AppTextStyles.bodyMedium),
    ],
  ),
)
```

### Error State - Use ModernErrorState

```dart
// Use the Modern widget
ModernErrorState(
  message: errorMessage,
  onRetry: () => ref.invalidate(dataProvider),
)
```

### Shimmer/Skeleton Loading - Use ModernShimmer

```dart
// Box shimmer
ModernShimmer.box(width: 100, height: 100)

// Circle shimmer
ModernShimmer.circle(size: 40)
```

---

## Review Checklist

When reviewing or implementing UI:

### Layout
- [ ] Proper visual hierarchy
- [ ] Consistent spacing (use AppDimensions.spacing*)
- [ ] Responsive to different screen sizes (`context.isMobile`)
- [ ] Safe area handling (notches, navigation bar)

### Components - Use Modern Widgets (REQUIRED)
- [ ] Import: `import 'package:kasbon_pos/shared/modern/modern.dart';`
- [ ] Touch targets >= AppDimensions.minTouchTarget (48dp)
- [ ] Use `ModernButton.*` for buttons (not ElevatedButton)
- [ ] Use `ModernTextField`/`ModernCurrencyField` for inputs
- [ ] Use `ModernCard.*` for cards
- [ ] Use `ModernEmptyState` for empty states
- [ ] Use `ModernErrorState` for error states
- [ ] Use `ModernLoading` for loading states
- [ ] Use `ModernBadge.*` for status badges
- [ ] Use `ModernDialog`/`ModernToast` for feedback

### Theme - Use Design Tokens
- [ ] Uses AppColors.* (no hardcoded colors)
- [ ] Uses AppTextStyles.* (no hardcoded text styles)
- [ ] Uses AppDimensions.* (no hardcoded sizes)
- [ ] Uses AppDimensions.radius* for border radius

### Accessibility
- [ ] Sufficient color contrast (AppColors handles this)
- [ ] Text is readable (AppTextStyles.bodyMedium+ = 14sp+)
- [ ] Icons have labels or tooltips
- [ ] Focus states visible

### Offline-First
- [ ] Sync status visible (use ModernBadge)
- [ ] Offline actions work
- [ ] Pending sync indicated
- [ ] Error handling for offline

### Bahasa Indonesia
- [ ] All text in Indonesian
- [ ] Currency format: Rp X.XXX (use ModernCurrencyField)
- [ ] Date format: DD MMM YYYY
- [ ] Consistent terminology

---

## Example: Implementing from Screenshot

When user provides a screenshot:

1. **Analyze the image** using Read tool
2. **Identify structure**: "I see a grid of products on left, cart on right..."
3. **Map to Flutter**: "This can be a Row with Expanded children..."
4. **Apply KASBON theme**: Use AppColors, AppDimensions, AppTextStyles
5. **Use shared widgets**: AppButton, AppCard, AppTextField, etc.
6. **Generate code**: Create the Flutter implementation
7. **Suggest improvements**: Add offline indicators, fix touch targets

Example response format:

```
## Analysis

I can see the design has:
- [Component 1]: Description
- [Component 2]: Description
...

## Implementation Plan

1. Create main layout with...
2. Build product grid using ProductCard...
3. Implement cart panel with CartItemRow...

## Code

[Flutter implementation using:
- AppColors.* for colors
- AppDimensions.* for spacing
- AppTextStyles.* for typography
- Shared widgets (AppButton, AppCard, etc.)]

## Improvements Applied

- Used ModernBadge.success for sync status indicator
- Used AppDimensions.minTouchTarget (48dp) for touch targets
- Applied AppColors.* for consistent colors
- Used ModernEmptyState/ModernErrorState/ModernLoading for states
- Used ModernButton.*, ModernCard.* for interactions
```

### Quick Reference - Required Imports

```dart
// Theme tokens
import 'package:kasbon_pos/config/theme/theme.dart';

// Modern widgets (USE THIS)
import 'package:kasbon_pos/shared/modern/modern.dart';

// Responsive utilities
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
```

### Widget Replacement Table

| Instead of... | Use Modern Widget |
|--------------|-------------------|
| `ElevatedButton` | `ModernButton.primary()` |
| `OutlinedButton` | `ModernButton.outline()` |
| `TextButton` | `ModernButton.text()` |
| `TextField` | `ModernTextField` |
| `Card` | `ModernCard.elevated()` |
| `CircularProgressIndicator` | `ModernLoading()` |
| `AlertDialog` | `ModernDialog` |
| `SnackBar` | `ModernToast` |
| `AppButton.*` (legacy) | `ModernButton.*` |
| `AppCard.*` (legacy) | `ModernCard.*` |
| `AppTextField` (legacy) | `ModernTextField` |
