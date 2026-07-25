import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';

import '../../../../../fixtures/mock_data.dart';

void main() {
  group('Product', () {
    late Product product;

    setUp(() {
      product = MockData.createProduct(
        id: 'prod-1',
        sku: 'SKU-12345',
        name: 'Test Product',
        costPrice: 10000,
        sellingPrice: 15000,
        stock: 100,
        minStock: 5,
      );
    });

    group('profit', () {
      test('calculates profit as selling price minus cost price', () {
        expect(product.profit, 5000);
      });

      test('returns zero when selling price equals cost price', () {
        final noMarginProduct = MockData.createProduct(
          costPrice: 10000,
          sellingPrice: 10000,
        );
        expect(noMarginProduct.profit, 0);
      });

      test('returns negative when selling below cost', () {
        final lossProduct = MockData.createProduct(
          costPrice: 15000,
          sellingPrice: 10000,
        );
        expect(lossProduct.profit, -5000);
      });
    });

    group('profitMargin', () {
      test('calculates profit margin as percentage', () {
        // (15000 - 10000) / 10000 * 100 = 50%
        expect(product.profitMargin, 50);
      });

      test('returns zero when cost price is zero', () {
        final zeroCostProduct = MockData.createProduct(
          costPrice: 0,
          sellingPrice: 10000,
        );
        expect(zeroCostProduct.profitMargin, 0);
      });

      test('calculates 100% margin for double price', () {
        final doubleProduct = MockData.createProduct(
          costPrice: 10000,
          sellingPrice: 20000,
        );
        expect(doubleProduct.profitMargin, 100);
      });

      test('calculates negative margin when selling at loss', () {
        final lossProduct = MockData.createProduct(
          costPrice: 20000,
          sellingPrice: 10000,
        );
        expect(lossProduct.profitMargin, -50);
      });
    });

    group('isLowStock', () {
      test('returns true when stock equals minStock', () {
        final lowStockProduct = MockData.createProduct(
          stock: 5,
          minStock: 5,
        );
        expect(lowStockProduct.isLowStock, true);
      });

      test('returns true when stock is below minStock but above zero', () {
        final lowStockProduct = MockData.createProduct(
          stock: 3,
          minStock: 5,
        );
        expect(lowStockProduct.isLowStock, true);
      });

      test('returns false when stock is above minStock', () {
        final normalStockProduct = MockData.createProduct(
          stock: 10,
          minStock: 5,
        );
        expect(normalStockProduct.isLowStock, false);
      });

      test('returns false when stock is zero (out of stock)', () {
        final outOfStockProduct = MockData.createProduct(
          stock: 0,
          minStock: 5,
        );
        expect(outOfStockProduct.isLowStock, false);
      });
    });

    group('isOutOfStock', () {
      test('returns true when stock is zero', () {
        final outOfStockProduct = MockData.createProduct(stock: 0);
        expect(outOfStockProduct.isOutOfStock, true);
      });

      test('returns true when stock is negative', () {
        final negativeStockProduct = MockData.createProduct(stock: -1);
        expect(negativeStockProduct.isOutOfStock, true);
      });

      test('returns false when stock is positive', () {
        final inStockProduct = MockData.createProduct(stock: 1);
        expect(inStockProduct.isOutOfStock, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated name', () {
        final updated = product.copyWith(name: 'New Name');
        expect(updated.name, 'New Name');
        expect(updated.id, product.id);
        expect(updated.sku, product.sku);
      });

      test('creates copy with updated price', () {
        final updated = product.copyWith(sellingPrice: 20000);
        expect(updated.sellingPrice, 20000);
        expect(updated.costPrice, product.costPrice);
      });

      test('creates copy with updated stock', () {
        final updated = product.copyWith(stock: 50);
        expect(updated.stock, 50);
        expect(updated.name, product.name);
      });

      test('preserves original values when not updated', () {
        final updated = product.copyWith(name: 'New Name');
        expect(updated.costPrice, product.costPrice);
        expect(updated.sellingPrice, product.sellingPrice);
        expect(updated.stock, product.stock);
        expect(updated.minStock, product.minStock);
        expect(updated.unit, product.unit);
        expect(updated.isActive, product.isActive);
      });

      test('can update multiple fields at once', () {
        final updated = product.copyWith(
          name: 'Updated Product',
          costPrice: 12000,
          sellingPrice: 18000,
          stock: 200,
        );
        expect(updated.name, 'Updated Product');
        expect(updated.costPrice, 12000);
        expect(updated.sellingPrice, 18000);
        expect(updated.stock, 200);
      });

      test('can update optional fields', () {
        final updated = product.copyWith(
          description: 'New description',
          barcode: '1234567890123',
          imageUrl: 'https://example.com/image.jpg',
        );
        expect(updated.description, 'New description');
        expect(updated.barcode, '1234567890123');
        expect(updated.imageUrl, 'https://example.com/image.jpg');
      });

      test('creates new instance (immutable)', () {
        final updated = product.copyWith(name: 'New Name');
        expect(identical(product, updated), false);
        expect(product.name, 'Test Product');
      });
    });

    group('equality', () {
      test('products with same id and sku are equal', () {
        final product1 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        final product2 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        expect(product1, equals(product2));
      });

      test('products with different id are not equal', () {
        final product1 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        final product2 = MockData.createProduct(id: 'prod-2', sku: 'SKU-123');
        expect(product1, isNot(equals(product2)));
      });

      test('products with different sku are not equal', () {
        final product1 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        final product2 = MockData.createProduct(id: 'prod-1', sku: 'SKU-456');
        expect(product1, isNot(equals(product2)));
      });

      test('hashCode is consistent with equality', () {
        final product1 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        final product2 = MockData.createProduct(id: 'prod-1', sku: 'SKU-123');
        expect(product1.hashCode, equals(product2.hashCode));
      });
    });

    group('factory methods', () {
      test('lowStockProduct creates product with low stock', () {
        final lowStock = MockData.lowStockProduct();
        expect(lowStock.isLowStock, true);
        expect(lowStock.isOutOfStock, false);
      });

      test('outOfStockProduct creates product with zero stock', () {
        final outOfStock = MockData.outOfStockProduct();
        expect(outOfStock.isOutOfStock, true);
        expect(outOfStock.stock, 0);
      });

      test('highMarginProduct creates product with high profit', () {
        final highMargin = MockData.highMarginProduct();
        expect(highMargin.profit, 15000); // 20000 - 5000
        expect(highMargin.profitMargin, 300); // (20000 - 5000) / 5000 * 100
      });
    });
  });
}
