import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/pos/application/cart_notifier.dart';
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
      final added = cart.addItem(sampleProduct1);
      expect(added, true);

      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.qty, 2);
      expect(state.subtotal, 30000.0);
    });

    test('Add item exceeding stock fails', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      // Stock limit is 2 for sampleProduct2
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
      
      cart.removeItem(sampleProduct1.id);
      
      final state = container.read(cartNotifierProvider);
      expect(state.items.length, 1);
      expect(state.items.first.product.id, 'prod-2');
      expect(state.subtotal, 20000.0);
    });
  });
}

// Simple Mock for Tax Notifier to run simple unit calculations tests
class TaxNotifierMock extends TaxNotifier {
  TaxNotifierMock() : super(TaxRepositoryFake()) {
    state = TaxState(
      taxSetting: TaxSetting(percentage: 11.0, updatedAt: DateTime.now(), enable: 0),
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
