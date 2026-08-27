import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../product/domain/models/product.dart';

class ProductModifierModal extends StatefulWidget {
  final Product product;
  final List<SelectedModifier>? initialModifiers;
  final int initialQty;
  final String initialNotes;
  final bool isEditing;
  final Function(List<SelectedModifier> selectedModifiers, int qty, String notes) onConfirm;

  const ProductModifierModal({
    super.key,
    required this.product,
    this.initialModifiers,
    this.initialQty = 1,
    this.initialNotes = '',
    this.isEditing = false,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required Product product,
    List<SelectedModifier>? initialModifiers,
    int initialQty = 1,
    String initialNotes = '',
    bool isEditing = false,
    required Function(List<SelectedModifier> selectedModifiers, int qty, String notes) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductModifierModal(
        product: product,
        initialModifiers: initialModifiers,
        initialQty: initialQty,
        initialNotes: initialNotes,
        isEditing: isEditing,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ProductModifierModal> createState() => _ProductModifierModalState();
}

class _ProductModifierModalState extends State<ProductModifierModal> {
  final Map<String, Set<String>> _selectedOptionIdsByGroup = {};
  late final TextEditingController _notesController;
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty > 0 ? widget.initialQty : 1;
    _notesController = TextEditingController(text: widget.initialNotes);

    if (widget.initialModifiers != null && widget.initialModifiers!.isNotEmpty) {
      for (var grp in widget.product.modifierGroups) {
        _selectedOptionIdsByGroup[grp.id] = {};
      }
      for (var mod in widget.initialModifiers!) {
        _selectedOptionIdsByGroup.putIfAbsent(mod.groupId, () => {}).add(mod.optionId);
      }
    } else {
      // Initialize default selections
      for (var grp in widget.product.modifierGroups) {
        _selectedOptionIdsByGroup[grp.id] = {};
        final defaultOpts = grp.options.where((o) => o.isDefault).toList();
        if (defaultOpts.isNotEmpty) {
          for (var opt in defaultOpts) {
            _selectedOptionIdsByGroup[grp.id]!.add(opt.id);
            if (!grp.allowMultiple) break; // single selection
          }
        } else if (grp.isRequired && grp.options.isNotEmpty && !grp.allowMultiple) {
          // Automatically select the first option if single required
          _selectedOptionIdsByGroup[grp.id]!.add(grp.options.first.id);
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<SelectedModifier> get _selectedModifiers {
    final List<SelectedModifier> result = [];
    for (var grp in widget.product.modifierGroups) {
      final selectedIds = _selectedOptionIdsByGroup[grp.id] ?? {};
      for (var opt in grp.options) {
        if (selectedIds.contains(opt.id)) {
          result.add(SelectedModifier(
            groupId: grp.id,
            groupName: grp.nama,
            optionId: opt.id,
            optionName: opt.nama,
            harga: opt.harga,
          ));
        }
      }
    }
    return result;
  }

  double get _unitPrice {
    final modPrice = _selectedModifiers.fold<double>(0.0, (sum, m) => sum + m.harga);
    return widget.product.harga + modPrice;
  }

  double get _totalPrice => _unitPrice * _qty;

  bool get _isValid {
    for (var grp in widget.product.modifierGroups) {
      final count = (_selectedOptionIdsByGroup[grp.id] ?? {}).length;
      if (grp.isRequired && count < 1) {
        return false;
      }
      if (grp.minSelect > 0 && count < grp.minSelect) {
        return false;
      }
      if (grp.maxSelect > 0 && count > grp.maxSelect) {
        return false;
      }
    }
    return true;
  }

  void _toggleOption(ProductModifierGroup group, ProductModifierOption option) {
    setState(() {
      final currentSet = _selectedOptionIdsByGroup[group.id] ?? {};
      if (group.allowMultiple) {
        if (currentSet.contains(option.id)) {
          currentSet.remove(option.id);
        } else {
          if (group.maxSelect > 0 && currentSet.length >= group.maxSelect) {
            // Reached max
            return;
          }
          currentSet.add(option.id);
        }
      } else {
        // Single select (radio)
        if (currentSet.contains(option.id) && !group.isRequired) {
          currentSet.clear();
        } else {
          currentSet.clear();
          currentSet.add(option.id);
        }
      }
      _selectedOptionIdsByGroup[group.id] = currentSet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'Ubah Varian: ${widget.product.nama}' : widget.product.nama,
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Harga Dasar: ${CurrencyFormatter.format(widget.product.harga)}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
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
          ),

          // Body: Modifier groups & options list
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...widget.product.modifierGroups.map((grp) => _buildGroupSection(grp)),
                  SizedBox(height: 12.h),
                  Text(
                    'Catatan Pesanan',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  AppTextField(
                    controller: _notesController,
                    labelText: 'Catatan Pesanan',
                    hintText: 'Contoh: Sedikit es, manis sedang...',
                    prefixIcon: Icons.edit_note_rounded,
                    maxLines: 2,
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),

          // Bottom Bar: Qty counter & Add to Order button
          Container(
            padding: EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
              border: const Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Qty Counter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        ),
                        Text(
                          '$_qty',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                          onPressed: () => setState(() => _qty++),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Submit Button
                  Expanded(
                    child: AppButton(
                      text: widget.isEditing
                          ? 'Perbarui (${CurrencyFormatter.format(_totalPrice)})'
                          : 'Tambah (${CurrencyFormatter.format(_totalPrice)})',
                      icon: widget.isEditing ? Icons.check_circle_outline_rounded : Icons.shopping_bag_outlined,
                      onPressed: _isValid
                          ? () {
                              widget.onConfirm(
                                _selectedModifiers,
                                _qty,
                                _notesController.text.trim(),
                              );
                              Navigator.pop(context);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(ProductModifierGroup group) {
    final selectedIds = _selectedOptionIdsByGroup[group.id] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.nama,
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: group.isRequired
                    ? (selectedIds.isNotEmpty ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1))
                    : AppColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                group.isRequired
                    ? (selectedIds.isNotEmpty ? 'Wajib Terisi' : 'Wajib Pilih')
                    : 'Opsional',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: group.isRequired
                      ? (selectedIds.isNotEmpty ? AppColors.success : AppColors.error)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ...group.options.map((opt) {
          final isSelected = selectedIds.contains(opt.id);
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () => _toggleOption(group, opt),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.3) : AppColors.surface,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.allowMultiple
                          ? (isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                          : (isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 20.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        opt.nama,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      opt.harga > 0 ? '+${CurrencyFormatter.format(opt.harga)}' : 'Gratis',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: opt.harga > 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        SizedBox(height: 12.h),
      ],
    );
  }
}
