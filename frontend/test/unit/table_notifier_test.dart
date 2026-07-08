import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/table/domain/repositories/table_repository.dart';
import 'package:frontend/features/table/domain/models/table.dart';
import 'package:frontend/features/table/application/table_notifier.dart';

class TableRepositoryMock implements TableRepository {
  final List<TableModel> tables = [];

  @override
  Future<List<TableModel>> getAllTables() async {
    return tables;
  }

  @override
  Future<TableModel?> getTableById(String id) async {
    try {
      return tables.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTable(TableModel table) async {
    final index = tables.indexWhere((t) => t.id == table.id);
    if (index >= 0) {
      tables[index] = table;
    } else {
      tables.add(table);
    }
  }

  @override
  Future<void> deleteTable(String id) async {
    tables.removeWhere((t) => t.id == id);
  }

  @override
  Future<bool> isTableNameExists(String name, {String? excludeId}) async {
    return tables.any((t) => t.nama.toLowerCase() == name.toLowerCase() && t.id != excludeId);
  }

  @override
  Future<bool> isTableNumberExists(String number, {String? excludeId}) async {
    return tables.any((t) => t.nomor == number && t.id != excludeId);
  }

  @override
  Future<void> updateTableStatus(String id, int status) async {
    final index = tables.indexWhere((t) => t.id == id);
    if (index >= 0) {
      tables[index] = tables[index].copyWith(status: status);
    }
  }
}

void main() {
  group('TableNotifier Bulk Generation Tests', () {
    late TableRepositoryMock mockRepository;
    late TableNotifier notifier;

    setUp(() {
      mockRepository = TableRepositoryMock();
      notifier = TableNotifier(mockRepository);
    });

    test('generateMultipleTables generates correct number of tables with padding', () async {
      final success = await notifier.generateMultipleTables(5);
      expect(success, true);
      expect(notifier.state.allTables.length, 5);
      
      expect(notifier.state.allTables[0].nomor, '01');
      expect(notifier.state.allTables[0].nama, 'Meja 01');

      expect(notifier.state.allTables[4].nomor, '05');
      expect(notifier.state.allTables[4].nama, 'Meja 05');
    });

    test('generateMultipleTables skips existing tables and numbering matches correctly', () async {
      // Add existing Meja 01
      await mockRepository.saveTable(TableModel(
        id: '1',
        nama: 'Meja 01',
        nomor: '01',
        status: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await notifier.loadTables();
      expect(notifier.state.allTables.length, 1);

      // Generate 2 tables, should generate 02 and 03
      final success = await notifier.generateMultipleTables(2);
      expect(success, true);
      expect(notifier.state.allTables.length, 3);

      expect(notifier.state.allTables.any((t) => t.nomor == '01'), true);
      expect(notifier.state.allTables.any((t) => t.nomor == '02'), true);
      expect(notifier.state.allTables.any((t) => t.nomor == '03'), true);
    });
  });
}
