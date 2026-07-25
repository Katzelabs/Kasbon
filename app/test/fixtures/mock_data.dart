import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/pos/domain/entities/cart_item.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction_item.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';

/// Factory methods for creating test data
class MockData {
  MockData._();

  // ============================================
  // PRODUCT FACTORIES
  // ============================================

  /// Creates a test product with default values
  static Product createProduct({
    String? id,
    String? categoryId,
    String? sku,
    String? name,
    String? description,
    String? barcode,
    double? costPrice,
    double? sellingPrice,
    int? stock,
    int? minStock,
    String? unit,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return Product(
      id: id ?? 'prod-1',
      categoryId: categoryId,
      sku: sku ?? 'SKU-12345',
      name: name ?? 'Test Product',
      description: description,
      barcode: barcode,
      costPrice: costPrice ?? 10000,
      sellingPrice: sellingPrice ?? 15000,
      stock: stock ?? 100,
      minStock: minStock ?? 5,
      unit: unit ?? 'pcs',
      imageUrl: imageUrl,
      isActive: isActive ?? true,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Creates a product with low stock (at or below minStock but not zero)
  static Product lowStockProduct({
    String? id,
    String? name,
    int? stock,
    int? minStock,
  }) {
    return createProduct(
      id: id ?? 'prod-low-stock',
      name: name ?? 'Low Stock Product',
      stock: stock ?? 3,
      minStock: minStock ?? 5,
    );
  }

  /// Creates a product with zero stock
  static Product outOfStockProduct({
    String? id,
    String? name,
  }) {
    return createProduct(
      id: id ?? 'prod-out-of-stock',
      name: name ?? 'Out of Stock Product',
      stock: 0,
    );
  }

  /// Creates a product with high profit margin
  static Product highMarginProduct({
    String? id,
    String? name,
    double? costPrice,
    double? sellingPrice,
  }) {
    return createProduct(
      id: id ?? 'prod-high-margin',
      name: name ?? 'High Margin Product',
      costPrice: costPrice ?? 5000,
      sellingPrice: sellingPrice ?? 20000,
    );
  }

  // ============================================
  // CART ITEM FACTORIES
  // ============================================

  /// Creates a test cart item
  static CartItem createCartItem({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? createProduct(),
      quantity: quantity ?? 1,
    );
  }

  /// Creates a cart item that exceeds stock
  static CartItem cartItemExceedsStock({
    String? productId,
    String? productName,
    int? stock,
    int? quantity,
  }) {
    return CartItem(
      product: createProduct(
        id: productId ?? 'prod-exceeds',
        name: productName ?? 'Exceeds Stock Product',
        stock: stock ?? 5,
      ),
      quantity: quantity ?? 10,
    );
  }

  // ============================================
  // TRANSACTION ITEM FACTORIES
  // ============================================

  /// Creates a test transaction item
  static TransactionItem createTransactionItem({
    String? id,
    String? transactionId,
    String? productId,
    String? productName,
    String? productSku,
    int? quantity,
    double? costPrice,
    double? sellingPrice,
    double? discountAmount,
    double? subtotal,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    final qty = quantity ?? 2;
    final price = sellingPrice ?? 15000;
    final discount = discountAmount ?? 0;
    return TransactionItem(
      id: id ?? 'item-1',
      transactionId: transactionId ?? 'trx-1',
      productId: productId ?? 'prod-1',
      productName: productName ?? 'Test Product',
      productSku: productSku ?? 'SKU-12345',
      quantity: qty,
      costPrice: costPrice ?? 10000,
      sellingPrice: price,
      discountAmount: discount,
      subtotal: subtotal ?? (price * qty - discount),
      createdAt: createdAt ?? now,
    );
  }

  // ============================================
  // TRANSACTION FACTORIES
  // ============================================

  /// Creates a test transaction with default values (paid)
  static Transaction createTransaction({
    String? id,
    String? transactionNumber,
    String? customerName,
    double? subtotal,
    double? discountAmount,
    double? discountPercentage,
    double? taxAmount,
    double? total,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    double? cashReceived,
    double? cashChange,
    String? notes,
    String? cashierName,
    DateTime? transactionDate,
    DateTime? debtPaidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TransactionItem>? items,
  }) {
    final now = DateTime.now();
    final txItems = items ?? [createTransactionItem()];
    final double calcSubtotal =
        subtotal ?? txItems.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final double calcTotal = total ?? calcSubtotal;
    final double cashReceivedValue = cashReceived ?? calcTotal;

    return Transaction(
      id: id ?? 'trx-1',
      transactionNumber: transactionNumber ?? 'TRX-20260126-0001',
      customerName: customerName,
      subtotal: calcSubtotal,
      discountAmount: discountAmount ?? 0,
      discountPercentage: discountPercentage ?? 0,
      taxAmount: taxAmount ?? 0,
      total: calcTotal,
      paymentMethod: paymentMethod ?? PaymentMethod.cash,
      paymentStatus: paymentStatus ?? PaymentStatus.paid,
      cashReceived: cashReceivedValue,
      cashChange: cashChange ?? 0.0,
      notes: notes,
      cashierName: cashierName ?? 'Test Cashier',
      transactionDate: transactionDate ?? now,
      debtPaidAt: debtPaidAt,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      items: txItems,
    );
  }

  /// Creates a debt transaction
  static Transaction debtTransaction({
    String? id,
    String? transactionNumber,
    String? customerName,
    double? total,
    List<TransactionItem>? items,
    DateTime? debtPaidAt,
  }) {
    return createTransaction(
      id: id ?? 'trx-debt-1',
      transactionNumber: transactionNumber ?? 'TRX-20260126-0002',
      customerName: customerName ?? 'Customer Hutang',
      total: total,
      paymentMethod: PaymentMethod.debt,
      paymentStatus: PaymentStatus.debt,
      cashReceived: null,
      cashChange: null,
      debtPaidAt: debtPaidAt,
      items: items,
    );
  }

  /// Creates a transaction with multiple items
  static Transaction transactionWithMultipleItems({
    String? id,
    int itemCount = 3,
  }) {
    final items = List.generate(
      itemCount,
      (index) => createTransactionItem(
        id: 'item-${index + 1}',
        productId: 'prod-${index + 1}',
        productName: 'Product ${index + 1}',
        productSku: 'SKU-${10000 + index}',
        quantity: index + 1,
        costPrice: 10000.0 * (index + 1),
        sellingPrice: 15000.0 * (index + 1),
      ),
    );

    return createTransaction(
      id: id ?? 'trx-multi',
      items: items,
    );
  }

  // ============================================
  // SHOP SETTINGS FACTORIES
  // ============================================

  /// Creates test shop settings
  static ShopSettings createShopSettings({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? logoUrl,
    String? receiptHeader,
    String? receiptFooter,
    String? currency,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return ShopSettings(
      id: id ?? 'shop-1',
      name: name ?? 'Toko Test',
      address: address ?? 'Jl. Test No. 123',
      phone: phone ?? '081234567890',
      logoUrl: logoUrl,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter ?? 'Terima kasih!',
      currency: currency ?? 'IDR',
      lowStockThreshold: lowStockThreshold ?? 5,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Creates minimal shop settings (name only)
  static ShopSettings minimalShopSettings({
    String? name,
  }) {
    final now = DateTime.now();
    return ShopSettings(
      id: 'shop-minimal',
      name: name ?? 'Toko Minimal',
      createdAt: now,
      updatedAt: now,
    );
  }
}
