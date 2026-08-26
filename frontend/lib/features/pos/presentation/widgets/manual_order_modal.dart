import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/cart_notifier.dart';

class ManualOrderModal extends ConsumerStatefulWidget {
  const ManualOrderModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const ManualOrderModal(),
    );
  }

  @override
  ConsumerState<ManualOrderModal> createState() => _ManualOrderModalState();
}

class _ManualOrderModalState extends ConsumerState<ManualOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  int _qty = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _parsedPrice {
    final cleanText = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0.0;
  }

  double get _totalPrice => _parsedPrice * _qty;

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = _parsedPrice;

    if (name.isEmpty) {
      AppSnackbar.showError(context, 'Nama item manual wajib diisi');
      return;
    }

    final success = ref.read(cartNotifierProvider.notifier).addManualItem(
      nama: name,
      harga: price,
      qty: _qty,
      catatan: _notesController.text.trim(),
    );

    if (success) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(context, 'Item "$name" berhasil ditambahkan ke keranjang');
    } else {
      final error = ref.read(cartNotifierProvider).errorMessage ?? 'Gagal menambahkan pesanan';
      AppSnackbar.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520.w,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h + bottomInset),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Bar with Drag Handle and Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withAlpha(80),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manual Pesanan',
                                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Item custom non-stock bebas di luar katalog',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 28, color: AppColors.divider),

                  // Input Nama Pesanan
                  Text(
                    'Nama Item / Pesanan *',
                    style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Misal: Ongkir Khusus, Custom Menu, Biaya Tambahan...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(150), fontSize: 13.sp),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textSecondary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Nama item wajib diisi' : null,
                  ),
                  SizedBox(height: 16.h),

                  // Input Harga Satuan (Rp)
                  Text(
                    'Harga Satuan (Rp) *',
                    style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14.sp),
                      prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.textSecondary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty || _parsedPrice <= 0) {
                        return 'Harga wajib diisi dan lebih dari 0';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Jumlah (Qty) Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jumlah (Qty)',
                            style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Kuantitas pesanan',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                            ),
                            Container(
                              constraints: BoxConstraints(minWidth: 40.w),
                              alignment: Alignment.center,
                              child: Text(
                                '$_qty',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                              onPressed: () => setState(() => _qty++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Catatan / Request (Opsional)
                  Text(
                    'Catatan / Request (Opsional)',
                    style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kurang manis, kirim ke meja depan, dll...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(150), fontSize: 12.sp),
                      prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.textSecondary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Subtotal Card Preview
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'NON-STOCK',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text('Subtotal:', style: AppTypography.titleSmall),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(_totalPrice),
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          text: 'Tambah ke Pesanan',
                          onPressed: _handleSubmit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  final int maxDigits;
  RupiahInputFormatter({this.maxDigits = 11});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (cleanText.length > maxDigits) {
      return oldValue;
    }

    final double value = double.tryParse(cleanText) ?? 0;
    final formatter = NumberFormat.decimalPattern('id_ID');
    final String formattedText = formatter.format(value);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
