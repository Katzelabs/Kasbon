import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/validators.dart';
import 'package:kasbon_pos/features/onboarding/domain/entities/business_type.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';

void main() {
  group('BusinessType', () {
    test('ids are stable storage, not display strings', () {
      // These reach `shop_settings.business_type`. Renaming one orphans every
      // row holding the old value, so the list is pinned here on purpose -
      // a failure means someone changed storage, not a label.
      expect(
        BusinessType.values.map((t) => t.id),
        [
          'warung_makan',
          'kedai_kopi',
          'toko_kelontong',
          'toko_pakaian',
          'jasa',
          'lainnya',
        ],
      );
    });

    test('ids are unique', () {
      final ids = BusinessType.values.map((t) => t.id).toSet();
      expect(ids.length, BusinessType.values.length);
    });

    test('every trade arrives with categories to sell under', () {
      // An empty starter list would put the user back in front of the blank
      // category screen this whole step exists to avoid.
      for (final type in BusinessType.values) {
        expect(
          type.starterCategories,
          isNotEmpty,
          reason: '${type.id} has no starter categories',
        );
        expect(
          type.starterCategories.toSet().length,
          type.starterCategories.length,
          reason: '${type.id} repeats a category',
        );
      }
    });

    test('fromId round-trips, and shrugs at anything else', () {
      for (final type in BusinessType.values) {
        expect(BusinessType.fromId(type.id), type);
      }
      // The column is free-form TEXT: a value written by a newer build must
      // not crash an older one.
      expect(BusinessType.fromId('laundry'), isNull);
      expect(BusinessType.fromId(null), isNull);
    });
  });

  group('Validators.otp', () {
    test('accepts exactly six digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp(' 123456 '), isNull);
    });

    test('rejects anything else', () {
      expect(Validators.otp(null), 'Kode OTP wajib diisi');
      expect(Validators.otp(''), 'Kode OTP wajib diisi');
      expect(Validators.otp('12345'), 'Kode OTP harus 6 digit angka');
      expect(Validators.otp('1234567'), 'Kode OTP harus 6 digit angka');
      expect(Validators.otp('12345a'), 'Kode OTP harus 6 digit angka');
    });
  });

  group('profit arithmetic has one definition', () {
    // The form shows a margin before a Product exists, so the numbers are also
    // reachable statically. The two paths must not drift.
    test('the static helpers and the entity getters agree', () {
      final product = Product(
        id: 'p1',
        sku: 'SKU-1',
        name: 'Es Teh',
        costPrice: 2000,
        sellingPrice: 5000,
        stock: 10,
        createdAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 31),
      );

      expect(Product.profitOf(2000, 5000), product.profit);
      expect(Product.profitMarginOf(2000, 5000), product.profitMargin);
      expect(product.profit, 3000);
      // Margin is over cost, not revenue: 3000/2000.
      expect(product.profitMargin, 150);
    });

    test('a zero cost price does not divide by zero', () {
      expect(Product.profitMarginOf(0, 5000), 0);
    });
  });
}
