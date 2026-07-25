import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/pos/domain/entities/cart_item.dart';

import '../../../../../fixtures/mock_data.dart';

void main() {
  group('CartItem', () {
    group('subtotal', () {
      test('calculates subtotal as selling price times quantity', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(sellingPrice: 15000),
          quantity: 2,
        );
        expect(cartItem.subtotal, 30000);
      });

      test('returns zero for quantity of zero', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(sellingPrice: 15000),
          quantity: 0,
        );
        expect(cartItem.subtotal, 0);
      });

      test('handles single quantity correctly', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(sellingPrice: 25000),
          quantity: 1,
        );
        expect(cartItem.subtotal, 25000);
      });

      test('handles large quantities', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(sellingPrice: 5000),
          quantity: 100,
        );
        expect(cartItem.subtotal, 500000);
      });
    });

    group('profit', () {
      test('calculates profit as (selling - cost) times quantity', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(
            costPrice: 10000,
            sellingPrice: 15000,
          ),
          quantity: 2,
        );
        // (15000 - 10000) * 2 = 10000
        expect(cartItem.profit, 10000);
      });

      test('returns zero profit when selling at cost', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(
            costPrice: 10000,
            sellingPrice: 10000,
          ),
          quantity: 3,
        );
        expect(cartItem.profit, 0);
      });

      test('returns negative profit when selling below cost', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(
            costPrice: 15000,
            sellingPrice: 10000,
          ),
          quantity: 2,
        );
        // (10000 - 15000) * 2 = -10000
        expect(cartItem.profit, -10000);
      });

      test('returns zero profit for zero quantity', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(
            costPrice: 10000,
            sellingPrice: 15000,
          ),
          quantity: 0,
        );
        expect(cartItem.profit, 0);
      });
    });

    group('exceedsStock', () {
      test('returns true when quantity exceeds available stock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5),
          quantity: 10,
        );
        expect(cartItem.exceedsStock, true);
      });

      test('returns false when quantity equals stock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5),
          quantity: 5,
        );
        expect(cartItem.exceedsStock, false);
      });

      test('returns false when quantity is below stock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 10),
          quantity: 5,
        );
        expect(cartItem.exceedsStock, false);
      });

      test('returns true when stock is zero and quantity is positive', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 0),
          quantity: 1,
        );
        expect(cartItem.exceedsStock, true);
      });
    });

    group('wouldCauseLowStock', () {
      test('returns true when stock after sale is at minStock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 10, minStock: 5),
          quantity: 5,
        );
        // 10 - 5 = 5, which equals minStock
        expect(cartItem.wouldCauseLowStock, true);
      });

      test('returns true when stock after sale is below minStock but above 0',
          () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 8, minStock: 5),
          quantity: 5,
        );
        // 8 - 5 = 3, which is below minStock (5) but above 0
        expect(cartItem.wouldCauseLowStock, true);
      });

      test('returns false when stock after sale is above minStock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 20, minStock: 5),
          quantity: 5,
        );
        // 20 - 5 = 15, which is above minStock
        expect(cartItem.wouldCauseLowStock, false);
      });

      test('returns false when sale would cause out of stock', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5, minStock: 5),
          quantity: 5,
        );
        // 5 - 5 = 0, which is out of stock, not low stock
        expect(cartItem.wouldCauseLowStock, false);
      });

      test('returns false when sale exceeds stock completely', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5, minStock: 5),
          quantity: 10,
        );
        // 5 - 10 = -5, which is negative (out of stock)
        expect(cartItem.wouldCauseLowStock, false);
      });
    });

    group('wouldCauseOutOfStock', () {
      test('returns true when stock after sale is zero', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5),
          quantity: 5,
        );
        expect(cartItem.wouldCauseOutOfStock, true);
      });

      test('returns true when stock after sale is negative', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 5),
          quantity: 10,
        );
        expect(cartItem.wouldCauseOutOfStock, true);
      });

      test('returns false when stock after sale is positive', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(stock: 10),
          quantity: 5,
        );
        expect(cartItem.wouldCauseOutOfStock, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated quantity', () {
        final original = MockData.createCartItem(quantity: 2);
        final updated = original.copyWith(quantity: 5);

        expect(updated.quantity, 5);
        expect(updated.product, original.product);
      });

      test('creates copy with updated product', () {
        final original = MockData.createCartItem(
          product: MockData.createProduct(name: 'Original'),
          quantity: 2,
        );
        final newProduct = MockData.createProduct(name: 'Updated');
        final updated = original.copyWith(product: newProduct);

        expect(updated.product.name, 'Updated');
        expect(updated.quantity, original.quantity);
      });

      test('preserves values when not updated', () {
        final original = MockData.createCartItem(quantity: 3);
        final updated = original.copyWith();

        expect(updated.quantity, original.quantity);
        expect(updated.product.id, original.product.id);
      });

      test('creates new instance (immutable)', () {
        final original = MockData.createCartItem(quantity: 2);
        final updated = original.copyWith(quantity: 5);

        expect(identical(original, updated), false);
        expect(original.quantity, 2);
      });
    });

    group('equality', () {
      test('cart items with same product id and quantity are equal', () {
        final item1 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-1'),
          quantity: 2,
        );
        final item2 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-1'),
          quantity: 2,
        );
        expect(item1, equals(item2));
      });

      test('cart items with different product id are not equal', () {
        final item1 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-1'),
          quantity: 2,
        );
        final item2 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-2'),
          quantity: 2,
        );
        expect(item1, isNot(equals(item2)));
      });

      test('cart items with different quantity are not equal', () {
        final item1 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-1'),
          quantity: 2,
        );
        final item2 = MockData.createCartItem(
          product: MockData.createProduct(id: 'prod-1'),
          quantity: 3,
        );
        expect(item1, isNot(equals(item2)));
      });
    });

    group('toString', () {
      test('returns meaningful string representation', () {
        final cartItem = MockData.createCartItem(
          product: MockData.createProduct(
            name: 'Test Product',
            sellingPrice: 15000,
          ),
          quantity: 2,
        );
        final str = cartItem.toString();

        expect(str, contains('Test Product'));
        expect(str, contains('2'));
        expect(str, contains('30000'));
      });
    });
  });
}
