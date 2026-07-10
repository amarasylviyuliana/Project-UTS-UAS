import 'package:flutter_test/flutter_test.dart';
import 'package:bumdes_frontend/src/models/product_model.dart';
import 'package:bumdes_frontend/src/providers/product_provider.dart';

void main() {
  group('ProductProvider category handling', () {
    test('normalizeCategoryName trims and collapses whitespace', () {
      expect(ProductProvider.normalizeCategoryName('  Pangan  '), 'Pangan');
      expect(
        ProductProvider.normalizeCategoryName('Kerajinan   Desa'),
        'Kerajinan Desa',
      );
      expect(ProductProvider.normalizeCategoryName(null), '');
    });

    test('buildCategoryNames deduplicates and preserves usable names', () {
      final products = [
        ProductModel(
          id: 1,
          name: 'Produk A',
          storeName: 'Toko A',
          location: 'Desa A',
          category: '  Pangan  ',
          price: 1000,
          stock: 10,
          description: '',
          imageUrl: '',
        ),
        ProductModel(
          id: 2,
          name: 'Produk B',
          storeName: 'Toko B',
          location: 'Desa B',
          category: 'Pangan',
          price: 2000,
          stock: 8,
          description: '',
          imageUrl: '',
        ),
        ProductModel(
          id: 3,
          name: 'Produk C',
          storeName: 'Toko C',
          location: 'Desa C',
          category: 'Kerajinan Desa',
          price: 3000,
          stock: 5,
          description: '',
          imageUrl: '',
        ),
      ];

      final categories = ProductProvider.buildCategoryNames(products, [
        '  Kuliner  ',
        'Pangan',
      ]);

      expect(categories, ['Semua', 'Kerajinan Desa', 'Kuliner', 'Pangan']);
    });
  });
}
