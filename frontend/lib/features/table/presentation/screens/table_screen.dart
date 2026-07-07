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
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/utils/validators.dart';
import '../../application/table_notifier.dart';
import '../../domain/models/table.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
    });
  }

  void _showFormDialog(BuildContext context, {TableModel? table}) {
    final isEdit = table != null;
    final nameController = TextEditingController(text: table?.nama);
    final numberController = TextEditingController(text: table?.nomor);
    int selectedStatus = table?.status ?? 0;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: isEdit ? 'Ubah Data Meja' : 'Tambah Meja Baru',
              confirmText: 'Simpan',
              onConfirm: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final number = numberController.text.trim();

                  bool success;
                  if (isEdit) {
                    success = await ref.read(tableNotifierProvider.notifier).updateTable(
                          id: table.id,
                          nama: name,
                          nomor: number,
                          status: selectedStatus,
                        );
                  } else {
                    success = await ref.read(tableNotifierProvider.notifier).createTable(
                          nama: name,
                          nomor: number,
                        );
                  }

                  if (success) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    AppSnackbar.showSuccess(
                      context,
                      isEdit ? 'Data meja berhasil diperbarui.' : 'Meja baru berhasil ditambahkan.',
                    );
                  } else {
                    final err = ref.read(tableNotifierProvider).errorMessage;
                    if (err != null) {
                      AppSnackbar.showError(context, err);
                    }
                  }
                }
              },
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: nameController,
                      labelText: 'Nama Meja',
                      hintText: 'Contoh: Meja 01',
                      prefixIcon: Icons.table_restaurant_rounded,
                      validator: (v) => Validators.required(v, 'Nama Meja'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: numberController,
                      labelText: 'Nomor Urut Meja',
                      hintText: 'Contoh: 01',
                      prefixIcon: Icons.format_list_numbered_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.required(v, 'Nomor Urut Meja'),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status Meja',
                          prefixIcon: Icon(Icons.info_outline_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Kosong')),
                          DropdownMenuItem(value: 1, child: Text('Terisi')),
                          DropdownMenuItem(value: 2, child: Text('Reserved')),
                          DropdownMenuItem(value: 3, child: Text('Maintenance')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, TableModel table) {
    AppDialog.show(
      context: context,
      title: 'Hapus Meja',
      message: 'Apakah Anda yakin ingin menghapus "${table.nama}"? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      isDestructive: true,
      onConfirm: () async {
        final success = await ref.read(tableNotifierProvider.notifier).deleteTable(table.id);
        if (!context.mounted) return;
        Navigator.pop(context);
        if (success) {
          AppSnackbar.showSuccess(context, 'Meja "${table.nama}" berhasil dihapus.');
        } else {
          final err = ref.read(tableNotifierProvider).errorMessage;
          AppSnackbar.showError(context, err ?? 'Gagal menghapus meja.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tableNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kelola Master Meja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Meja',
            onPressed: () => _showFormDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading && state.allTables.isEmpty
            ? const AppLoading(message: 'Memuat data meja...')
            : state.allTables.isEmpty
                ? AppEmptyState(
                    title: 'Belum Ada Data Meja',
                    description: 'Silakan tambah meja baru untuk memulai manajemen meja restoran.',
                    icon: Icons.table_restaurant_rounded,
                    actionText: 'Tambah Meja',
                    onActionPressed: () => _showFormDialog(context),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(tableNotifierProvider.notifier).loadTables(),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Daftar Meja Restoran',
                            style: AppTypography.headlineLarge.copyWith(fontSize: 24),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Kelola meja makan untuk pesanan makan di tempat (Dine-in).',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          Expanded(
                            child: ResponsiveLayout(
                              mobile: _buildTableGrid(context, state.allTables, crossAxisCount: 2),
                              tablet: _buildTableGrid(context, state.allTables, crossAxisCount: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: state.allTables.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showFormDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Meja'),
            )
          : null,
    );
  }

  Widget _buildTableGrid(BuildContext context, List<TableModel> tables, {required int crossAxisCount}) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: 1.05,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        
        Color getStatusColor() {
          switch (table.status) {
            case 0:
              return AppColors.success;
            case 1:
              return AppColors.secondary;
            case 2:
              return AppColors.warning;
            case 3:
              return AppColors.error;
            default:
              return AppColors.disabled;
          }
        }

        return AppCard(
          borderSide: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      table.statusLabel,
                      style: TextStyle(
                        color: getStatusColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'No: ${table.nomor}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Center(
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                table.nama,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const Divider(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    onPressed: () => _showFormDialog(context, table: table),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    onPressed: () => _showDeleteDialog(context, table),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    tooltip: 'Hapus',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
