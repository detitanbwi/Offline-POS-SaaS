import '../../../../core/database/pos_database.dart';

class TableTransferService {
  final PosDatabase _db;

  TableTransferService(this._db);

  Future<void> transferTable({
    required String masterOrderId,
    required String fromTableId,
    required String toTableId,
  }) async {
    final db = await _db.database;

    // Verify destination table is available
    final destRows = await db.query(
      'tables',
      where: 'id = ?',
      whereArgs: [toTableId],
    );
    if (destRows.isEmpty) {
      throw Exception('Meja tujuan tidak ditemukan.');
    }
    final destStatus = (destRows.first['status'] as num?)?.toInt() ?? 0;
    if (destStatus != 0) {
      throw Exception('Meja tujuan sedang terisi. Harap pilih meja yang kosong.');
    }

    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Move master order to the new table
      await txn.update(
        'master_orders',
        {
          'table_id': toTableId,
          'last_activity_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [masterOrderId],
      );

      // 1b. Move legacy orders if any exist for backward compatibility
      await txn.update(
        'orders',
        {
          'table_id': toTableId,
          'updated_at': now,
        },
        where: 'table_id = ? AND status = ?',
        whereArgs: [fromTableId, 'pending'],
      );

      // 2. Free the origin table
      await txn.update(
        'tables',
        {
          'status': 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [fromTableId],
      );

      // 3. Mark the destination table as occupied (status 1)
      await txn.update(
        'tables',
        {
          'status': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [toTableId],
      );
    });
  }
}
