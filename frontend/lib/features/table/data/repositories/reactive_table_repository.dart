import 'dart:async';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/table_ui_state.dart';

class ReactiveTableRepository {
  final PosDatabase _db;
  final StreamController<List<TableUiModel>> _tableStateController =
      StreamController<List<TableUiModel>>.broadcast();

  ReactiveTableRepository(this._db);

  Stream<List<TableUiModel>> get tableUiStateStream =>
      _tableStateController.stream;

  Future<List<TableUiModel>> loadAndEmitTables() async {
    final db = await _db.database;
    final now = DateTime.now();

    final tableRows = await db.query('tables', orderBy: 'nomor ASC');
    final List<TableUiModel> uiModels = [];

    for (final t in tableRows) {
      final tableId = t['id'] as String;
      final nama = t['nama'] as String;
      final nomor = t['nomor'] as String;
      final rawStatus = (t['status'] as num?)?.toInt() ?? 0;

      // Look up active master order for this table
      final orderRows = await db.query(
        'master_orders',
        where: "table_id = ? AND session_status = 'open'",
        limit: 1,
      );

      String? activeMasterOrderId;
      String? activeNomorOrder;
      String? customerName;
      double grandTotal = 0.0;
      double totalPaid = 0.0;
      DateTime? lastActivityAt;
      DateTime? allItemsServedAt;
      String paymentStatus = 'unpaid';

      if (orderRows.isNotEmpty) {
        final ord = orderRows.first;
        activeMasterOrderId = ord['id'] as String?;
        activeNomorOrder = ord['nomor_order'] as String?;
        customerName = ord['customer_name'] as String?;
        grandTotal = (ord['grand_total'] as num?)?.toDouble() ?? 0.0;
        totalPaid = (ord['total_paid'] as num?)?.toDouble() ?? 0.0;
        paymentStatus = ord['payment_status'] as String? ?? 'unpaid';

        if (ord['last_activity_at'] != null) {
          lastActivityAt = DateTime.parse(ord['last_activity_at'] as String);
        }
        if (ord['all_items_served_at'] != null) {
          allItemsServedAt =
              DateTime.parse(ord['all_items_served_at'] as String);
        }
      }

      if (lastActivityAt == null && t['updated_at'] != null) {
        lastActivityAt = DateTime.parse(t['updated_at'] as String);
      }

      final int idleMinutes = lastActivityAt != null
          ? now.difference(lastActivityAt).inMinutes
          : 0;
      final int servedElapsedMinutes = allItemsServedAt != null
          ? now.difference(allItemsServedAt).inMinutes
          : 0;

      // Derive the 4-state visual status
      TableVisualState visualState;
      if (rawStatus == 0 && activeMasterOrderId == null) {
        visualState = TableVisualState.available; // White (#FFFFFF)
      } else if (rawStatus == 2 || paymentStatus == 'paid') {
        visualState = TableVisualState.occupiedPrepaid; // Green (#A5D6A7)
      } else if (rawStatus == 3 ||
          (idleMinutes >= 45 && paymentStatus == 'unpaid') ||
          (allItemsServedAt != null &&
              servedElapsedMinutes >= 20 &&
              paymentStatus == 'unpaid')) {
        visualState = TableVisualState.alert; // Red (#EF9A9A)
      } else {
        visualState = TableVisualState.occupiedUnpaid; // Yellow (#FFF59D)
      }

      uiModels.add(
        TableUiModel(
          id: tableId,
          nama: nama,
          nomor: nomor,
          rawStatus: rawStatus,
          visualState: visualState,
          activeMasterOrderId: activeMasterOrderId,
          activeNomorOrder: activeNomorOrder,
          customerName: customerName,
          grandTotal: grandTotal,
          totalPaid: totalPaid,
          lastActivityAt: lastActivityAt,
          idleMinutes: idleMinutes,
        ),
      );
    }

    _tableStateController.add(uiModels);
    return uiModels;
  }

  void notifyTableStateChanged() {
    loadAndEmitTables();
  }

  void dispose() {
    _tableStateController.close();
  }
}
