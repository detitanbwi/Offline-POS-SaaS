import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

class StockDateRangeModal extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(DateTime? start, DateTime? end) onApply;

  const StockDateRangeModal({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    required Function(DateTime? start, DateTime? end) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StockDateRangeModal(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        onApply: onApply,
      ),
    );
  }

  @override
  State<StockDateRangeModal> createState() => _StockDateRangeModalState();
}

class _StockDateRangeModalState extends State<StockDateRangeModal> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate != null
        ? DateTime(widget.initialStartDate!.year, widget.initialStartDate!.month, widget.initialStartDate!.day)
        : null;
    _endDate = widget.initialEndDate != null
        ? DateTime(widget.initialEndDate!.year, widget.initialEndDate!.month, widget.initialEndDate!.day)
        : null;

    final initial = _startDate ?? DateTime.now();
    _displayedMonth = DateTime(initial.year, initial.month, 1);
  }

  void _onDateTapped(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // Klik pertama atau reset saat range sudah terisi: Jadikan start date
        _startDate = normalized;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        // Klik kedua: Menentukan end date
        if (normalized.isBefore(_startDate!)) {
          // Jika klik tanggal sebelum start date, jadikan tanggal ini sebagai start date baru
          _startDate = normalized;
          _endDate = null;
        } else {
          // Range terbentuk
          _endDate = normalized;
        }
      }
    });
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      switch (preset) {
        case 'all':
          _startDate = null;
          _endDate = null;
          break;
        case 'today':
          _startDate = today;
          _endDate = today;
          _displayedMonth = DateTime(today.year, today.month, 1);
          break;
        case 'thisMonth':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = DateTime(today.year, today.month + 1, 0);
          _displayedMonth = DateTime(today.year, today.month, 1);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy', 'id_ID');
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = _displayedMonth.weekday; // 1 = Monday, 7 = Sunday

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Rentang Tanggal',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pilih tanggal awal lalu tanggal akhir',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Hotel Style Range Indicator Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  // Start Date Box
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TANGGAL AWAL',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.sp,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _startDate != null ? dateFormat.format(_startDate!) : 'Pilih tanggal...',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _startDate != null ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 18),
                  ),

                  // End Date Box
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TANGGAL AKHIR',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.sp,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _endDate != null
                              ? dateFormat.format(_endDate!)
                              : (_startDate != null ? 'Pilih akhir...' : '-'),
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _endDate != null ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Preset Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildPresetChip('Semua', 'all', _startDate == null && _endDate == null),
                const SizedBox(width: 8),
                _buildPresetChip('Hari Ini', 'today', false),
                const SizedBox(width: 8),
                _buildPresetChip('Bulan Ini', 'thisMonth', false),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),

          // Month Navigator (< Month Year >)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  monthFormat.format(_displayedMonth),
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 26),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // Weekday Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _WeekdayLabel('Sen'),
                _WeekdayLabel('Sel'),
                _WeekdayLabel('Rab'),
                _WeekdayLabel('Kam'),
                _WeekdayLabel('Jum'),
                _WeekdayLabel('Sab'),
                _WeekdayLabel('Min'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (firstWeekday - 1) + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }

                final day = index - (firstWeekday - 2);
                final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
                final isStart = _startDate != null && _isSameDay(_startDate!, cellDate);
                final isEnd = _endDate != null && _isSameDay(_endDate!, cellDate);
                final isInRange = _startDate != null &&
                    _endDate != null &&
                    cellDate.isAfter(_startDate!) &&
                    cellDate.isBefore(_endDate!);

                final isToday = _isSameDay(DateTime.now(), cellDate);

                return InkWell(
                  onTap: () => _onDateTapped(cellDate),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isInRange
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isStart || isEnd ? AppColors.primary : Colors.transparent),
                      borderRadius: isStart
                          ? (_endDate != null && !isEnd
                              ? const BorderRadius.horizontal(left: Radius.circular(20))
                              : BorderRadius.circular(20))
                          : (isEnd
                              ? (_startDate != null && !isStart
                                  ? const BorderRadius.horizontal(right: Radius.circular(20))
                                  : BorderRadius.circular(20))
                              : (isInRange ? BorderRadius.zero : BorderRadius.circular(20))),
                      border: isToday && !isStart && !isEnd
                          ? Border.all(color: AppColors.primary, width: 1.2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: (isStart || isEnd || isToday) ? FontWeight.bold : FontWeight.normal,
                        color: (isStart || isEnd)
                            ? Colors.white
                            : (isInRange
                                ? AppColors.primary
                                : (cellDate.weekday == DateTime.sunday
                                    ? AppColors.error
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      widget.onApply(null, null);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Reset Semua',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: 'Terapkan Filter',
                    onPressed: () {
                      // If only start date selected, treat as single day range
                      final start = _startDate;
                      final end = _endDate ?? _startDate;
                      widget.onApply(start, end);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String preset, bool isSelected) {
    return InkWell(
      onTap: () => _setPreset(preset),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.labelSmall.copyWith(
          color: text == 'Min' ? AppColors.error : AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 11.sp,
        ),
      ),
    );
  }
}
