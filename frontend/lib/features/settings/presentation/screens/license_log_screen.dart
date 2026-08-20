import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/database/pos_database.dart';
import 'package:intl/intl.dart';

class LicenseLogScreen extends StatefulWidget {
  const LicenseLogScreen({super.key});

  @override
  State<LicenseLogScreen> createState() => _LicenseLogScreenState();
}

class _LicenseLogScreenState extends State<LicenseLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final db = await PosDatabase.instance.database;
      final logs = await db.query(
        'license_logs',
        orderBy: 'created_at DESC',
      );
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Habis';
    int days = seconds ~/ (24 * 3600);
    int hours = (seconds % (24 * 3600)) ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    
    if (days > 0) return '$days hr $hours jm';
    if (hours > 0) return '$hours jm $minutes mnt';
    return '$minutes mnt';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'offline':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Log Aktivitas Lisensi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada log pengecekan lisensi',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.tryParse(log['created_at']);
                    final formattedDate = date != null
                        ? DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal())
                        : '-';
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.security_rounded,
                        color: _getStatusColor(log['status']),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            log['status'].toString().toUpperCase(),
                            style: AppTypography.titleSmall.copyWith(
                              color: _getStatusColor(log['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Trigger: ${log['trigger_type']}',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa Waktu saat cek: ${_formatDuration(log['remaining_time_seconds'] as int)}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
