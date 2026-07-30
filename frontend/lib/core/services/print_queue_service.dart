import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/pos_database.dart';
import 'printer_service.dart';
import '../../features/printer/domain/models/print_queue_job.dart';

class PrintQueueService {
  final PosDatabase _db;
  final PrinterService _printerService;
  final _uuid = const Uuid();
  Timer? _workerTimer;
  bool _isProcessing = false;

  PrintQueueService(this._db, [PrinterService? printerService])
      : _printerService = printerService ?? PrinterService.instance;

  void startBackgroundWorker({Duration interval = const Duration(seconds: 30)}) {
    _workerTimer?.cancel();
    _workerTimer = Timer.periodic(interval, (_) => processQueue());
  }

  void stopBackgroundWorker() {
    _workerTimer?.cancel();
    _workerTimer = null;
  }

  Future<PrintQueueJobModel> enqueueJob({
    required String targetPrinterType,
    required String targetAddress,
    required List<int> payloadBytes,
    required String jobType,
    String? referenceId,
    int maxRetries = 5,
  }) async {
    final now = DateTime.now();
    final job = PrintQueueJobModel(
      id: _uuid.v4(),
      targetPrinterType: targetPrinterType,
      targetAddress: targetAddress,
      payloadBytes: payloadBytes,
      jobType: jobType,
      referenceId: referenceId,
      status: 'pending',
      retryCount: 0,
      maxRetries: maxRetries,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.insert('print_queue_jobs', job.toMap());

    // Trigger processing asynchronously
    unawaited(processQueue());
    return job;
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final db = await _db.database;
      final rows = await db.query(
        'print_queue_jobs',
        where: "status IN ('pending', 'failed') AND retry_count < max_retries",
        orderBy: 'created_at ASC',
      );

      for (final row in rows) {
        final job = PrintQueueJobModel.fromMap(row);
        final success = await _printerService.printBytes(
          job.payloadBytes,
          job.targetAddress,
        );

        final now = DateTime.now();
        if (success) {
          await db.update(
            'print_queue_jobs',
            {
              'status': 'completed',
              'error_message': null,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [job.id],
          );
        } else {
          final newRetry = job.retryCount + 1;
          final newStatus = newRetry >= job.maxRetries ? 'failed' : 'pending';
          await db.update(
            'print_queue_jobs',
            {
              'status': newStatus,
              'retry_count': newRetry,
              'error_message': 'Failed to send ESC/POS bytes to ${job.targetAddress}',
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [job.id],
          );
        }
      }
    } catch (e) {
      debugPrint('PrintQueueService error in processQueue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<PrintQueueJobModel>> getPendingJobs() async {
    final db = await _db.database;
    final rows = await db.query(
      'print_queue_jobs',
      where: "status IN ('pending', 'failed')",
      orderBy: 'created_at DESC',
    );
    return rows.map((e) => PrintQueueJobModel.fromMap(e)).toList();
  }

  Future<bool> retryJob(String jobId) async {
    final db = await _db.database;
    await db.update(
      'print_queue_jobs',
      {
        'status': 'pending',
        'retry_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
    await processQueue();
    final res = await db.query(
      'print_queue_jobs',
      where: 'id = ?',
      whereArgs: [jobId],
    );
    if (res.isEmpty) return false;
    final updated = PrintQueueJobModel.fromMap(res.first);
    return updated.status == 'completed';
  }

  Future<void> clearCompletedJobs() async {
    final db = await _db.database;
    await db.delete(
      'print_queue_jobs',
      where: "status = 'completed'",
    );
  }
}
