import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/pos/application/cart_notifier.dart';
import 'package:frontend/features/tax/application/tax_notifier.dart';
import 'package:frontend/features/tax/domain/models/tax_setting.dart';

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

    test('Add item multiple times respects product stock limit', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      // Stock limit is 2 for Nasi Goreng
      expect(cart.addItem(sampleProduct2), true);
      expect(cart.addItem(sampleProduct2), true);
      
      // Third time should be blocked since stock limit is reached
      expect(cart.addItem(sampleProduct2), false);

      final state = container.read(cartNotifierProvider);
      expect(state.items.first.qty, 2);
      expect(state.errorMessage != null, true);
    });

    test('Update quantity recalculates totals correctly', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      cart.addItem(sampleProduct1);
      final ok = cart.updateQuantity(sampleProduct1.id, 3);
      expect(ok, true);

      final state = container.read(cartNotifierProvider);
      expect(state.items.first.qty, 3);
      expect(state.subtotal, 45000.0);
      expect(state.grandTotal, 45000.0);
    });

    test('Update quantity beyond stock limits returns false', () {
      final cart = container.read(cartNotifierProvider.notifier);
      
      cart.addItem(sampleProduct2); // Stock = 2
      final ok = cart.updateQuantity(sampleProduct2.id, 5);
      expect(ok, false);

      final state = container.read(cartNotifierProvider);
      expect(state.items.first.qty, 1); // unchanged
    });

    test('Removing item from cart updates subtotal and items list', () {
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

class TaxRepositoryFake implements dynamic {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
