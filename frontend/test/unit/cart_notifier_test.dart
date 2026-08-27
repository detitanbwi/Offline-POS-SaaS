import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/pos/application/cart_notifier.dart';
import 'package:frontend/features/pos/application/order_notifier.dart';
import 'package:frontend/features/tax/application/tax_notifier.dart';
import 'package:frontend/features/tax/domain/models/tax_setting.dart';
import 'package:frontend/features/tax/domain/repositories/tax_repository.dart';

void main() {
  group('CartNotifier Calculations Tests', () {
    late ProviderContainer container;
    late Product sampleProduct1;
    late Product sampleProduct2;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Override tax notifier with static disabled state initially
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock()),
        ],
      );

      final now = DateTime.now();
      sampleProduct1 = Product(
        id: 'prod-1',
        kategoriId: 'cat-1',
        nama: 'Kopi Susu',
        harga: 15000.0,
        stok: 5,
        createdAt: now,
        updatedAt: now,
      );

      sampleProduct2 = Product(
        id: 'prod-2',
        kategoriId: 'cat-1',
        nama: 'Nasi Goreng',
        harga: 20000.0,
        stok: 2,
        createdAt: now,
        updatedAt: now,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Add item to cart increases count and calculates subtotal', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      final added = cart.addItem(sampleProduct1);
      expect(added, true);

      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.product.id, 'prod-1');
      expect(state.items.first.qty, 1);
      expect(state.subtotal, 15000.0);
      expect(state.grandTotal, 15000.0);
    });

    test('Add same item increments quantity and subtotal', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      cart.addItem(sampleProduct1);
      cart.addItem(sampleProduct1);

      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.qty, 2);
      expect(state.subtotal, 30000.0);
      expect(state.grandTotal, 30000.0);
    });

    test('Add item exceeding stock fails', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      expect(cart.addItem(sampleProduct2), true);
      expect(cart.addItem(sampleProduct2), true);
      expect(cart.addItem(sampleProduct2), false); // Exceeds stock

      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.qty, 2);
      expect(state.errorMessage, contains('tidak mencukupi'));
    });

    test('Update quantity and calculate updates', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      cart.addItem(sampleProduct1);
      final success = cart.updateQuantity(sampleProduct1.id, 4);
      expect(success, true);

      var state = container.read(cartNotifierProvider);
      expect(state.items.first.qty, 4);
      expect(state.subtotal, 60000.0);

      // Exceeds stock
      final fail = cart.updateQuantity(sampleProduct1.id, 6);
      expect(fail, false);
      
      state = container.read(cartNotifierProvider);
      expect(state.items.first.qty, 4); // unchanged
    });

    test('Remove item from cart resets totals', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      cart.addItem(sampleProduct1);
      cart.addItem(sampleProduct2);
      
      expect(container.read(cartNotifierProvider).items.length, 2);
      expect(container.read(cartNotifierProvider).subtotal, 35000.0);

      cart.removeItem(sampleProduct1.id);
      
      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.product.id, 'prod-2');
      expect(state.subtotal, 20000.0);
    });

    test('Calculate Service Charge Before Tax (Standard Mode)', () {
      final customContainer = ProviderContainer(
        overrides: [
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock(
            setting: TaxSetting(
              id: 1,
              enable: 1,
              percentage: 10.0, // 10% tax
              serviceChargeEnable: 1,
              serviceChargePercentage: 5.0, // 5% service
              serviceChargeAfterTax: 0, // before tax
              updatedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final cart = customContainer.read(cartNotifierProvider.notifier);
      // Add item Rp 100.000 (5x sampleProduct2 @ 20.000)
      cart.addItem(Product(
        id: 'prod-100k',
        kategoriId: 'cat-1',
        nama: 'Paket Makan',
        harga: 100000.0,
        stok: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final state = customContainer.read(cartNotifierProvider);
      expect(state.subtotal, 100000.0);
      // Service 5% of 100.000 = 5.000
      expect(state.serviceChargeAmount, 5000.0);
      // Tax 10% of (100.000 + 5.000) = 10.500
      expect(state.taxAmount, 10500.0);
      // Grand Total = 100.000 + 5.000 + 10.500 = 115.500
      expect(state.grandTotal, 115500.0);

      customContainer.dispose();
    });

    test('Calculate Service Charge After Tax (Compound Mode)', () {
      final customContainer = ProviderContainer(
        overrides: [
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock(
            setting: TaxSetting(
              id: 1,
              enable: 1,
              percentage: 10.0, // 10% tax
              serviceChargeEnable: 1,
              serviceChargePercentage: 5.0, // 5% service
              serviceChargeAfterTax: 1, // after tax
              updatedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final cart = customContainer.read(cartNotifierProvider.notifier);
      // Add item Rp 100.000
      cart.addItem(Product(
        id: 'prod-100k',
        kategoriId: 'cat-1',
        nama: 'Paket Makan',
        harga: 100000.0,
        stok: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final state = customContainer.read(cartNotifierProvider);
      expect(state.subtotal, 100000.0);
      // Tax 10% of 100.000 = 10.000
      expect(state.taxAmount, 10000.0);
      // Service 5% of (100.000 + 10.000) = 5.500
      expect(state.serviceChargeAmount, 5500.0);
      // Grand Total = 100.000 + 10.000 + 5.500 = 115.500
      expect(state.grandTotal, 115500.0);

      customContainer.dispose();
    });

    test('Calculate Service Charge and Tax with Decimal Ceil Rounding Up', () {
      final customContainer = ProviderContainer(
        overrides: [
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock(
            setting: TaxSetting(
              id: 1,
              enable: 1,
              percentage: 11.0, // 11% tax
              serviceChargeEnable: 1,
              serviceChargePercentage: 5.0, // 5% service
              serviceChargeAfterTax: 0, // before tax
              updatedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final cart = customContainer.read(cartNotifierProvider.notifier);
      // Add item Rp 19.000
      cart.addItem(Product(
        id: 'prod-19k',
        kategoriId: 'cat-1',
        nama: 'Es Teh & Krupuk',
        harga: 19000.0,
        stok: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final state = customContainer.read(cartNotifierProvider);
      expect(state.subtotal, 19000.0);
      // Service 5% of 19.000 = 950
      expect(state.serviceChargeAmount, 950.0);
      // Tax 11% of (19.000 + 950 = 19.950) is 2194.5 -> ceil to 2195.0
      expect(state.taxAmount, 2195.0);
      // Grand Total = 19.000 + 950 + 2.195 = 22.145
      expect(state.grandTotal, 22145.0);

      customContainer.dispose();
    });

    test('Take Away and Online Food excludes Service Charge when toggle is enabled', () {
      final customContainer = ProviderContainer(
        overrides: [
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock(
            setting: TaxSetting(
              id: 1,
              enable: 1,
              percentage: 10.0, // 10% tax
              serviceChargeEnable: 1,
              serviceChargePercentage: 5.0, // 5% service
              serviceChargeAfterTax: 0,
              serviceChargeExcludeOnline: 1, // Exclude for online / take away
              updatedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final orderNotifier = customContainer.read(orderNotifierProvider.notifier);
      final cart = customContainer.read(cartNotifierProvider.notifier);

      // Set to take away
      orderNotifier.setOrderType('take_away', subType: 'online_food', platform: 'GrabFood');

      cart.addItem(Product(
        id: 'prod-online',
        kategoriId: 'cat-1',
        nama: 'Menu Online',
        harga: 50000.0,
        stok: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final state = customContainer.read(cartNotifierProvider);
      expect(state.subtotal, 50000.0);
      // Service charge must be 0% and Rp 0 because order is take away / online food
      expect(state.serviceChargeRate, 0.0);
      expect(state.serviceChargeAmount, 0.0);
      // Tax is 10% of 50.000 = 5.000
      expect(state.taxAmount, 5000.0);
      // Grand Total = 50.000 + 5.000 = 55.000
      expect(state.grandTotal, 55000.0);

      customContainer.dispose();
    });

    test('addManualItem adds custom non-stock item and calculates subtotal correctly', () {
      final cart = container.read(cartNotifierProvider.notifier);

      final success = cart.addManualItem(
        nama: 'Ongkos Kirim Khusus',
        harga: 15000.0,
        qty: 2,
        catatan: 'Area Barat',
      );

      expect(success, true);

      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      final item = state.items.first;
      expect(item.product.nama, 'Ongkos Kirim Khusus');
      expect(item.product.harga, 15000.0);
      expect(item.qty, 2);
      expect(item.subtotal, 30000.0);
      expect(item.catatan, 'Area Barat');
      expect(item.isManual, true);
      expect(item.product.stok, -1); // Non-stock item
      expect(state.subtotal, 30000.0);
    });

    test('addManualItem validates empty name, negative price, and zero qty', () {
      final cart = container.read(cartNotifierProvider.notifier);

      // Empty name
      expect(cart.addManualItem(nama: '', harga: 10000.0, qty: 1), false);
      expect(container.read(cartNotifierProvider).errorMessage, contains('tidak boleh kosong'));

      // Negative price
      expect(cart.addManualItem(nama: 'Test', harga: -5000.0, qty: 1), false);
      expect(container.read(cartNotifierProvider).errorMessage, contains('tidak boleh negatif'));

      // Zero qty
      expect(cart.addManualItem(nama: 'Test', harga: 5000.0, qty: 0), false);
      expect(container.read(cartNotifierProvider).errorMessage, contains('minimal 1'));
    });

    test('setItemDiscount applies percentage and nominal discounts correctly', () {
      final cart = container.read(cartNotifierProvider.notifier);
      cart.addItem(sampleProduct1); // 1x 15.000

      // 10% discount on 15.000 -> 1.500 -> subtotal = 13.500
      cart.setItemDiscount(sampleProduct1.id, discountType: 'percent', discountValue: 10.0);
      var state = container.read(cartNotifierProvider);
      expect(state.items.first.discountPercentage, 10.0);
      expect(state.items.first.discountAmount, 1500.0);
      expect(state.items.first.subtotal, 13500.0);
      expect(state.subtotal, 13500.0);
      expect(state.itemDiscountTotal, 1500.0);

      // Nominal discount 5.000 -> subtotal = 10.000
      cart.setItemDiscount(sampleProduct1.id, discountType: 'nominal', discountValue: 5000.0);
      state = container.read(cartNotifierProvider);
      expect(state.items.first.discountAmount, 5000.0);
      expect(state.items.first.subtotal, 10000.0);
      expect(state.subtotal, 10000.0);

      // Reset discount (value = 0 or empty)
      cart.setItemDiscount(sampleProduct1.id, discountType: 'percent', discountValue: 0.0);
      state = container.read(cartNotifierProvider);
      expect(state.items.first.discountAmount, 0.0);
      expect(state.items.first.subtotal, 15000.0);
      expect(state.subtotal, 15000.0);
    });

    test('setOrderDiscount applies bill-level discount and recalculates grand total', () {
      final cart = container.read(cartNotifierProvider.notifier);
      cart.addItem(sampleProduct1); // 15.000
      cart.addItem(sampleProduct2); // 20.000 -> items subtotal = 35.000

      // 20% bill discount on 35.000 -> 7.000 -> netSubtotal = 28.000
      cart.setOrderDiscount(discountType: 'percent', discountValue: 20.0);
      var state = container.read(cartNotifierProvider);
      expect(state.orderDiscountRate, 20.0);
      expect(state.orderDiscountAmount, 7000.0);
      expect(state.netSubtotal, 28000.0);
      expect(state.grandTotal, 28000.0);

      // Nominal bill discount 10.000 -> netSubtotal = 25.000
      cart.setOrderDiscount(discountType: 'nominal', discountValue: 10000.0);
      state = container.read(cartNotifierProvider);
      expect(state.orderDiscountAmount, 10000.0);
      expect(state.netSubtotal, 25000.0);
      expect(state.grandTotal, 25000.0);

      // Clear bill discount
      cart.clearOrderDiscount();
      state = container.read(cartNotifierProvider);
      expect(state.orderDiscountAmount, 0.0);
      expect(state.netSubtotal, 35000.0);
      expect(state.grandTotal, 35000.0);
    });

    test('Discounts correctly reduce base for Tax and Service Charge calculations', () {
      final customContainer = ProviderContainer(
        overrides: [
          taxNotifierProvider.overrideWith((ref) => TaxNotifierMock(
            setting: TaxSetting(
              id: 1,
              enable: 1,
              percentage: 10.0, // 10% tax
              serviceChargeEnable: 1,
              serviceChargePercentage: 5.0, // 5% service
              serviceChargeAfterTax: 0, // before tax
              updatedAt: DateTime.now(),
            ),
          )),
        ],
      );

      final cart = customContainer.read(cartNotifierProvider.notifier);
      cart.addItem(Product(
        id: 'prod-100k',
        kategoriId: 'cat-1',
        nama: 'Paket Makan',
        harga: 100000.0,
        stok: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 20% order discount -> netSubtotal = 80.000
      cart.setOrderDiscount(discountType: 'percent', discountValue: 20.0);
      final state = customContainer.read(cartNotifierProvider);

      expect(state.subtotal, 100000.0);
      expect(state.orderDiscountAmount, 20000.0);
      expect(state.netSubtotal, 80000.0);
      // Service 5% of 80.000 = 4.000
      expect(state.serviceChargeAmount, 4000.0);
      // Tax 10% of (80.000 + 4.000) = 8.400
      expect(state.taxAmount, 8400.0);
      // Grand Total = 80.000 + 4.000 + 8.400 = 92.400
      expect(state.grandTotal, 92400.0);
    });
  });
}

// Simple Mock for Tax Notifier to run simple unit calculations tests
class TaxNotifierMock extends TaxNotifier {
  TaxNotifierMock({TaxSetting? setting}) : super(TaxRepositoryFake()) {
    state = TaxState(
      taxSetting: setting ?? TaxSetting(percentage: 11.0, updatedAt: DateTime.now(), enable: 0),
      isLoading: false,
    );
  }
}

class TaxRepositoryFake implements TaxRepository {
  @override
  Future<TaxSetting> getTaxSetting() async {
    return TaxSetting(percentage: 11.0, updatedAt: DateTime.now(), enable: 0);
  }

  @override
  Future<void> updateTaxSetting(TaxSetting taxSetting) async {}
}
