import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/responsive/modern_content_column.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/modern/modern.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../products/presentation/widgets/profit_margin_summary.dart';
import '../../domain/entities/business_type.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_progress.dart';

/// The setup a new account cannot skip, and the two bits it can.
///
/// The signup trigger creates a `user_profiles` row and nothing else: no shop,
/// no categories, no products. Before this screen existed a verified user
/// landed on a dashboard of zeros with an empty POS grid, and had to find
/// Settings -> Profil Toko unprompted before their receipts even carried a
/// name. Step 1 closes that hole and blocks; steps 2 and 3 fill the app with
/// something to sell and can be skipped.
///
/// Lives outside the `ShellRoute` deliberately - a wizard with a bottom nav bar
/// under it is a wizard the user can walk out of halfway.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  // Step 1
  final _shopFormKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();

  // Step 2
  final _customCategoryController = TextEditingController();

  // Step 3
  final _productFormKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  String? _selectedCategoryId;

  @override
  void dispose() {
    _pageController.dispose();
    _shopNameController.dispose();
    _customCategoryController.dispose();
    _productNameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _animateTo(OnboardingStep step) {
    _pageController.animateToPage(
      step.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onShopContinue() async {
    FocusScope.of(context).unfocus();
    if (!_shopFormKey.currentState!.validate()) return;
    if (ref.read(onboardingProvider).businessType == null) return;

    final saved =
        await ref.read(onboardingProvider.notifier).saveShopAndContinue();
    if (!mounted) return;
    if (saved) _animateTo(OnboardingStep.categories);
  }

  Future<void> _onCategoriesContinue() async {
    FocusScope.of(context).unfocus();
    final saved =
        await ref.read(onboardingProvider.notifier).saveCategoriesAndContinue();
    if (!mounted) return;
    if (saved) {
      ref.invalidate(categoriesProvider);
      _animateTo(OnboardingStep.product);
    }
  }

  void _onSkipCategories() {
    ref.read(onboardingProvider.notifier).goToStep(OnboardingStep.product);
    _animateTo(OnboardingStep.product);
  }

  Future<void> _onProductContinue() async {
    FocusScope.of(context).unfocus();
    if (!_productFormKey.currentState!.validate()) return;

    final saved = await ref.read(onboardingProvider.notifier).saveProduct(
          name: _productNameController.text,
          costPrice: _parseCurrency(_costPriceController.text) ?? 0,
          sellingPrice: _parseCurrency(_sellingPriceController.text) ?? 0,
          stock: int.tryParse(_stockController.text.trim()) ?? 0,
          categoryId: _selectedCategoryId,
        );
    if (!mounted) return;
    if (saved) await _finish();
  }

  Future<void> _onSkipProduct() => _finish();

  Future<void> _finish() async {
    // Marker first, navigation second. The router's gate reads it, so leaving
    // before it lands bounces the user straight back into the wizard.
    final done = await ref.read(onboardingProvider.notifier).finish();
    if (!mounted) return;

    if (!done) {
      ModernToast.error(
        context,
        ref.read(onboardingProvider).errorMessage ??
            'Gagal menyelesaikan pengaturan',
      );
      return;
    }

    ref.invalidate(categoriesProvider);
    ref.invalidate(paginatedProductsProvider);

    // POS, not the dashboard: on day one the dashboard is a wall of zeros,
    // while POS with products in it reads as an app that is ready.
    context.go(AppRoutes.pos);
  }

  double? _parseCurrency(String text) =>
      double.tryParse(text.replaceAll('.', ''));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return ModernScaffold(
      body: SafeArea(
        child: ModernContentColumn.form(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppDimensions.spacing24,
                  0,
                  AppDimensions.spacing16,
                ),
                child: OnboardingProgress(
                  currentIndex: state.step.index,
                  totalSteps: OnboardingStep.values.length,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  // Steps advance by button, not by swipe: step 1 has to pass
                  // validation before the wizard is allowed to move on, and a
                  // swipe has nowhere to report that it refused.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => ref
                      .read(onboardingProvider.notifier)
                      .goToStep(OnboardingStep.values[index]),
                  children: [
                    _buildShopStep(state),
                    _buildCategoriesStep(state),
                    _buildProductStep(state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 1 - the shop
  // ---------------------------------------------------------------------

  Widget _buildShopStep(OnboardingState state) {
    return SingleChildScrollView(
      child: Form(
        key: _shopFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeading(
              title: 'Tentang Toko Anda',
              subtitle: 'Dua pertanyaan singkat, lalu kita siapkan isinya',
            ),
            ModernTextField(
              label: 'Nama Toko',
              hint: 'Contoh: Warung Bu Sri',
              controller: _shopNameController,
              leading: const Icon(Icons.store_rounded),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              autofocus: true,
              onChanged:
                  ref.read(onboardingProvider.notifier).setShopName,
              validator: (value) => Validators.minLength(value, 2,
                  fieldName: 'Nama toko'),
              enabled: !state.isSaving,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: AppDimensions.spacing24),
            const Text('Jenis Usaha', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              'Kami pakai ini untuk menyiapkan kategori awal',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Wrap(
              spacing: AppDimensions.spacing8,
              runSpacing: AppDimensions.spacing8,
              children: [
                for (final type in BusinessType.values)
                  ModernChip.filter(
                    label: type.label,
                    icon: type.icon,
                    selected: state.businessType == type,
                    enabled: !state.isSaving,
                    onSelected: (_) => ref
                        .read(onboardingProvider.notifier)
                        .setBusinessType(type),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing24),
            _ErrorText(state.errorMessage),
            ModernButton.primary(
              onPressed: state.isSaving || !state.canLeaveShopStep
                  ? null
                  : _onShopContinue,
              isLoading: state.isSaving,
              size: ModernSize.large,
              fullWidth: true,
              child: const Text('Lanjut'),
            ),
            const SizedBox(height: AppDimensions.spacing24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 2 - categories
  // ---------------------------------------------------------------------

  Widget _buildCategoriesStep(OnboardingState state) {
    final suggestions = <String>{
      ...?state.businessType?.starterCategories,
      ...state.selectedCategories,
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(
            title: 'Kategori Produk',
            subtitle: 'Kami sudah pilihkan yang umum. Ubah sesuka Anda',
          ),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              for (final name in suggestions)
                ModernChip.filter(
                  label: name,
                  selected: state.selectedCategories.contains(name),
                  enabled: !state.isSaving,
                  onSelected: (_) => ref
                      .read(onboardingProvider.notifier)
                      .toggleCategory(name),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing20),
          ModernTextField(
            label: 'Tambah Kategori Lain',
            hint: 'Contoh: Gorengan',
            controller: _customCategoryController,
            leading: const Icon(Icons.add_rounded),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 50,
            enabled: !state.isSaving,
            onSubmitted: (_) => _addCustomCategory(),
            trailing: const Icon(Icons.check_rounded),
            onTrailingTap: _addCustomCategory,
          ),
          const SizedBox(height: AppDimensions.spacing24),
          _ErrorText(state.errorMessage),
          ModernButton.primary(
            onPressed: state.isSaving ? null : _onCategoriesContinue,
            isLoading: state.isSaving,
            size: ModernSize.large,
            fullWidth: true,
            child: Text(
              state.selectedCategories.isEmpty
                  ? 'Lanjut'
                  : 'Buat ${state.selectedCategories.length} Kategori',
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          ModernButton.text(
            onPressed: state.isSaving ? null : _onSkipCategories,
            child: const Text('Lewati'),
          ),
          const SizedBox(height: AppDimensions.spacing24),
        ],
      ),
    );
  }

  void _addCustomCategory() {
    ref
        .read(onboardingProvider.notifier)
        .addCustomCategory(_customCategoryController.text);
    _customCategoryController.clear();
  }

  // ---------------------------------------------------------------------
  // Step 3 - the first product
  // ---------------------------------------------------------------------

  Widget _buildProductStep(OnboardingState state) {
    final cost = _parseCurrency(_costPriceController.text);
    final selling = _parseCurrency(_sellingPriceController.text);

    return SingleChildScrollView(
      child: Form(
        key: _productFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeading(
              title: 'Produk Pertama',
              subtitle: 'Isi harga modal dan harga jual - untungnya kami '
                  'hitung otomatis',
            ),
            ModernTextField(
              label: 'Nama Produk',
              hint: 'Contoh: Es Teh Manis',
              controller: _productNameController,
              leading: const Icon(Icons.inventory_2_outlined),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              validator: (value) =>
                  Validators.required(value, fieldName: 'Nama produk'),
              enabled: !state.isSaving,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: AppDimensions.spacing16),
            ModernCurrencyField(
              controller: _costPriceController,
              label: 'Harga Modal',
              validator: (value) =>
                  Validators.positiveNumber(value, fieldName: 'Harga modal'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            ModernCurrencyField(
              controller: _sellingPriceController,
              label: 'Harga Jual',
              validator: (value) =>
                  Validators.positiveNumber(value, fieldName: 'Harga jual'),
              onChanged: (_) => setState(() {}),
            ),
            // The whole reason this step asks for a cost price at all: the
            // margin appears as it is typed, and the user finds out what the
            // app is for without being told.
            if (cost != null && selling != null && cost > 0) ...[
              const SizedBox(height: AppDimensions.spacing16),
              ModernCard.filled(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: ProfitMarginSummary(
                  costPrice: cost,
                  sellingPrice: selling,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacing16),
            ModernTextField(
              label: 'Stok Awal',
              controller: _stockController,
              leading: const Icon(Icons.numbers_rounded),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              maxLength: 6,
              enabled: !state.isSaving,
            ),
            if (state.createdCategories.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacing16),
              ModernDropdown<String>(
                label: 'Kategori',
                hint: 'Pilih kategori',
                value: _selectedCategoryId,
                items: [
                  for (final category in state.createdCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                enabled: !state.isSaving,
                onChanged: (value) =>
                    setState(() => _selectedCategoryId = value),
              ),
            ],
            const SizedBox(height: AppDimensions.spacing24),
            _ErrorText(state.errorMessage),
            ModernButton.primary(
              onPressed: state.isSaving ? null : _onProductContinue,
              isLoading: state.isSaving,
              size: ModernSize.large,
              fullWidth: true,
              child: const Text('Simpan & Mulai Jualan'),
            ),
            const SizedBox(height: AppDimensions.spacing8),
            ModernButton.text(
              onPressed: state.isSaving ? null : _onSkipProduct,
              child: const Text('Lewati, nanti saja'),
            ),
            const SizedBox(height: AppDimensions.spacing24),
          ],
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h2),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing24),
      ],
    );
  }
}

/// The wizard's failure line. Nothing when the last step succeeded.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message!,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}
