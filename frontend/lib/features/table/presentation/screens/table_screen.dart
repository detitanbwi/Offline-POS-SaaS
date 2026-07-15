import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../application/table_notifier.dart';
import '../../domain/models/table.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
    });
  }

  void _confirmBulkDelete(BuildContext context) {
    AppDialog.show(
      context: context,
      title: 'Hapus Masal Meja',
      message: 'Apakah Anda yakin ingin menghapus ${_selectedIds.length} meja terpilih? Meja yang masih terisi atau terkait transaksi tidak akan terhapus.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
      onConfirm: () async {
        Navigator.pop(context); // close dialog
        
        final idsToDelete = _selectedIds.toList();
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        
        int deletedCount = 0;
        int failedCount = 0;
        
        for (final id in idsToDelete) {
          final success = await ref.read(tableNotifierProvider.notifier).deleteTable(id);
          if (success) {
            deletedCount++;
          } else {
            failedCount++;
          }
        }
        
        if (!context.mounted) return;
        
        if (failedCount > 0) {
          AppSnackbar.showWarning(
            context,
            'Berhasil menghapus $deletedCount meja. $failedCount meja gagal dihapus (karena status meja terisi/terkait transaksi).',
          );
        } else {
          AppSnackbar.showSuccess(context, '$deletedCount meja berhasil dihapus.');
        }
      },
    );
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

                  if (!context.mounted) return;
                  if (success) {
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
                        initialValue: selectedStatus,
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

  void _showGenerateDialog(BuildContext context) {
    final countController = TextEditingController(text: '20');
    final formKey = GlobalKey<FormState>();
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: 'Generate Banyak Meja',
              confirmText: 'Generate',
              isLoading: isGenerating,
              onConfirm: () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isGenerating = true);
                  final count = int.parse(countController.text.trim());
                  final success = await ref.read(tableNotifierProvider.notifier).generateMultipleTables(count);
                  
                  if (success) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    AppSnackbar.showSuccess(
                      context,
                      '$count meja baru berhasil dibuat secara otomatis.',
                    );
                  } else {
                    setDialogState(() => isGenerating = false);
                    if (!context.mounted) return;
                    final err = ref.read(tableNotifierProvider).errorMessage;
                    AppSnackbar.showError(context, err ?? 'Gagal men-generate meja.');
                  }
                }
              },
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Masukkan total meja makan yang ingin dibuat secara otomatis (misal: 20). Nama meja akan menggunakan format "Meja 01", "Meja 02", dst.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: countController,
                      labelText: 'Jumlah Meja',
                      hintText: 'Contoh: 20',
                      prefixIcon: Icons.table_restaurant_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Jumlah meja harus diisi';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) {
                          return 'Masukkan angka positif yang valid';
                        }
                        if (n > 100) {
                          return 'Jumlah meja maksimal adalah 100 untuk sekali generate';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tableNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'Pilih Meja' : 'Kelola Master Meja'),
        actions: [
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist_rounded),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedIds.clear();
              });
            },
            tooltip: _isSelectionMode ? 'Batal' : 'Pilih Banyak',
          ),
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded),
              tooltip: 'Generate Meja',
              onPressed: () => _showGenerateDialog(context),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: state.isLoading && state.allTables.isEmpty
            ? const AppLoading(message: 'Memuat data meja...')
            : state.allTables.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppEmptyState(
                            title: 'Belum Ada Data Meja',
                            description: 'Silakan buat beberapa meja sekaligus secara otomatis.',
                            icon: Icons.table_restaurant_rounded,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppButton(
                                text: 'Generate Meja',
                                icon: Icons.playlist_add_rounded,
                                type: AppButtonType.primary,
                                onPressed: () => _showGenerateDialog(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          if (_isSelectionMode) ...[
                            Row(
                              children: [
                                Checkbox(
                                  value: state.allTables.isNotEmpty &&
                                      _selectedIds.length == state.allTables.length,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.addAll(state.allTables.map((t) => t.id));
                                      } else {
                                        _selectedIds.clear();
                                      }
                                    });
                                  },
                                ),
                                const Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                Text('${_selectedIds.length} Terpilih'),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _selectedIds.isEmpty
                                      ? null
                                      : () => _confirmBulkDelete(context),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  label: const Text('Hapus Terpilih', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                          ],
                          Expanded(
                            child: _buildTableGrid(context, state.allTables),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: state.allTables.isNotEmpty && !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Generate Meja'),
            )
          : null,
    );
  }

  Widget _buildTableGrid(BuildContext context, List<TableModel> tables) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = (width / 110).floor();
    if (crossAxisCount < 3) crossAxisCount = 3;
    if (crossAxisCount > 8) crossAxisCount = 8;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.s,
        crossAxisSpacing: AppSpacing.s,
        childAspectRatio: 0.76,
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

        final isSelected = _selectedIds.contains(table.id);

        return AppCard(
          onTap: _isSelectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(table.id);
                    } else {
                      _selectedIds.add(table.id);
                    }
                  });
                }
              : null,
          borderSide: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSelectionMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(table.id);
                            } else {
                              _selectedIds.remove(table.id);
                            }
                          });
                        },
                      ),
                    ),
                    Text(
                      'No: ${table.nomor}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: getStatusColor().withValues(alpha: 0.1),

                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        table.statusLabel,
                        style: TextStyle(
                          color: getStatusColor(),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'No: ${table.nomor}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              const Center(
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                table.nama,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(fontSize: 13.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Divider(height: 4),
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Center(
                    child: Text(
                      table.statusLabel,
                      style: TextStyle(
                        color: getStatusColor(),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                      onPressed: () => _showFormDialog(context, table: table),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(context, table),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
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
