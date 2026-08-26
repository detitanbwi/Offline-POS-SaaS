import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/cart_item.dart';

class ItemDiscountModal extends StatefulWidget {
  final CartItem item;
  final Function({
    required String catatan,
    required String discountType,
    required double discountValue,
  }) onApply;

  const ItemDiscountModal({
    super.key,
    required this.item,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required CartItem item,
    required Function({
      required String catatan,
      required String discountType,
      required double discountValue,
    }) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDiscountModal(item: item, onApply: onApply),
    );
  }

  @override
  State<ItemDiscountModal> createState() => _ItemDiscountModalState();
}

class _ItemDiscountModalState extends State<ItemDiscountModal> {
  late TextEditingController _noteController;
  late TextEditingController _discountController;
  String _discountType = 'percent'; // 'percent' or 'nominal'

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.catatan);

    _discountType = widget.item.discountType;
    if (_discountType == 'percent' && widget.item.discountPercentage > 0) {
      _discountController = TextEditingController(
        text: widget.item.discountPercentage.toStringAsFixed(
          widget.item.discountPercentage.truncateToDouble() == widget.item.discountPercentage ? 0 : 1,
        ),
      );
    } else if (_discountType == 'nominal' && widget.item.discountAmount > 0) {
      _discountController = TextEditingController(
        text: CurrencyFormatter.formatNumber(widget.item.discountAmount),
      );
    } else {
      _discountController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
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
    final grossTotal = widget.item.grossSubtotal;
    final parsedValue = _parseDiscountInput();

    double calculatedDiscount = 0.0;
    if (_discountType == 'percent') {
      calculatedDiscount = (grossTotal * (parsedValue.clamp(0.0, 100.0) / 100)).clamp(0.0, grossTotal);
    } else {
      calculatedDiscount = parsedValue.clamp(0.0, grossTotal);
    }
    final netItemTotal = (grossTotal - calculatedDiscount).clamp(0.0, grossTotal);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.product.nama,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.item.qty} pcs x ${currencyFormat.format(widget.item.product.harga)} = ${currencyFormat.format(grossTotal)}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.divider),

            // Diskon Section Title & Type Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diskon Item',
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
            const SizedBox(height: 10),

            // Discount Input Field
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
                hintText: _discountType == 'percent' ? 'Contoh: 10 (Diskon 10%)' : 'Contoh: 5.000 (Potongan Rp 5.000)',
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
            const SizedBox(height: 8),

            // Quick Preset Buttons (only for percent)
            if (_discountType == 'percent')
              Wrap(
                spacing: 8,
                children: [5.0, 10.0, 15.0, 20.0, 50.0].map((pct) {
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

            // Catatan Item Field
            Text(
              'Catatan Tambahan (Opsional)',
              style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Misal: Kurang manis, tanpa es, pedas, dsb.',
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
            const SizedBox(height: 16),

            // Preview Price Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: calculatedDiscount > 0
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: calculatedDiscount > 0 ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Harga Item:',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      if (calculatedDiscount > 0)
                        Text(
                          'Hemat ${currencyFormat.format(calculatedDiscount)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(netItemTotal),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final safeValue = _parseDiscountInput();
                  widget.onApply(
                    catatan: _noteController.text.trim(),
                    discountType: _discountType,
                    discountValue: safeValue,
                  );
                  Navigator.pop(context);
                },
                child: Text(
                  'Terapkan',
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
