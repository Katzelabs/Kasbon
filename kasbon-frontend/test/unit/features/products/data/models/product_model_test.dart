import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/products/data/models/product_model.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';

import '../../../../../fixtures/mock_data.dart';

void main() {
  group('ProductModel', () {
    late DateTime fixedDate;
    late Map<String, dynamic> validJson;

    setUp(() {
      fixedDate = DateTime(2026, 1, 26, 14, 30);
      validJson = {
        'id': 'prod-1',
        'category_id': 'cat-1',
        'sku': 'SKU-12345',
        'name': 'Test Product',
        'description': 'Test description',
        'barcode': '1234567890123',
        'cost_price': 10000.0,
        'selling_price': 15000.0,
        'stock': 100,
        'min_stock': 5,
        'unit': 'pcs',
        'image_url': 'https://example.com/image.jpg',
        'is_active': true,
        'created_at': fixedDate.toIso8601String(),
        'updated_at': fixedDate.toIso8601String(),
      };
    });

    group('fromJson', () {
      test('creates model from valid JSON', () {
        final model = ProductModel.fromJson(validJson);

        expect(model.id, 'prod-1');
        expect(model.categoryId, 'cat-1');
        expect(model.sku, 'SKU-12345');
        expect(model.name, 'Test Product');
        expect(model.description, 'Test description');
        expect(model.barcode, '1234567890123');
        expect(model.costPrice, 10000.0);
        expect(model.sellingPrice, 15000.0);
        expect(model.stock, 100);
        expect(model.minStock, 5);
        expect(model.unit, 'pcs');
        expect(model.imageUrl, 'https://example.com/image.jpg');
        expect(model.isActive, true);
        expect(model.createdAt, fixedDate);
        expect(model.updatedAt, fixedDate);
      });

      test('handles null optional fields', () {
        final jsonWithNulls = {
          ...validJson,
          'category_id': null,
          'description': null,
          'barcode': null,
          'image_url': null,
        };

        final model = ProductModel.fromJson(jsonWithNulls);

        expect(model.categoryId, null);
        expect(model.description, null);
        expect(model.barcode, null);
        expect(model.imageUrl, null);
      });

      test('handles isActive as false', () {
        final jsonInactive = {
          ...validJson,
          'is_active': false,
        };

        final model = ProductModel.fromJson(jsonInactive);
        expect(model.isActive, false);
      });

      test('converts integer price to double', () {
        final jsonIntPrices = {
          ...validJson,
          'cost_price': 10000,
          'selling_price': 15000,
        };

        final model = ProductModel.fromJson(jsonIntPrices);
        expect(model.costPrice, 10000.0);
        expect(model.sellingPrice, 15000.0);
      });

      test('uses defaults for missing optional fields', () {
        final minimalJson = {
          'id': 'prod-1',
          'sku': 'SKU-12345',
          'name': 'Test Product',
          'cost_price': 10000.0,
          'selling_price': 15000.0,
          'stock': 100,
          'created_at': fixedDate.toIso8601String(),
          'updated_at': fixedDate.toIso8601String(),
        };

        final model = ProductModel.fromJson(minimalJson);
        expect(model.minStock, 5); // default
        expect(model.unit, 'pcs'); // default
        expect(model.isActive, true); // default
      });
    });

    group('toJson', () {
      test('converts model to JSON with correct keys', () {
        final model = ProductModel(
          id: 'prod-1',
          categoryId: 'cat-1',
          sku: 'SKU-12345',
          name: 'Test Product',
          description: 'Test description',
          barcode: '1234567890123',
          costPrice: 10000.0,
          sellingPrice: 15000.0,
          stock: 100,
          minStock: 5,
          unit: 'pcs',
          imageUrl: 'https://example.com/image.jpg',
          isActive: true,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final json = model.toJson();

        expect(json['id'], 'prod-1');
        expect(json['category_id'], 'cat-1');
        expect(json['sku'], 'SKU-12345');
        expect(json['name'], 'Test Product');
        expect(json['description'], 'Test description');
        expect(json['barcode'], '1234567890123');
        expect(json['cost_price'], 10000.0);
        expect(json['selling_price'], 15000.0);
        expect(json['stock'], 100);
        expect(json['min_stock'], 5);
        expect(json['unit'], 'pcs');
        expect(json['image_url'], 'https://example.com/image.jpg');
        expect(json['is_active'], true);
      });

      test('includes null values for optional fields', () {
        final model = ProductModel(
          id: 'prod-1',
          categoryId: null,
          sku: 'SKU-12345',
          name: 'Test Product',
          description: null,
          barcode: null,
          costPrice: 10000.0,
          sellingPrice: 15000.0,
          stock: 100,
          minStock: 5,
          unit: 'pcs',
          imageUrl: null,
          isActive: true,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final json = model.toJson();
        expect(json.containsKey('category_id'), true);
        expect(json['category_id'], null);
        expect(json['description'], null);
        expect(json['barcode'], null);
        expect(json['image_url'], null);
      });
    });

    group('toEntity', () {
      test('converts model to Product entity', () {
        final model = ProductModel.fromJson(validJson);
        final entity = model.toEntity();

        expect(entity, isA<Product>());
        expect(entity.id, model.id);
        expect(entity.categoryId, model.categoryId);
        expect(entity.sku, model.sku);
        expect(entity.name, model.name);
        expect(entity.description, model.description);
        expect(entity.barcode, model.barcode);
        expect(entity.costPrice, model.costPrice);
        expect(entity.sellingPrice, model.sellingPrice);
        expect(entity.stock, model.stock);
        expect(entity.minStock, model.minStock);
        expect(entity.unit, model.unit);
        expect(entity.imageUrl, model.imageUrl);
        expect(entity.isActive, model.isActive);
        expect(entity.createdAt, model.createdAt);
        expect(entity.updatedAt, model.updatedAt);
      });

      test('preserves all values in conversion', () {
        final model = ProductModel(
          id: 'prod-special',
          categoryId: 'cat-special',
          sku: 'SKU-SPECIAL',
          name: 'Special Product',
          description: 'Special description',
          barcode: '9999999999999',
          costPrice: 25000.0,
          sellingPrice: 35000.0,
          stock: 50,
          minStock: 10,
          unit: 'kg',
          imageUrl: 'https://special.com/image.jpg',
          isActive: false,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final entity = model.toEntity();

        expect(entity.id, 'prod-special');
        expect(entity.unit, 'kg');
        expect(entity.isActive, false);
      });
    });

    group('fromEntity', () {
      test('creates model from Product entity', () {
        final entity = MockData.createProduct(
          id: 'prod-1',
          categoryId: 'cat-1',
          sku: 'SKU-12345',
          name: 'Test Product',
          description: 'Test description',
          barcode: '1234567890123',
          costPrice: 10000,
          sellingPrice: 15000,
          stock: 100,
          minStock: 5,
          unit: 'pcs',
          imageUrl: 'https://example.com/image.jpg',
          isActive: true,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final model = ProductModel.fromEntity(entity);

        expect(model.id, entity.id);
        expect(model.categoryId, entity.categoryId);
        expect(model.sku, entity.sku);
        expect(model.name, entity.name);
        expect(model.description, entity.description);
        expect(model.barcode, entity.barcode);
        expect(model.costPrice, entity.costPrice);
        expect(model.sellingPrice, entity.sellingPrice);
        expect(model.stock, entity.stock);
        expect(model.minStock, entity.minStock);
        expect(model.unit, entity.unit);
        expect(model.imageUrl, entity.imageUrl);
        expect(model.isActive, entity.isActive);
        expect(model.createdAt, entity.createdAt);
        expect(model.updatedAt, entity.updatedAt);
      });
    });

    group('round-trip conversion', () {
      test('entity -> model -> entity preserves all values', () {
        final originalEntity = MockData.createProduct(
          id: 'prod-roundtrip',
          categoryId: 'cat-roundtrip',
          sku: 'SKU-ROUNDTRIP',
          name: 'Roundtrip Product',
          description: 'Roundtrip description',
          barcode: '1111111111111',
          costPrice: 20000,
          sellingPrice: 30000,
          stock: 75,
          minStock: 8,
          unit: 'box',
          imageUrl: 'https://roundtrip.com/image.jpg',
          isActive: true,
          createdAt: fixedDate,
          updatedAt: fixedDate,
        );

        final model = ProductModel.fromEntity(originalEntity);
        final roundtripEntity = model.toEntity();

        expect(roundtripEntity.id, originalEntity.id);
        expect(roundtripEntity.categoryId, originalEntity.categoryId);
        expect(roundtripEntity.sku, originalEntity.sku);
        expect(roundtripEntity.name, originalEntity.name);
        expect(roundtripEntity.description, originalEntity.description);
        expect(roundtripEntity.barcode, originalEntity.barcode);
        expect(roundtripEntity.costPrice, originalEntity.costPrice);
        expect(roundtripEntity.sellingPrice, originalEntity.sellingPrice);
        expect(roundtripEntity.stock, originalEntity.stock);
        expect(roundtripEntity.minStock, originalEntity.minStock);
        expect(roundtripEntity.unit, originalEntity.unit);
        expect(roundtripEntity.imageUrl, originalEntity.imageUrl);
        expect(roundtripEntity.isActive, originalEntity.isActive);
        expect(roundtripEntity.createdAt, originalEntity.createdAt);
        expect(roundtripEntity.updatedAt, originalEntity.updatedAt);
      });

      test('json -> model -> json preserves all values', () {
        final originalJson = Map<String, dynamic>.from(validJson);

        final model = ProductModel.fromJson(originalJson);
        final roundtripJson = model.toJson();

        expect(roundtripJson['id'], originalJson['id']);
        expect(roundtripJson['category_id'], originalJson['category_id']);
        expect(roundtripJson['sku'], originalJson['sku']);
        expect(roundtripJson['name'], originalJson['name']);
        expect(roundtripJson['cost_price'], originalJson['cost_price']);
        expect(roundtripJson['selling_price'], originalJson['selling_price']);
        expect(roundtripJson['stock'], originalJson['stock']);
        expect(roundtripJson['is_active'], originalJson['is_active']);
      });
    });
  });
}
