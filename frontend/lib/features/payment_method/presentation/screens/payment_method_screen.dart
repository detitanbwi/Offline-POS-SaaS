import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../application/payment_method_notifier.dart';
import '../../domain/models/payment_method.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog(BuildContext context, [PaymentMethod? method]) {
    final formKey = GlobalKey<_PaymentMethodFormState>();

    AppDialog.show(
      context: context,
      title: method == null ? 'Tambah Metode Pembayaran' : 'Ubah Metode Pembayaran',
      confirmText: 'Simpan',
      content: _PaymentMethodForm(
        key: formKey,
        method: method,
        onSubmit: (name, status) async {
          Navigator.pop(context); // close dialog

          bool success;
          if (method == null) {
            success = await ref.read(paymentMethodNotifierProvider.notifier).addPaymentMethod(name);
          } else {
            success = await ref.read(paymentMethodNotifierProvider.notifier).updatePaymentMethod(method.id, name, status);
          }

          if (!mounted) return;
          final state = ref.read(paymentMethodNotifierProvider);
          if (success) {
            AppSnackbar.showSuccess(
              context,
              method == null ? 'Metode pembayaran ditambahkan!' : 'Metode pembayaran diperbarui!',
            );
          } else if (state.errorMessage != null) {
            AppSnackbar.showError(context, state.errorMessage!);
          }
        },
      ),
      onConfirm: () {
        formKey.currentState?.submit();
      },
    );
  }

  void _confirmDelete(BuildContext context, PaymentMethod method) {
    if (method.id == 'pm-tunai') {
      AppSnackbar.showError(context, 'Metode pembayaran Tunai default tidak dapat dihapus.');
      return;
    }

    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Metode Pembayaran',
      itemName: method.nama,
      onDelete: () async {
        Navigator.pop(context); // close dialog
        final success = await ref.read(paymentMethodNotifierProvider.notifier).deletePaymentMethod(method.id);

        if (!mounted) return;
        final state = ref.read(paymentMethodNotifierProvider);
        if (success) {
          AppSnackbar.showSuccess(context, 'Metode pembayaran "${method.nama}" berhasil dihapus!');
        } else if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentMethodNotifierProvider);
    final notifier = ref.read(paymentMethodNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Metode Pembayaran'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_card),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: AppTextField(
                controller: _searchController,
                labelText: 'Cari Metode Pembayaran',
                prefixIcon: Icons.search,
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memproses data...')
                  : state.filteredMethods.isEmpty
                      ? AppEmptyState(
                          title: 'Metode Pembayaran Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada metode pembayaran yang cocok.'
                              : 'Silakan tambah metode pembayaran baru.',
                          icon: Icons.payments_outlined,
                          actionText: _searchController.text.isNotEmpty ? null : 'Tambah Metode Pembayaran',
                          onActionPressed: () => _showAddEditDialog(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredMethods.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final pm = state.filteredMethods[index];
                            final isDefault = pm.id == 'pm-tunai';
                            
                            return AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (pm.isActive ? AppColors.success : AppColors.disabled).withValues(alpha: 0.1),

                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      pm.iconData,
                                      color: pm.isActive ? AppColors.success : AppColors.disabled,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pm.nama,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 16,
                                            decoration: pm.isActive ? null : TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          pm.isActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: pm.isActive ? AppColors.success : AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Switch toggle active/inactive
                                  Switch(
                                    value: pm.isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: isDefault
                                        ? null // Cannot toggle default 'Tunai'
                                        : (active) async {
                                            final ok = await notifier.togglePaymentMethodStatus(pm.id, active);
                                            if (!ok && mounted) {
                                              final err = ref.read(paymentMethodNotifierProvider).errorMessage;
                                              if (err != null) AppSnackbar.showError(context, err);
                                            }
                                          },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                    onPressed: () => _showAddEditDialog(context, pm),
                                    tooltip: 'Ubah',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: isDefault ? AppColors.disabled : AppColors.error,
                                    ),
                                    onPressed: isDefault ? null : () => _confirmDelete(context, pm),
                                    tooltip: 'Hapus',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodForm extends StatefulWidget {
  final PaymentMethod? method;
  final Function(String name, int status) onSubmit;

  const _PaymentMethodForm({
    super.key,
    this.method,
    required this.onSubmit,
  });

  @override
  State<_PaymentMethodForm> createState() => _PaymentMethodFormState();
}

class _PaymentMethodFormState extends State<_PaymentMethodForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late int _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.method?.nama ?? '');
    _status = widget.method?.aktif ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            labelText: 'Nama Metode Pembayaran',
            hintText: 'Contoh: Gopay, Bank Mandiri, QRIS',
            prefixIcon: Icons.payment_rounded,
            readOnly: widget.method?.id == 'pm-tunai', // Default Tunai name cannot be edited
            validator: (v) => Validators.required(v, 'Nama Metode Pembayaran'),
          ),
          if (widget.method != null && widget.method?.id != 'pm-tunai') ...[
            const SizedBox(height: 16),
            const Text(
              'Status Aktif',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: _status,
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                      value: 1,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Nonaktif', style: TextStyle(fontSize: 14)),
                      value: 0,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_nameController.text.trim(), _status);
      return true;
    }
    return false;
  }
}
