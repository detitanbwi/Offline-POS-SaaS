enum TableVisualState {
  available,       // White - Empty table (status == 0)
  occupiedUnpaid,  // Yellow - Occupied with unpaid balance
  occupiedPrepaid, // Green - Occupied and prepaid / fully paid
  alert,           // Red - Idle > 45m or unpaid after served > 20m
}

class TableUiModel {
  final String id;
  final String nama;
  final String nomor;
  final int rawStatus; // 0=empty, 1=occupied, 2=reserved, 3=alert
  final TableVisualState visualState;
  final String? activeMasterOrderId;
  final String? activeNomorOrder;
  final String? customerName;
  final double grandTotal;
  final double totalPaid;
  final DateTime? lastActivityAt;
  final int idleMinutes;

  const TableUiModel({
    required this.id,
    required this.nama,
    required this.nomor,
    required this.rawStatus,
    required this.visualState,
    this.activeMasterOrderId,
    this.activeNomorOrder,
    this.customerName,
    this.grandTotal = 0.0,
    this.totalPaid = 0.0,
    this.lastActivityAt,
    this.idleMinutes = 0,
  });

  bool get isAvailable => visualState == TableVisualState.available;
  bool get isOccupied => visualState != TableVisualState.available;
  double get remainingBalance => grandTotal - totalPaid;

  TableUiModel copyWith({
    String? id,
    String? nama,
    String? nomor,
    int? rawStatus,
    TableVisualState? visualState,
    String? activeMasterOrderId,
    String? activeNomorOrder,
    String? customerName,
    double? grandTotal,
    double? totalPaid,
    DateTime? lastActivityAt,
    int? idleMinutes,
  }) {
    return TableUiModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      nomor: nomor ?? this.nomor,
      rawStatus: rawStatus ?? this.rawStatus,
      visualState: visualState ?? this.visualState,
      activeMasterOrderId: activeMasterOrderId ?? this.activeMasterOrderId,
      activeNomorOrder: activeNomorOrder ?? this.activeNomorOrder,
      customerName: customerName ?? this.customerName,
      grandTotal: grandTotal ?? this.grandTotal,
      totalPaid: totalPaid ?? this.totalPaid,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      idleMinutes: idleMinutes ?? this.idleMinutes,
    );
  }
}
