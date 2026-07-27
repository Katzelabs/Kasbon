import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/presentation/widgets/order_card.dart';

/// Design system showcase screen for previewing all reusable widgets
class DesignSystemShowcaseScreen extends StatefulWidget {
  const DesignSystemShowcaseScreen({super.key});

  @override
  State<DesignSystemShowcaseScreen> createState() =>
      _DesignSystemShowcaseScreenState();
}

class _DesignSystemShowcaseScreenState
    extends State<DesignSystemShowcaseScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    Tab(text: 'Colors'),
    Tab(text: 'Typography'),
    Tab(text: 'Buttons'),
    Tab(text: 'Inputs'),
    Tab(text: 'Badges'),
    Tab(text: 'Cards'),
    Tab(text: 'Feedback'),
    Tab(text: 'Layout'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Design System',
        onBack: () => Navigator.of(context).maybePop(),
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs,
            tabAlignment: TabAlignment.start,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ColorsSection(),
                _TypographySection(),
                _ButtonsSection(),
                _InputsSection(),
                _BadgesSection(),
                _CardsSection(),
                _FeedbackSection(),
                _LayoutSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// COLORS SECTION
// ===========================================================================

class _ColorsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Primary Colors'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildColorRow('Primary', AppColors.primary),
        _buildColorRow('Primary Light', AppColors.primaryLight),
        _buildColorRow('Primary Dark', AppColors.primaryDark),
        _buildColorRow('Primary Container', AppColors.primaryContainer),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Secondary Colors'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildColorRow('Secondary', AppColors.secondary),
        _buildColorRow('Secondary Light', AppColors.secondaryLight),
        _buildColorRow('Secondary Container', AppColors.secondaryContainer),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Status Colors'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildColorRow('Success', AppColors.success),
        _buildColorRow('Warning', AppColors.warning),
        _buildColorRow('Error', AppColors.error),
        _buildColorRow('Info', AppColors.info),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Text Colors'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildColorRow('Text Primary', AppColors.textPrimary),
        _buildColorRow('Text Secondary', AppColors.textSecondary),
        _buildColorRow('Text Tertiary', AppColors.textTertiary),
        _buildColorRow('Text Disabled', AppColors.textDisabled),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Category Colors'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: AppColors.categoryColors
              .asMap()
              .entries
              .map((e) => _buildColorChip('Cat ${e.key + 1}', e.value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildColorRow(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                Text(
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }
}

// ===========================================================================
// TYPOGRAPHY SECTION
// ===========================================================================

class _TypographySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Headings'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildTextSample('H1', AppTextStyles.h1),
        _buildTextSample('H2', AppTextStyles.h2),
        _buildTextSample('H3', AppTextStyles.h3),
        _buildTextSample('H4', AppTextStyles.h4),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Body Text'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildTextSample('Body Large', AppTextStyles.bodyLarge),
        _buildTextSample('Body Medium', AppTextStyles.bodyMedium),
        _buildTextSample('Body Small', AppTextStyles.bodySmall),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Labels'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildTextSample('Label Large', AppTextStyles.labelLarge),
        _buildTextSample('Label Medium', AppTextStyles.labelMedium),
        _buildTextSample('Label Small', AppTextStyles.labelSmall),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Prices'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildTextSample('Price Large - Rp 150.000', AppTextStyles.priceLarge),
        _buildTextSample('Price Medium - Rp 75.000', AppTextStyles.priceMedium),
        _buildTextSample('Price Small - Rp 25.000', AppTextStyles.priceSmall),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Other'),
        const SizedBox(height: AppDimensions.spacing12),
        _buildTextSample('Button', AppTextStyles.button),
        _buildTextSample('Caption', AppTextStyles.caption),
      ],
    );
  }

  Widget _buildTextSample(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: style),
          Text(
            '${style.fontSize}px - ${style.fontWeight}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// BUTTONS SECTION
// ===========================================================================

class _ButtonsSection extends StatefulWidget {
  @override
  State<_ButtonsSection> createState() => _ButtonsSectionState();
}

class _ButtonsSectionState extends State<_ButtonsSection> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Primary Buttons'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernButton.primary(onPressed: () {}, child: const Text('Primary')),
            ModernButton.primary(leadingIcon: Icons.add, onPressed: () {}, child: const Text('With Icon')),
            const ModernButton.primary(child: Text('Disabled')),
            ModernButton.primary(isLoading: true, onPressed: () {}, child: const Text('Loading')),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Secondary Buttons'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernButton.secondary(onPressed: () {}, child: const Text('Secondary')),
            ModernButton.secondary(leadingIcon: Icons.edit, onPressed: () {}, child: const Text('With Icon')),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Outline Buttons'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernButton.outline(onPressed: () {}, child: const Text('Outline')),
            ModernButton.outline(leadingIcon: Icons.add, onPressed: () {}, child: const Text('Tambah')),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Text Buttons'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernButton.text(onPressed: () {}, child: const Text('Text Button')),
            ModernButton.text(trailingIcon: Icons.chevron_right, onPressed: () {}, child: const Text('Lihat Semua')),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Button Sizes'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ModernButton.primary(size: ModernSize.small, onPressed: () {}, child: const Text('Small')),
            ModernButton.primary(size: ModernSize.medium, onPressed: () {}, child: const Text('Medium')),
            ModernButton.primary(size: ModernSize.large, onPressed: () {}, child: const Text('Large')),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Icon Buttons'),
        const SizedBox(height: AppDimensions.spacing12),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernIconButton.filled(icon: Icons.add, onPressed: () {}),
            ModernIconButton.tonal(icon: Icons.edit, onPressed: () {}),
            ModernIconButton.outlined(icon: Icons.delete, onPressed: () {}),
            ModernIconButton.standard(icon: Icons.more_vert, onPressed: () {}),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Quantity Stepper'),
        const SizedBox(height: AppDimensions.spacing12),
        Row(
          children: [
            ModernQuantityStepper(
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
            const SizedBox(width: AppDimensions.spacing16),
            ModernQuantityStepper.compact(
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// INPUTS SECTION
// ===========================================================================

class _InputsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: const [
        ModernSectionHeader(title: 'Text Fields'),
        SizedBox(height: AppDimensions.spacing12),
        ModernTextField(
          label: 'Nama Produk',
          hint: 'Masukkan nama produk',
        ),
        SizedBox(height: AppDimensions.spacing16),
        ModernTextField(
          label: 'Email',
          hint: 'contoh@email.com',
          leading: Icon(Icons.email_outlined),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AppDimensions.spacing16),
        ModernPasswordField(
          label: 'Password',
          hint: 'Masukkan password',
        ),
        SizedBox(height: AppDimensions.spacing16),
        ModernTextField(
          label: 'Dengan Error',
          hint: 'Field dengan error',
          errorText: 'Field ini wajib diisi',
        ),
        SizedBox(height: AppDimensions.spacing16),
        ModernTextField(
          label: 'Disabled',
          hint: 'Field disabled',
          enabled: false,
        ),
        SizedBox(height: AppDimensions.spacing24),
        ModernSectionHeader(title: 'Search Field'),
        SizedBox(height: AppDimensions.spacing12),
        ModernSearchField(
          hint: 'Cari produk...',
        ),
        SizedBox(height: AppDimensions.spacing24),
        ModernSectionHeader(title: 'Currency Field'),
        SizedBox(height: AppDimensions.spacing12),
        ModernCurrencyField(
          label: 'Harga',
          hint: '0',
        ),
      ],
    );
  }
}

// ===========================================================================
// BADGES SECTION
// ===========================================================================

class _BadgesSection extends StatefulWidget {
  @override
  State<_BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<_BadgesSection> {
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Status Badges'),
        const SizedBox(height: AppDimensions.spacing12),
        const Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernBadge.success(label: 'Sukses'),
            ModernBadge.warning(label: 'Proses'),
            ModernBadge.error(label: 'Gagal'),
            ModernBadge.info(label: 'Info'),
            ModernBadge.neutral(label: 'Netral'),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Badges with Dot'),
        const SizedBox(height: AppDimensions.spacing12),
        const Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernBadge.success(label: 'Siap Disajikan', showDot: true),
            ModernBadge.warning(label: 'Diproses', showDot: true),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Counter Badges'),
        const SizedBox(height: AppDimensions.spacing12),
        const Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            ModernCounterBadge(count: 5),
            ModernCounterBadge(count: 12),
            ModernCounterBadge(count: 99),
            ModernCounterBadge(count: 150),
            ModernCounterBadge(count: 3, variant: ModernBadgeVariant.error),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Category Chips'),
        const SizedBox(height: AppDimensions.spacing12),
        ModernChipGroup(
          items: const [
            ModernChipItem(label: 'Semua'),
            ModernChipItem(label: 'Makanan'),
            ModernChipItem(label: 'Minuman'),
            ModernChipItem(label: 'Snack'),
            ModernChipItem(label: 'Dessert'),
          ],
          selectedIndex: _selectedCategory,
          onSelected: (i) => setState(() => _selectedCategory = i),
        ),
      ],
    );
  }
}

// ===========================================================================
// CARDS SECTION
// ===========================================================================

class _CardsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Base Cards'),
        const SizedBox(height: AppDimensions.spacing12),
        const ModernCard.elevated(
          child: Text('Elevated Card'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        const ModernCard.outlined(
          child: Text('Outlined Card'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        const ModernCard.filled(
          child: Text('Filled Card'),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Order Cards'),
        const SizedBox(height: AppDimensions.spacing12),
        Row(
          children: [
            Expanded(
              child: OrderCard(
                orderNumber: '#001',
                itemCount: 3,
                status: OrderStatus.ready,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: OrderCard(
                orderNumber: '#002',
                itemCount: 5,
                status: OrderStatus.inProgress,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// FEEDBACK SECTION
// ===========================================================================

class _FeedbackSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Loading Indicators'),
        const SizedBox(height: AppDimensions.spacing12),
        const Row(
          children: [
            ModernLoading.small(),
            SizedBox(width: AppDimensions.spacing16),
            ModernLoading.medium(),
            SizedBox(width: AppDimensions.spacing16),
            ModernLoading.large(),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Shimmer Loading'),
        const SizedBox(height: AppDimensions.spacing12),
        Row(
          children: [
            ModernShimmer.circle(diameter: 48),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModernShimmer.box(width: 150, height: 16),
                  const SizedBox(height: AppDimensions.spacing8),
                  ModernShimmer.box(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Empty States'),
        const SizedBox(height: AppDimensions.spacing12),
        ModernCard.outlined(
          child: ModernEmptyState.list(
            title: 'Belum Ada Produk',
            message: 'Tambahkan produk pertama Anda',
          ),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Error States'),
        const SizedBox(height: AppDimensions.spacing12),
        ModernCard.outlined(
          child: ModernErrorState.network(),
        ),
      ],
    );
  }
}

// ===========================================================================
// LAYOUT SECTION
// ===========================================================================

class _LayoutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      children: [
        const ModernSectionHeader(title: 'Avatars'),
        const SizedBox(height: AppDimensions.spacing12),
        const Row(
          children: [
            ModernAvatar.small(initials: 'AB'),
            SizedBox(width: AppDimensions.spacing12),
            ModernAvatar.medium(initials: 'CD'),
            SizedBox(width: AppDimensions.spacing12),
            ModernAvatar.large(initials: 'EF'),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Section Headers'),
        const SizedBox(height: AppDimensions.spacing12),
        const ModernSectionHeader(title: 'Menu Items', subtitle: '12 produk'),
        const SizedBox(height: AppDimensions.spacing12),
        ModernSectionHeader.withSeeAll(
          title: 'Produk Terlaris',
          onSeeAll: () {},
        ),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Dividers'),
        const SizedBox(height: AppDimensions.spacing12),
        const ModernDivider(),
        const SizedBox(height: AppDimensions.spacing24),
        const ModernSectionHeader(title: 'Summary Rows'),
        const SizedBox(height: AppDimensions.spacing12),
        ModernCard.outlined(
          child: Column(
            children: [
              const ModernSummaryRow(label: 'Subtotal', value: 'Rp 75.000'),
              const ModernSummaryRow(label: 'Pajak (10%)', value: 'Rp 7.500'),
              const ModernSummaryRow(label: 'Diskon', value: '- Rp 5.000'),
              const ModernDivider(),
              ModernSummaryRow.total(label: 'Total', value: 'Rp 77.500'),
            ],
          ),
        ),
      ],
    );
  }
}
