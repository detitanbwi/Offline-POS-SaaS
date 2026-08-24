import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/product/domain/models/package_item.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  group('Package Bundling & MultiStock Tests', () {
    test('PackageItem serialization toMap and fromMap', () {
      final item = PackageItem(
        id: 'pkg-item-1',
        packageId: 'pkg-1',
        productId: 'prod-1',
        qty: 2,
        createdAt: now,
        updatedAt: now,
        productNama: 'Nasi Goreng',
        productHarga: 15000,
        productStok: 10,
      );

      final map = item.toMap();
      expect(map['id'], 'pkg-item-1');
      expect(map['package_id'], 'pkg-1');
      expect(map['product_id'], 'prod-1');
      expect(map['qty'], 2);

      final fromMap = PackageItem.fromMap({
        ...map,
        'product_nama': 'Nasi Goreng',
        'product_harga': 15000,
        'product_stok': 10,
      });

      expect(fromMap.id, 'pkg-item-1');
      expect(fromMap.packageId, 'pkg-1');
      expect(fromMap.productId, 'prod-1');
      expect(fromMap.qty, 2);
      expect(fromMap.productNama, 'Nasi Goreng');
      expect(fromMap.productHarga, 15000);
      expect(fromMap.productStok, 10);
    });

    test('Effective stock computation with unlimited (stok == -1) components', () {
      final comp1 = Product(id: 'p1', nama: 'Es Teh', kategoriId: 'c1', harga: 5000, stok: -1, createdAt: now, updatedAt: now);
      final comp2 = Product(id: 'p2', nama: 'Es Jeruk', kategoriId: 'c1', harga: 6000, stok: -1, createdAt: now, updatedAt: now);

      final package = Product(
        id: 'pkg-all-unlimited',
        nama: 'Paket Minuman Bebas',
        kategoriId: 'c1',
        harga: 10000,
        stok: 0,
        createdAt: now,
        updatedAt: now,
        isPackage: true,
        packageItems: [
          PackageItem(id: 'pi1', packageId: 'pkg-all-unlimited', productId: 'p1', qty: 1, productStok: -1, createdAt: now, updatedAt: now),
          PackageItem(id: 'pi2', packageId: 'pkg-all-unlimited', productId: 'p2', qty: 1, productStok: -1, createdAt: now, updatedAt: now),
        ],
      );

      final effectiveStock = package.getEffectiveStock(allProducts: [comp1, comp2]);
      expect(effectiveStock, -1); // Unlimited
    });

    test('Effective stock computation with bottleneck component stock', () {
      final comp1 = Product(id: 'p1', nama: 'Nasi Goreng', kategoriId: 'c1', harga: 15000, stok: 10, createdAt: now, updatedAt: now); // 10 / 2 = 5 bundles
      final comp2 = Product(id: 'p2', nama: 'Ayam Goreng', kategoriId: 'c1', harga: 10000, stok: 3, createdAt: now, updatedAt: now); // 3 / 1 = 3 bundles (bottleneck!)
      final comp3 = Product(id: 'p3', nama: 'Sambal', kategoriId: 'c1', harga: 2000, stok: -1, createdAt: now, updatedAt: now); // unlimited

      final package = Product(
        id: 'pkg-combo',
        nama: 'Paket Kenyang',
        kategoriId: 'c1',
        harga: 25000,
        stok: 0,
        createdAt: now,
        updatedAt: now,
        isPackage: true,
        packageItems: [
          PackageItem(id: 'pi1', packageId: 'pkg-combo', productId: 'p1', qty: 2, productStok: 10, createdAt: now, updatedAt: now),
          PackageItem(id: 'pi2', packageId: 'pkg-combo', productId: 'p2', qty: 1, productStok: 3, createdAt: now, updatedAt: now),
          PackageItem(id: 'pi3', packageId: 'pkg-combo', productId: 'p3', qty: 1, productStok: -1, createdAt: now, updatedAt: now),
        ],
      );

      final effectiveStock = package.getEffectiveStock(allProducts: [comp1, comp2, comp3]);
      expect(effectiveStock, 3);
    });

    test('Effective stock is 0 when any component stock is 0 or less than component requirement', () {
      final comp1 = Product(id: 'p1', nama: 'Nasi Goreng', kategoriId: 'c1', harga: 15000, stok: 1, createdAt: now, updatedAt: now); // requires 2, but only 1 available!
      final comp2 = Product(id: 'p2', nama: 'Teh Botol', kategoriId: 'c1', harga: 5000, stok: 10, createdAt: now, updatedAt: now);

      final package = Product(
        id: 'pkg-empty',
        nama: 'Paket Hemat',
        kategoriId: 'c1',
        harga: 18000,
        stok: 0,
        createdAt: now,
        updatedAt: now,
        isPackage: true,
        packageItems: [
          PackageItem(id: 'pi1', packageId: 'pkg-empty', productId: 'p1', qty: 2, productStok: 1, createdAt: now, updatedAt: now),
          PackageItem(id: 'pi2', packageId: 'pkg-empty', productId: 'p2', qty: 1, productStok: 10, createdAt: now, updatedAt: now),
        ],
      );

      final effectiveStock = package.getEffectiveStock(allProducts: [comp1, comp2]);
      expect(effectiveStock, 0);
    });

    test('Effective stock is 0 when package has 0 components configured', () {
      final package = Product(
        id: 'pkg-no-comp',
        nama: 'Paket Kosong',
        kategoriId: 'c1',
        harga: 10000,
        stok: 0,
        createdAt: now,
        updatedAt: now,
        isPackage: true,
        packageItems: const [],
      );

      final effectiveStock = package.getEffectiveStock(allProducts: []);
      expect(effectiveStock, 0);
    });
  });
}
