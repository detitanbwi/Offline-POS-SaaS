import '../models/table.dart';

abstract class TableRepository {
  Future<List<TableModel>> getAllTables();
  Future<TableModel?> getTableById(String id);
  Future<void> saveTable(TableModel table);
  Future<void> deleteTable(String id);
  Future<bool> isTableNameExists(String name, {String? excludeId});
  Future<bool> isTableNumberExists(String number, {String? excludeId});
  Future<void> updateTableStatus(String id, int status);
}
