import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/category/domain/models/category.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/stock/domain/models/stock_in.dart';
import 'package:frontend/features/payment_method/domain/models/payment_method.dart';
import 'package:frontend/features/tax/domain/models/tax_setting.dart';
import 'package:frontend/features/pos/domain/models/transaction.dart';

void main() {
  group('Models Serialization Tests', () {
    test('Category serialization and deserialization', () {
      final now = DateTime.now();
      final category = Category(
        id: 'cat-123',
        nama: 'Makanan',
        status: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = category.toMap();
      expect(map['id'], 'cat-123');
      expect(map['nama'], 'Makanan');
      expect(map['status'], 1);

      final decoded = Category.fromMap(map);
      expect(decoded.id, category.id);
      expect(decoded.nama, category.nama);
      expect(decoded.status, category.status);
    });

    test('Product serialization and deserialization', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-123',
        kategoriId: 'cat-123',
        nama: 'Kopi Susu',
        harga: 15000.0,
        stok: 10,
        status: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      expect(map['id'], 'prod-123');
      expect(map['kategori_id'], 'cat-123');
      expect(map['nama'], 'Kopi Susu');
      expect(map['harga'], 15000.0);
      expect(map['stok'], 10);

      final decoded = Product.fromMap(map, categoryName: 'Minuman');
      expect(decoded.id, product.id);
      expect(decoded.kategoriId, product.kategoriId);
      expect(decoded.kategoriNama, 'Minuman');
      expect(decoded.nama, product.nama);
      expect(decoded.harga, product.harga);
      expect(decoded.stok, product.stok);
    });

    test('StockIn serialization and deserialization', () {
      final now = DateTime.now();
      final stockIn = StockIn(
        id: 'stock-123',
        produkId: 'prod-123',
        qty: 5,
        tanggal: '2026-07-07',
        catatan: 'Restock kopi',
        createdAt: now,
      );

      final map = stockIn.toMap();
      expect(map['id'], 'stock-123');
      expect(map['produk_id'], 'prod-123');
      expect(map['qty'], 5);
      expect(map['tanggal'], '2026-07-07');
      expect(map['catatan'], 'Restock kopi');

      final decoded = StockIn.fromMap(map, productName: 'Kopi Susu');
      expect(decoded.id, stockIn.id);
      expect(decoded.produkId, stockIn.produkId);
      expect(decoded.produkNama, 'Kopi Susu');
      expect(decoded.qty, stockIn.qty);
      expect(decoded.tanggal, stockIn.tanggal);
    });

    test('PaymentMethod serialization and deserialization', () {
      final now = DateTime.now();
      final pm = PaymentMethod(
        id: 'pm-qris',
        nama: 'QRIS',
        icon: 'qr_code',
        aktif: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = pm.toMap();
      expect(map['id'], 'pm-qris');
      expect(map['nama'], 'QRIS');
      expect(map['icon'], 'qr_code');
      expect(map['aktif'], 1);

      final decoded = PaymentMethod.fromMap(map);
      expect(decoded.id, pm.id);
      expect(decoded.nama, pm.nama);
      expect(decoded.icon, pm.icon);
      expect(decoded.aktif, pm.aktif);
    });

    test('TaxSetting serialization and deserialization', () {
      final now = DateTime.now();
      final tax = TaxSetting(
        id: 1,
        enable: 1,
        percentage: 11.0,
        updatedAt: now,
      );

      final map = tax.toMap();
      expect(map['id'], 1);
      expect(map['enable'], 1);
      expect(map['percentage'], 11.0);

      final decoded = TaxSetting.fromMap(map);
      expect(decoded.id, tax.id);
      expect(decoded.enable, tax.enable);
      expect(decoded.percentage, tax.percentage);
    });

    test('TransactionHeader serialization and deserialization', () {
      final now = DateTime.now();
      final tx = TransactionHeader(
        id: 'tx-123',
        nomorTransaksi: 'TRX-20260707-0001',
        subtotal: 30000.0,
        taxPercentage: 11.0,
        taxAmount: 3300.0,
        grandTotal: 33300.0,
        paymentMethodId: 'pm-tunai',
        paymentMethodNama: 'Tunai',
        nominalBayar: 50000.0,
        kembalian: 16700.0,
        catatan: 'Pembayaran warung',
        createdAt: now,
      );

      final map = tx.toMap();
      expect(map['id'], 'tx-123');
      expect(map['nomor_transaksi'], 'TRX-20260707-0001');
      expect(map['subtotal'], 30000.0);
      expect(map['tax_percentage'], 11.0);
      expect(map['tax_amount'], 3300.0);
      expect(map['grand_total'], 33300.0);
      expect(map['payment_method_id'], 'pm-tunai');
      expect(map['payment_method_nama'], 'Tunai');
      expect(map['nominal_bayar'], 50000.0);
      expect(map['kembalian'], 16700.0);
      expect(map['catatan'], 'Pembayaran warung');

      final decoded = TransactionHeader.fromMap(map);
      expect(decoded.id, tx.id);
      expect(decoded.nomorTransaksi, tx.nomorTransaksi);
      expect(decoded.subtotal, tx.subtotal);
      expect(decoded.grandTotal, tx.grandTotal);
    });
  });
}
