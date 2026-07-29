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
  Product? _existingProduct;
  CategorySelection _categorySelection = const NoCategory();
  String? _initialCategoryId;

  /// Which product the fields currently hold.
  ///
  /// The populate guard used to be `_existingProduct == null`, which answers
  /// "have I loaded anything?" rather than "have I loaded *this*?" - so a
  /// mounted form silently kept editing the previous record when the selection
  /// changed underneath it.
  String? _populatedForId;

  ProviderSubscription<AsyncValue<Product>>? _productSubscription;

  /// Whether the first build has happened.
  ///
  /// The subscription below fires immediately, which for a cached product means
  /// inside `initState`. Calling `setState` there would mark an element dirty
  /// while it is being built; before the first build there is nothing to
  /// invalidate anyway, since the fields are simply read fresh.
  bool _hasBuilt = false;

  /// Owns image uploads for a product that does not exist yet.
  ///
  /// Lazily initialised rather than generated in `initState` so it cannot go
  /// stale: a form that switches to another product now files uploads under
  /// that product's id, not under the id it was first opened with.
  late final String _draftProductId = const Uuid().v4();

  String get _imageOwnerId => widget.productId ?? _draftProductId;

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
    _watchProduct();
  }

  @override
  void didUpdateWidget(ProductFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The router keys this screen by product id, so in practice a change here
    // means a caller built it without that key. Re-subscribing rather than
    // trusting the key is what makes the populate id-aware instead of
    // mount-aware.
    if (oldWidget.productId != widget.productId) {
      _watchProduct();
    }
  }

  /// Subscribes to the product being edited and populates the form from it.
  ///
  /// A listener rather than a `ref.watch` in `build`: populating during a build
  /// meant an `addPostFrameCallback` plus a `setState` a frame later, which is
  /// a setState-during-build hazard wearing a delay.
  void _watchProduct() {
    _productSubscription?.close();
    _productSubscription = null;
    _populatedForId = null;
    _existingProduct = null;
    _categorySelection = const NoCategory();
    _initialCategoryId = null;

    final id = widget.productId;
    if (id == null) return;

    _productSubscription = ref.listenManual<AsyncValue<Product>>(
      productProvider(id),
      (previous, next) {
        final product = next.valueOrNull;
        if (product == null || product.id == _populatedForId) return;
        _populateForm(product);
        if (_hasBuilt && mounted) setState(() {});
      },
      fireImmediately: true,
    );
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
    _populatedForId = product.id;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _costPriceController.text = _formatCurrency(product.costPrice.toInt());
    _sellingPriceController.text =
        _formatCurrency(product.sellingPrice.toInt());
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
        final result = await createCategory(CreateCategoryParams(name: name));
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
    _hasBuilt = true;
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
        _dismiss();
      } else if (next.errorMessage != null) {
        ModernToast.error(context, next.errorMessage!);
      }
    });

    final title = widget.isEditing ? 'Edit Produk' : 'Tambah Produk';
    final body = widget.isEditing
        ? _buildEditForm()
        : _buildFormContent(formState.isLoading);

    // A screen, never a pane. This used to branch on DetailPaneScope and wear
    // panel chrome when the products list docked it beside the grid; editing
    // now takes the window at every width, the way adding always has, so there
    // is one presentation to reason about.
    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: title,
        onBack: () => context.pop(),
        onProfileTap: () {
          // TODO: Navigate to profile
        },
      ),
      body: body,
    );
  }

  /// Leaves this screen.
  ///
  /// A pop rather than a `go`, because the routes are nested: closing
  /// `/products/:id/edit` lands on `/products/:id` - the detail, or the list
  /// with that product open in its panel - rather than dropping the selection.
  void _dismiss() => context.pop();

  Widget _buildEditForm() {
    // Watched only for its loading and error states; the fields themselves are
    // filled by the subscription set up in initState.
    final productAsync = ref.watch(productProvider(widget.productId!));

    return productAsync.when(
      data: (_) {
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
              onPressed: () =>
                  ref.invalidate(productProvider(widget.productId!)),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isLoading) {
    // The space the form has, not the window - the two-column fork is fed pane
    // width when this is the detail half of a split view.
    final isWide = context.isAtLeast(Breakpoint.expanded);

    return isWide
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
        // Tab order goes left-right by row, card by whole card.
        //
        // The default reading-order policy sorts focus nodes into horizontal
        // bands, and the bands here depend on how tall each card happens to
        // be. The two columns' cards do not line up, so Barcode - the only
        // field in the right column's second card - lands in the middle of
        // Nama / Deskripsi / Kategori. Worse, Deskripsi is multi-line and
        // grows as it is typed into, so the tab order can shift while the user
        // is filling the form in.
        //
        // An explicit order is the only way to make it stable. Note the
        // consequence: row one is Foto | Harga, and Foto holds no tab stop, so
        // the first Tab now lands on Harga Modal rather than Nama Produk.
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Foto + Informasi Dasar + Stok
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: _buildImageCard(),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: _buildInfoCard(),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(5),
                      child: _buildStockCard(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing16),

              // Right Column: Harga + Lainnya + Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: _buildPriceCard(),
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(4),
                      child: _buildOtherCard(),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),
                    // Last, whatever the rows above did: the save button is
                    // where a form ends.
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(6),
                      child: _buildTabletActionButtons(isLoading),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              productId: _imageOwnerId,
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
                    // Keyed by record so the field's own controller resets with
                    // the rest of the form when the selection changes.
                    key: ValueKey('category-${_populatedForId ?? 'new'}'),
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
          onPressed: isLoading ? null : _dismiss,
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
            onPressed: isLoading ? null : _dismiss,
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
