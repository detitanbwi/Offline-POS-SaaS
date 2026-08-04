import 'dart:typed_data';

class PrintQueueJobModel {
  final String id;
  final String targetPrinterType; // 'bluetooth', 'network', 'usb'
  final String targetAddress;
  final List<int> payloadBytes;
  final String jobType; // 'kitchen_ticket', 'customer_receipt', 'void_ticket'
  final String? referenceId;
  final String status; // 'pending', 'processing', 'failed', 'completed'
  final int retryCount;
  final int maxRetries;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrintQueueJobModel({
    required this.id,
    required this.targetPrinterType,
    required this.targetAddress,
    required this.payloadBytes,
    required this.jobType,
    this.referenceId,
    this.status = 'pending',
    this.retryCount = 0,
    this.maxRetries = 5,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending' || status == 'failed';
  bool get canRetry => retryCount < maxRetries && isPending;

  PrintQueueJobModel copyWith({
    String? id,
    String? targetPrinterType,
    String? targetAddress,
    List<int>? payloadBytes,
    String? jobType,
    String? referenceId,
    String? status,
    int? retryCount,
    int? maxRetries,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrintQueueJobModel(
      id: id ?? this.id,
      targetPrinterType: targetPrinterType ?? this.targetPrinterType,
      targetAddress: targetAddress ?? this.targetAddress,
      payloadBytes: payloadBytes ?? this.payloadBytes,
      jobType: jobType ?? this.jobType,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_printer_type': targetPrinterType,
      'target_address': targetAddress,
      'payload_bytes': Uint8List.fromList(payloadBytes),
      'job_type': jobType,
      'reference_id': referenceId,
      'status': status,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PrintQueueJobModel.fromMap(Map<String, dynamic> map) {
    final bytesVal = map['payload_bytes'];
    List<int> bytesList;
    if (bytesVal is Uint8List) {
      bytesList = bytesVal;
    } else if (bytesVal is List) {
      bytesList = bytesVal.cast<int>();
    } else {
      bytesList = [];
    }

    return PrintQueueJobModel(
      id: map['id'] as String,
      targetPrinterType: map['target_printer_type'] as String? ?? 'bluetooth',
      targetAddress: map['target_address'] as String? ?? '',
      payloadBytes: bytesList,
      jobType: map['job_type'] as String? ?? 'kitchen_ticket',
      referenceId: map['reference_id'] as String?,
      status: map['status'] as String? ?? 'pending',
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      maxRetries: (map['max_retries'] as num?)?.toInt() ?? 5,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
