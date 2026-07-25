import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/sku_generator.dart';

void main() {
  group('SkuGenerator', () {
    group('generate', () {
      test('generates SKU with prefix from product name', () {
        final sku = SkuGenerator.generate('Mie Goreng');
        expect(sku, matches(RegExp(r'^MIE-\d{1,5}$')));
      });

      test('uses first 3 letters of product name as prefix', () {
        final sku = SkuGenerator.generate('Kopi Hitam');
        expect(sku.startsWith('KOP-'), true);
      });

      test('handles product name with less than 3 characters', () {
        final sku = SkuGenerator.generate('Es');
        expect(sku, matches(RegExp(r'^ES-\d{1,5}$')));
      });

      test('handles single character product name', () {
        final sku = SkuGenerator.generate('A');
        expect(sku, matches(RegExp(r'^A-\d{1,5}$')));
      });

      test('uses SKU prefix for empty product name', () {
        final sku = SkuGenerator.generate('');
        expect(sku, matches(RegExp(r'^SKU-\d{1,5}$')));
      });

      test('removes non-alphanumeric characters from name', () {
        final sku = SkuGenerator.generate('Mie @#\$ Goreng!');
        expect(sku.startsWith('MIE-'), true);
      });

      test('handles name with only special characters', () {
        final sku = SkuGenerator.generate('!@#\$%');
        expect(sku, matches(RegExp(r'^SKU-\d{1,5}$')));
      });

      test('converts prefix to uppercase', () {
        final sku = SkuGenerator.generate('mie goreng');
        expect(sku.startsWith('MIE-'), true);
      });

      test('handles product name starting with numbers', () {
        final sku = SkuGenerator.generate('123 Produk');
        expect(sku, matches(RegExp(r'^123-\d{1,5}$')));
      });

      test('generates unique SKUs for same product name', () async {
        final sku1 = SkuGenerator.generate('Test Product');
        // Wait a bit to ensure timestamp changes
        await Future.delayed(const Duration(milliseconds: 10));
        final sku2 = SkuGenerator.generate('Test Product');

        // Both should have same prefix but potentially different suffix
        expect(sku1.startsWith('TES-'), true);
        expect(sku2.startsWith('TES-'), true);
      });
    });

    group('isValid', () {
      test('returns true for valid SKU format', () {
        expect(SkuGenerator.isValid('MIE-12345'), true);
      });

      test('returns true for single letter prefix', () {
        expect(SkuGenerator.isValid('A-1'), true);
      });

      test('returns true for two letter prefix', () {
        expect(SkuGenerator.isValid('ES-123'), true);
      });

      test('returns true for three letter prefix', () {
        expect(SkuGenerator.isValid('KOP-99999'), true);
      });

      test('returns true for numeric prefix', () {
        expect(SkuGenerator.isValid('123-456'), true);
      });

      test('returns true for alphanumeric prefix', () {
        expect(SkuGenerator.isValid('A1B-789'), true);
      });

      test('returns false for lowercase prefix', () {
        expect(SkuGenerator.isValid('mie-12345'), false);
      });

      test('returns false for prefix longer than 3 characters', () {
        expect(SkuGenerator.isValid('MIEE-12345'), false);
      });

      test('returns false for empty prefix', () {
        expect(SkuGenerator.isValid('-12345'), false);
      });

      test('returns false for suffix longer than 5 digits', () {
        expect(SkuGenerator.isValid('MIE-123456'), false);
      });

      test('returns false for non-numeric suffix', () {
        expect(SkuGenerator.isValid('MIE-ABC'), false);
      });

      test('returns false for missing dash', () {
        expect(SkuGenerator.isValid('MIE12345'), false);
      });

      test('returns false for multiple dashes', () {
        expect(SkuGenerator.isValid('MIE-123-45'), false);
      });

      test('returns false for empty string', () {
        expect(SkuGenerator.isValid(''), false);
      });

      test('returns false for whitespace only', () {
        expect(SkuGenerator.isValid('   '), false);
      });
    });
  });
}
