import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/modern/modern.dart';
import '../../../categories/domain/usecases/create_category.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/create_product.dart';
import '../providers/products_provider.dart';
import '../widgets/category_autocomplete_field.dart';
import '../widgets/product_image_picker.dart';

/// Screen for adding or editing a product
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({
    super.key,
    this.productId,
  });

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _barcodeController = TextEditingController();

  String _selectedUnit = 'pcs';
  String? _imagePath;
  late String _tempProductId;
  Product? _existingProduct;
  CategorySelection _categorySelection = const NoCategory();
  String? _initialCategoryId;

  final List<String> _units = [
    'pcs',
    'kg',
    'liter',
    'pack',
    'buah',
    'lusin',
    'dus',
    'sachet',
    'karung',
  ];

  @override
  void initState() {
    super.initState();
    // Set default values
    _stockController.text = '0';
    _minStockController.text = '5';
    // Generate a temporary product ID for new products (used for image naming)
    _tempProductId = widget.productId ?? const Uuid().v4();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  String _formatCurrency(int number) {
    if (number == 0) return '';
    final chars = number.toString().split('').reversed.toList();
    final result = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) result.add('.');
      result.add(chars[i]);
    }
    return result.reversed.join();
  }

  double _parseCurrencyText(String text) {
    return double.parse(text.replaceAll('.', ''));
  }

  void _populateForm(Product product) {
    _existingProduct = product;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _costPriceController.text = _formatCurrency(product.costPrice.toInt());
    _sellingPriceController.text = _formatCurrency(product.sellingPrice.toInt());
    _stockController.text = product.stock.toString();
    _minStockController.text = product.minStock.toString();
    _barcodeController.text = product.barcode ?? '';
    // Safely set unit - default to 'pcs' if unit not in list
    _selectedUnit = _units.contains(product.unit) ? product.unit : 'pcs';
    _imagePath = product.imageUrl;
    _initialCategoryId = product.categoryId;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final formNotifier = ref.read(productFormProvider.notifier);
    final description = _descriptionController.text.trim();
    final barcode = _barcodeController.text.trim();

    // Resolve category selection
    String? categoryId;
    switch (_categorySelection) {
      case ExistingCategory(:final category):
        categoryId = category.id;
      case NewCategoryName(:final name):
        final createCategory = getIt<CreateCategory>();
        final result =
            await createCategory(CreateCategoryParams(name: name));
        final resolved = result.fold(
          (failure) {
            if (mounted) {
              ModernToast.error(
                context,
                'Gagal membuat kategori: ${failure.message}',
              );
            }
            return null;
          },
          (category) => category.id,
        );
        if (resolved == null) return;
        categoryId = resolved;
        ref.invalidate(categoriesProvider);
      case NoCategory():
        categoryId = null;
    }

    if (widget.isEditing && _existingProduct != null) {
      final updatedProduct = _existingProduct!.copyWith(
        name: _nameController.text.trim(),
        description: description.isNotEmpty ? description : null,
        categoryId: categoryId,
        clearCategoryId: categoryId == null,
        costPrice: _parseCurrencyText(_costPriceController.text),
        sellingPrice: _parseCurrencyText(_sellingPriceController.text),
        stock: int.parse(_stockController.text),
        minStock: int.parse(_minStockController.text),
        barcode: barcode.isNotEmpty ? barcode : null,
        unit: _selectedUnit,
        imageUrl: _imagePath,
      );
      await formNotifier.updateProduct(updatedProduct);
    } else {
      final params = CreateProductParams(
        name: _nameController.text.trim(),
        description: description.isNotEmpty ? description : null,
        categoryId: categoryId,
        costPrice: _parseCurrencyText(_costPriceController.text),
        sellingPrice: _parseCurrencyText(_sellingPriceController.text),
        stock: int.parse(_stockController.text),
        minStock: int.parse(_minStockController.text),
        barcode: barcode.isNotEmpty ? barcode : null,
        unit: _selectedUnit,
        imageUrl: _imagePath,
      );
      await formNotifier.createProduct(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(productFormProvider);

    // Listen for form state changes
    ref.listen(productFormProvider, (previous, next) {
      if (next.isSuccess) {
        ref.invalidate(productsProvider);
        ModernToast.success(
          context,
          widget.isEditing
              ? 'Produk berhasil diperbarui'
              : 'Produk berhasil ditambahkan',
        );
        context.pop();
      } else if (next.errorMessage != null) {
        ModernToast.error(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: widget.isEditing ? 'Edit Produk' : 'Tambah Produk',
        onBack: () => context.pop(),
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: widget.isEditing
          ? _buildEditForm()
          : _buildFormContent(formState.isLoading),
    );
  }

  Widget _buildEditForm() {
    final productAsync = ref.watch(productProvider(widget.productId!));

    return productAsync.when(
      data: (product) {
        // Populate form only once
        if (_existingProduct == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _populateForm(product);
            setState(() {});
          });
        }
        final formState = ref.watch(productFormProvider);
        return _buildFormContent(formState.isLoading);
      },
      loading: () => const Center(child: ModernLoading()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text('Error: $error'),
            const SizedBox(height: AppDimensions.spacing16),
            ModernButton.primary(
              onPressed: () => ref.invalidate(productProvider(widget.productId!)),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isLoading) {
    final isTablet = context.isTabletOrDesktop;

    return isTablet
        ? _buildTabletLayout(isLoading)
        : _buildMobileLayout(isLoading);
  }

  Widget _buildMobileLayout(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageCard(),
            const SizedBox(height: AppDimensions.spacing16),
            _buildInfoCard(),
            const SizedBox(height: AppDimensions.spacing16),
            _buildPriceCard(),
            const SizedBox(height: AppDimensions.spacing16),
            _buildStockCard(),
            const SizedBox(height: AppDimensions.spacing16),
            _buildOtherCard(),
            const SizedBox(height: AppDimensions.spacing24),
            _buildMobileActionButtons(isLoading),
            const SizedBox(height: AppDimensions.spacing16),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Foto + Informasi Dasar + Stok
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageCard(),
                  const SizedBox(height: AppDimensions.spacing16),
                  _buildInfoCard(),
                  const SizedBox(height: AppDimensions.spacing16),
                  _buildStockCard(),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacing16),

            // Right Column: Harga + Lainnya + Buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPriceCard(),
                  const SizedBox(height: AppDimensions.spacing16),
                  _buildOtherCard(),
                  const SizedBox(height: AppDimensions.spacing24),
                  _buildTabletActionButtons(isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Foto Produk'),
          const SizedBox(height: AppDimensions.spacing12),
          Center(
            child: ProductImagePicker(
              currentImagePath: _imagePath,
              productId: _tempProductId,
              onImageChanged: (path) {
                setState(() => _imagePath = path);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Informasi Dasar'),
          const SizedBox(height: AppDimensions.spacing12),
          ModernTextField(
            controller: _nameController,
            label: 'Nama Produk *',
            hint: 'Masukkan nama produk',
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                Validators.required(value, fieldName: 'Nama produk'),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ModernTextField.multiline(
            controller: _descriptionController,
            label: 'Deskripsi',
            hint: 'Deskripsi produk (opsional)',
            maxLines: 3,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Consumer(
            builder: (context, ref, _) {
              final categoriesAsync = ref.watch(categoriesProvider);
              return categoriesAsync.when(
                data: (categories) {
                  final initialCategory = _initialCategoryId != null
                      ? categories
                          .where((c) => c.id == _initialCategoryId)
                          .firstOrNull
                      : null;
                  return CategoryAutocompleteField(
                    categories: categories,
                    initialCategory: initialCategory,
                    onChanged: (selection) {
                      setState(() => _categorySelection = selection);
                    },
                  );
                },
                loading: () => const ModernTextField(
                  label: 'Kategori',
                  hint: 'Memuat...',
                  enabled: false,
                ),
                error: (_, __) => const ModernTextField(
                  label: 'Kategori',
                  hint: 'Gagal memuat kategori',
                  enabled: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Harga'),
          const SizedBox(height: AppDimensions.spacing12),
          ModernCurrencyField(
            controller: _costPriceController,
            label: 'Harga Modal *',
            validator: (value) =>
                Validators.positiveNumber(value, fieldName: 'Harga modal'),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ModernCurrencyField(
            controller: _sellingPriceController,
            label: 'Harga Jual *',
            validator: (value) =>
                Validators.positiveNumber(value, fieldName: 'Harga jual'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Stok'),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: ModernTextField(
                  controller: _stockController,
                  label: 'Stok Awal',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      Validators.nonNegativeNumber(value, fieldName: 'Stok'),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: ModernTextField(
                  controller: _minStockController,
                  label: 'Min. Stok',
                  hint: '5',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => Validators.nonNegativeNumber(value,
                      fieldName: 'Minimal stok'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ModernDropdown<String>(
            label: 'Satuan',
            value: _selectedUnit,
            items: _units.map((unit) {
              return DropdownMenuItem(
                value: unit,
                child: Text(unit),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedUnit = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherCard() {
    return ModernCard.outlined(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Lainnya'),
          const SizedBox(height: AppDimensions.spacing12),
          ModernTextField(
            controller: _barcodeController,
            label: 'Barcode',
            hint: 'Scan atau masukkan barcode (opsional)',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            leading: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionButtons(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernButton.primary(
          onPressed: isLoading ? null : _submitForm,
          isLoading: isLoading,
          fullWidth: true,
          child: Text(widget.isEditing ? 'Perbarui' : 'Simpan'),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        ModernButton.outline(
          onPressed: isLoading ? null : () => context.pop(),
          fullWidth: true,
          child: const Text('Batal'),
        ),
      ],
    );
  }

  Widget _buildTabletActionButtons(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: ModernButton.outline(
            onPressed: isLoading ? null : () => context.pop(),
            fullWidth: true,
            child: const Text('Batal'),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: ModernButton.primary(
            onPressed: isLoading ? null : _submitForm,
            isLoading: isLoading,
            fullWidth: true,
            child: Text(widget.isEditing ? 'Perbarui' : 'Simpan'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}
