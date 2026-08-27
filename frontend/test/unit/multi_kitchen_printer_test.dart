import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/printer/domain/models/printer_config.dart';
import 'package:frontend/features/pos/domain/models/order_item.dart';

void main() {
  group('Multi Kitchen Printer Tests', () {
    test('PrinterConfigModel correctly serializes and deserializes label, categoryIds, and openDrawer', () {
      final config = PrinterConfigModel(
        id: 'printer-kitchen-1',
        name: 'RPP02N',
        label: 'Dapur Makanan',
        address: '00:11:22:33:44:55',
        type: 'kitchen',
        paperSize: 80,
        charsPerLine: 48,
        autoCut: true,
        openDrawer: false,
        categoryIds: ['cat-makanan', 'cat-snack'],
        createdAt: DateTime(2026, 8, 27, 10, 0),
      );

      final map = config.toMap();
      expect(map['id'], 'printer-kitchen-1');
      expect(map['name'], 'RPP02N');
      expect(map['label'], 'Dapur Makanan');
      expect(map['category_ids'], '["cat-makanan","cat-snack"]');
      expect(map['paper_size'], 80);
      expect(map['chars_per_line'], 48);
      expect(map['auto_cut'], 1);

      final fromMap = PrinterConfigModel.fromMap(map);
      expect(fromMap.id, 'printer-kitchen-1');
      expect(fromMap.displayName, 'Dapur Makanan');
      expect(fromMap.isKitchen, isTrue);
      expect(fromMap.isCashier, isFalse);
      expect(fromMap.categoryIds, ['cat-makanan', 'cat-snack']);
      expect(fromMap.paperSize, 80);
      expect(fromMap.effectiveCharsPerLine, 48);
      expect(fromMap.autoCut, isTrue);
    });

    test('displayName returns label if present, otherwise returns device name', () {
      final withLabel = PrinterConfigModel(
        id: 'p1',
        name: 'MTP-II',
        label: 'Bar Minuman',
        address: '00:11:22:33:44:55',
        type: 'kitchen',
        createdAt: DateTime.now(),
      );
      expect(withLabel.displayName, 'Bar Minuman');

      final withoutLabel = PrinterConfigModel(
        id: 'p2',
        name: 'MTP-II',
        label: null,
        address: '00:11:22:33:44:55',
        type: 'kitchen',
        createdAt: DateTime.now(),
      );
      expect(withoutLabel.displayName, 'MTP-II');

      final emptyLabel = PrinterConfigModel(
        id: 'p3',
        name: 'MTP-II',
        label: '   ',
        address: '00:11:22:33:44:55',
        type: 'kitchen',
        createdAt: DateTime.now(),
      );
      expect(emptyLabel.displayName, 'MTP-II');
    });

    test('Category filtering routes order items to matching kitchen printers', () {
      final foodPrinter = PrinterConfigModel(
        id: 'p-food',
        name: 'Printer Dapur',
        label: 'Dapur Makanan',
        address: '00:11:22:33:44:55',
        type: 'kitchen',
        categoryIds: ['cat-makanan'],
        createdAt: DateTime.now(),
      );

      final beveragePrinter = PrinterConfigModel(
        id: 'p-bar',
        name: 'Printer Bar',
        label: 'Bar Minuman',
        address: '00:11:22:33:44:66',
        type: 'kitchen',
        categoryIds: ['cat-minuman'],
        createdAt: DateTime.now(),
      );

      final allPurposePrinter = PrinterConfigModel(
        id: 'p-all',
        name: 'Printer Semua',
        label: 'Dapur Utama',
        address: '00:11:22:33:44:77',
        type: 'kitchen',
        categoryIds: const [], // empty means all categories
        createdAt: DateTime.now(),
      );

      final productCategoryMap = {
        'prod-ayam': 'cat-makanan',
        'prod-nasi': 'cat-makanan',
        'prod-es-teh': 'cat-minuman',
        'prod-kopi': 'cat-minuman',
      };

      final orderItems = [
        const OrderItemModel(
          id: 'item-1',
          orderId: 'ord-1',
          produkId: 'prod-ayam',
          produkNama: 'Ayam Goreng',
          produkHarga: 20000,
          qty: 2,
          subtotal: 40000,
        ),
        const OrderItemModel(
          id: 'item-2',
          orderId: 'ord-1',
          produkId: 'prod-es-teh',
          produkNama: 'Es Teh Manis',
          produkHarga: 5000,
          qty: 2,
          subtotal: 10000,
        ),
        const OrderItemModel(
          id: 'item-3',
          orderId: 'ord-1',
          produkId: 'manual_custom_1',
          produkNama: 'Sambal Ekstra Custom',
          produkHarga: 3000,
          qty: 1,
          subtotal: 3000,
        ),
      ];

      List<OrderItemModel> filterItems(PrinterConfigModel printer) {
        if (printer.categoryIds.isEmpty) return orderItems;
        return orderItems.where((item) {
          if (item.isManual) return true;
          final catId = productCategoryMap[item.produkId];
          if (catId == null) return true;
          return printer.categoryIds.contains(catId);
        }).toList();
      }

      final foodItems = filterItems(foodPrinter);
      expect(foodItems.length, 2); // Ayam Goreng + Sambal Ekstra Custom (manual)
      expect(foodItems.any((i) => i.produkNama == 'Ayam Goreng'), isTrue);
      expect(foodItems.any((i) => i.produkNama == 'Es Teh Manis'), isFalse);

      final beverageItems = filterItems(beveragePrinter);
      expect(beverageItems.length, 2); // Es Teh Manis + Sambal Ekstra Custom (manual)
      expect(beverageItems.any((i) => i.produkNama == 'Es Teh Manis'), isTrue);
      expect(beverageItems.any((i) => i.produkNama == 'Ayam Goreng'), isFalse);

      final allItems = filterItems(allPurposePrinter);
      expect(allItems.length, 3); // All items included
    });
  });
}
