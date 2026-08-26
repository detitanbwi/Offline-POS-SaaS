import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

class OrderDiscountModal extends StatefulWidget {
  final double itemsSubtotal;
  final double currentDiscountRate;
  final double currentDiscountAmount;
  final String currentDiscountType;
  final Function({
    required String discountType,
    required double discountValue,
  }) onApply;

  const OrderDiscountModal({
    super.key,
    required this.itemsSubtotal,
    required this.currentDiscountRate,
    required this.currentDiscountAmount,
    required this.currentDiscountType,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required double itemsSubtotal,
    required double currentDiscountRate,
    required double currentDiscountAmount,
    required String currentDiscountType,
    required Function({
      required String discountType,
      required double discountValue,
    }) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDiscountModal(
        itemsSubtotal: itemsSubtotal,
        currentDiscountRate: currentDiscountRate,
        currentDiscountAmount: currentDiscountAmount,
        currentDiscountType: currentDiscountType,
        onApply: onApply,
      ),
    );
  }

  @override
  State<OrderDiscountModal> createState() => _OrderDiscountModalState();
}

class _OrderDiscountModalState extends State<OrderDiscountModal> {
  late TextEditingController _discountController;
  String _discountType = 'percent'; // 'percent' or 'nominal'

  @override
  void initState() {
    super.initState();
    _discountType = widget.currentDiscountType;
    if (_discountType == 'percent' && widget.currentDiscountRate > 0) {
      _discountController = TextEditingController(
        text: widget.currentDiscountRate.toStringAsFixed(
          widget.currentDiscountRate.truncateToDouble() == widget.currentDiscountRate ? 0 : 1,
        ),
      );
    } else if (_discountType == 'nominal' && widget.currentDiscountAmount > 0) {
      _discountController = TextEditingController(
        text: CurrencyFormatter.formatNumber(widget.currentDiscountAmount),
      );
    } else {
      _discountController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  double _parseDiscountInput() {
    final text = _discountController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  void _applyPresetPercent(double pct) {
    setState(() {
      _discountType = 'percent';
      _discountController.text = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parsedValue = _parseDiscountInput();

    double calculatedDiscount = 0.0;
    if (_discountType == 'percent') {
      calculatedDiscount = (widget.itemsSubtotal * (parsedValue.clamp(0.0, 100.0) / 100)).clamp(0.0, widget.itemsSubtotal);
    } else {
      calculatedDiscount = parsedValue.clamp(0.0, widget.itemsSubtotal);
    }
    final netSubtotal = (widget.itemsSubtotal - calculatedDiscount).clamp(0.0, widget.itemsSubtotal);

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: AppSpacing.m,
        right: AppSpacing.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Diskon Nota / Transaksi',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.divider),

            // Diskon Type Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tipe Potongan',
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      _buildTypeToggle('percent', 'Persen (%)'),
                      _buildTypeToggle('nominal', 'Nominal (Rp)'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Input Field
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (val) {
                if (_discountType == 'nominal') {
                  final cleanText = val.replaceAll('.', '').replaceAll(',', '');
                  final parsed = double.tryParse(cleanText);
                  if (parsed != null) {
                    final formatted = CurrencyFormatter.formatNumber(parsed);
                    if (_discountController.text != formatted) {
                      _discountController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  } else if (cleanText.isEmpty) {
                    _discountController.clear();
                  }
                }
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: _discountType == 'percent' ? 'Contoh: 10 (Diskon 10%)' : 'Contoh: 20.000 (Potongan Rp 20.000)',
                prefixIcon: Icon(
                  _discountType == 'percent' ? Icons.percent_rounded : Icons.payments_outlined,
                  color: AppColors.primary,
                ),
                suffixIcon: _discountController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _discountController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Preset Buttons (only for percent)
            if (_discountType == 'percent')
              Wrap(
                spacing: 8,
                children: [5.0, 10.0, 15.0, 20.0, 25.0, 50.0].map((pct) {
                  final isSelected = parsedValue == pct;
                  return ChoiceChip(
                    label: Text('${pct.toInt()}%'),
                    selected: isSelected,
                    onSelected: (_) => _applyPresetPercent(pct),
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.sp,
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Breakdown calculation preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: calculatedDiscount > 0
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: calculatedDiscount > 0 ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal Tagihan:', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                      Text(currencyFormat.format(widget.itemsSubtotal), style: AppTypography.bodyMedium),
                    ],
                  ),
                  if (calculatedDiscount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Potongan Diskon Nota:', style: AppTypography.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                        Text('-${currencyFormat.format(calculatedDiscount)}', style: AppTypography.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const Divider(height: 16, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal Bersih:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        currencyFormat.format(netSubtotal),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (widget.currentDiscountRate > 0 || widget.currentDiscountAmount > 0)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        widget.onApply(discountType: 'percent', discountValue: 0.0);
                        Navigator.pop(context);
                      },
                      child: const Text('Hapus Diskon'),
                    ),
                  ),
                if (widget.currentDiscountRate > 0 || widget.currentDiscountAmount > 0)
                  const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final safeValue = _parseDiscountInput();
                      widget.onApply(
                        discountType: _discountType,
                        discountValue: safeValue,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Terapkan Diskon',
                      style: AppTypography.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String type, String label) {
    final isSelected = _discountType == type;
    return InkWell(
      onTap: () {
        if (_discountType != type) {
          setState(() {
            _discountType = type;
            _discountController.clear();
          });
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
