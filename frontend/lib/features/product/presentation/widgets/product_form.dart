import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_modifier.dart';
import '../../../category/domain/models/category.dart';

class ProductForm extends StatefulWidget {
  final Product? product;
  final List<Category> categories;
  final List<Product> allProducts;
  final Function({
    required String nama,
    required String kategoriId,
    required double harga,
    required int stok,
    required int status,
    required bool isPackage,
    required List<PackageItem> packageItems,
    required List<ProductModifierGroup> modifierGroups,
    String? image,
  }) onSubmit;

  const ProductForm({
    super.key,
    this.product,
    required this.categories,
    this.allProducts = const [],
    required this.onSubmit,
  });

  @override
  State<ProductForm> createState() => ProductFormState();
}

class ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  String? _selectedCategoryId;
  late int _status;
  String? _imagePath;
  final _imagePicker = ImagePicker();

  bool _isAlwaysAvailable = false;
  bool _isPackage = false;
  List<PackageItem> _packageItems = [];
  List<ProductModifierGroup> _modifierGroups = [];

  // Temporary selection states for adding component
  String? _selectedComponentProductId;
  int _componentQty = 1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.nama ?? '');
    _priceController = TextEditingController(
      text: widget.product?.harga != null
          ? CurrencyFormatter.formatNumber(widget.product!.harga)
          : '',
    );
    _isPackage = widget.product?.isPackage ?? false;
    _packageItems = widget.product?.packageItems != null ? List.from(widget.product!.packageItems) : [];
    _modifierGroups = widget.product?.modifierGroups != null ? List.from(widget.product!.modifierGroups) : [];

    _isAlwaysAvailable = widget.product?.stok == -1;
    _stockController = TextEditingController(
      text: widget.product?.stok != null
          ? (widget.product!.stok == -1 ? '' : widget.product!.stok.toString())
          : '0',
    );
    _imagePath = widget.product?.image;

    // Set default category
    final activeCategories = widget.categories.where((c) => c.isActive).toList();
    if (widget.product != null) {
      _selectedCategoryId = widget.product!.kategoriId;
    } else if (activeCategories.isNotEmpty) {
      _selectedCategoryId = activeCategories.first.id;
    }

    _status = widget.product?.status ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final savedPath = await _saveLocalImage(picked.path);
        if (savedPath != null) {
          setState(() {
            _imagePath = savedPath;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih Sumber Gambar',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('Pilih dari Galeri', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('Ambil dari Kamera', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _saveLocalImage(String pickedFilePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'pos_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFilePath)}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(pickedFilePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving local image: $e');
      return null;
    }
  }

  void _addComponentProduct(Product product, int qty) {
    if (qty <= 0) return;
    final existingIdx = _packageItems.indexWhere((item) => item.productId == product.id);
    final now = DateTime.now();

    setState(() {
      if (existingIdx != -1) {
        final existing = _packageItems[existingIdx];
        _packageItems[existingIdx] = existing.copyWith(
          qty: existing.qty + qty,
          updatedAt: now,
        );
      } else {
        _packageItems.add(PackageItem(
          id: const Uuid().v4(),
          packageId: widget.product?.id ?? '',
          productId: product.id,
          productNama: product.nama,
          productHarga: product.harga,
          productStok: product.stok,
          kategoriId: product.kategoriId,
          kategoriNama: product.kategoriNama,
          qty: qty,
          createdAt: now,
          updatedAt: now,
        ));
      }
      _selectedComponentProductId = null;
      _componentQty = 1;
    });
  }

  void _removeComponentProduct(int index) {
    setState(() {
      _packageItems.removeAt(index);
    });
  }

  Future<void> _showComponentSearchPicker(BuildContext context, List<Product> availableComponents) async {
    final searchCtrl = TextEditingController();
    String searchQuery = '';

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = availableComponents.where((p) {
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                final nameMatch = p.nama.toLowerCase().contains(q);
                final catMatch = (p.kategoriNama ?? '').toLowerCase().contains(q);
                return nameMatch || catMatch;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar & Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilih Menu Komponen (${filtered.length})',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(modalContext),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Field
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Ketik nama atau kategori menu...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setModalState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => searchQuery = val.trim());
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.divider),

                  // Results list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'Menu tidak ditemukan',
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              final isSelected = p.id == _selectedComponentProductId;
                              final stockText = p.stok == -1 ? '∞ Non-Stock' : 'Stok: ${p.stok}';

                              return InkWell(
                                onTap: () => Navigator.pop(modalContext, p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: (p.isActive ? AppColors.primary : AppColors.disabled).withValues(alpha: 0.1),
                                        child: Icon(
                                          Icons.fastfood_rounded,
                                          size: 18,
                                          color: p.isActive ? AppColors.primary : AppColors.disabled,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.nama,
                                              style: AppTypography.titleMedium.copyWith(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${p.kategoriNama ?? "Tanpa Kategori"} • ${CurrencyFormatter.format(p.harga)}',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.chevron_right_rounded,
                                        size: 20,
                                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedComponentProductId = selected.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = widget.categories.where((c) => c.isActive || c.id == widget.product?.kategoriId).toList();
    
    // Filter available components: only non-packages and not the current product itself
    final availableComponents = widget.allProducts.where((p) {
      if (p.isPackage) return false;
      if (widget.product != null && p.id == widget.product!.id) return false;
      return true;
    }).toList();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Type Selector (Single vs Package)
            Text(
              'Tipe Produk',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            SizedBox(height: 6),
            // Type Selector
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isPackage = false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: !_isPackage ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: !_isPackage ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Produk Satuan',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: !_isPackage ? FontWeight.bold : FontWeight.normal,
                                  color: !_isPackage ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isPackage = true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isPackage ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 16,
                              color: _isPackage ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Paket Bundling',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: _isPackage ? FontWeight.bold : FontWeight.normal,
                                  color: _isPackage ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            AppTextField(
              controller: _nameController,
              labelText: _isPackage ? 'Nama Menu Paket' : 'Nama Produk',
              hintText: _isPackage ? 'Contoh: Paket Hemat Kenyang' : 'Contoh: Nasi Goreng Spesial',
              prefixIcon: _isPackage ? Icons.layers_outlined : Icons.shopping_bag_outlined,
              maxLength: 100,
              validator: (v) => Validators.required(v, _isPackage ? 'Nama Paket' : 'Nama Produk'),
            ),
            SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Kategori Menu',
                filled: true,
                fillColor: AppColors.surface,
                labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.category_outlined, color: AppColors.textSecondary),
              ),
              items: activeCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(
                    cat.nama,
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
              validator: (v) => v == null ? 'Kategori harus dipilih' : null,
            ),
            SizedBox(height: 16),

            Text(
              'Gambar Produk (Opsional)',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourcePicker(context),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(Icons.image_outlined, size: 40, color: AppColors.disabled),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                            onPressed: () {
                              setState(() {
                                _imagePath = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.primary),
                          SizedBox(height: 6),
                          Text(
                            'Pilih Gambar (Galeri / Kamera)',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Format didukung: JPG, PNG',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // If Package Mode: Composition Builder
            if (_isPackage) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Komposisi Item Paket',
                          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih produk-produk satuan yang menyusun paket ini:',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // Add component: Searchable Selector Box
                    InkWell(
                      onTap: () => _showComponentSearchPicker(context, availableComponents),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedComponentProductId != null
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedComponentProductId != null
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              _selectedComponentProductId != null
                                  ? Icons.check_circle_rounded
                                  : Icons.search_rounded,
                              color: _selectedComponentProductId != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedComponentProductId != null
                                    ? availableComponents
                                        .firstWhere(
                                          (p) => p.id == _selectedComponentProductId,
                                          orElse: () => Product(
                                            id: '',
                                            kategoriId: '',
                                            nama: 'Item Terpilih',
                                            harga: 0,
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                          ),
                                        )
                                        .nama
                                    : 'Cari & pilih menu komponen...',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: _selectedComponentProductId != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: _selectedComponentProductId != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedComponentProductId != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _selectedComponentProductId = null);
                                },
                              )
                            else
                              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quantity counter and Add Button Row
                    Row(
                      children: [
                        Text(
                          'Porsi:',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 14),
                                onPressed: _componentQty > 1 ? () => setState(() => _componentQty--) : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$_componentQty',
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 14),
                                onPressed: () => setState(() => _componentQty++),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _selectedComponentProductId == null
                                ? null
                                : () {
                                    final prod = availableComponents.firstWhere((p) => p.id == _selectedComponentProductId);
                                    _addComponentProduct(prod, _componentQty);
                                  },
                            icon: const Icon(Icons.add_circle_outline, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Tambah Item',
                                maxLines: 1,
                                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Added components list
                    if (_packageItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada komponen ditambahkan ke paket ini.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Column(
                        children: _packageItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final stockDesc = (item.productStok == null || item.productStok == -1)
                              ? 'Non-Stock'
                              : 'Stok: ${item.productStok} pcs';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      '${item.qty}x',
                                      style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productNama ?? 'Item Komponen',
                                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Harga Satuan: ${CurrencyFormatter.format(item.productHarga ?? 0)}',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () => _removeComponentProduct(idx),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Calculation summary of components
                      Builder(
                        builder: (context) {
                          double totalStandardPrice = 0.0;
                          for (var item in _packageItems) {
                            totalStandardPrice += (item.productHarga ?? 0) * item.qty;
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Harga Satuan Asli:', style: AppTypography.bodySmall),
                                Text(
                                  CurrencyFormatter.format(totalStandardPrice),
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            AppTextField(
              controller: _priceController,
              labelText: _isPackage ? 'Harga Jual Paket (Rupiah)' : 'Harga Jual (Rupiah)',
              hintText: 'Masukkan harga jual (contoh: 25.000)',
              prefixText: 'Rp ',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Harga Jual tidak boleh kosong';
                }
                final cleanValue = v.replaceAll('.', '');
                final numVal = num.tryParse(cleanValue);
                if (numVal == null) {
                  return 'Harga Jual harus berupa angka';
                }
                if (numVal < 0) {
                  return 'Harga Jual tidak boleh negatif';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Only show physical stock selection if NOT a package
            if (!_isPackage) ...[
              Text(
                'Jenis Inventori Produk',
                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAlwaysAvailable = false;
                            if (_stockController.text.trim().isEmpty) {
                              _stockController.text = '0';
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isAlwaysAvailable ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isAlwaysAvailable
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: !_isAlwaysAvailable ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: !_isAlwaysAvailable ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAlwaysAvailable = true;
                            _stockController.text = '';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isAlwaysAvailable ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isAlwaysAvailable
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.all_inclusive_rounded,
                                size: 18,
                                color: _isAlwaysAvailable ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Non Stock',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _isAlwaysAvailable ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                !_isAlwaysAvailable
                    ? '• Produk memiliki kuantitas fisik dan stok akan terpotong setiap transaksi.'
                    : '• Produk selalu tersedia (makanan/jasa) tanpa batasan kuantitas fisik.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
              ),
              const SizedBox(height: 14),
              if (!_isAlwaysAvailable) ...[
                AppTextField(
                  controller: _stockController,
                  labelText: 'Stok Awal (pcs)',
                  hintText: 'Masukkan jumlah stok fisik',
                  prefixIcon: Icons.warehouse_outlined,
                  keyboardType: TextInputType.number,
                  readOnly: widget.product != null && widget.product!.stok != -1,
                  validator: (v) {
                    if (_isAlwaysAvailable) return null;
                    return Validators.integer(v, 'Stok');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Section Varian & Topping (Menu Modifiers)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Varian & Topping Menu',
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pilihan ukuran, topping, level gula, dll.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showModifierGroupDialog(),
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Tambah'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  if (_modifierGroups.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._modifierGroups.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final group = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        group.nama,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: group.isRequired ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          group.isRequired ? 'Wajib' : 'Opsional',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: group.isRequired ? AppColors.primary : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          group.isSingleSelect ? 'Pilih 1' : 'Multi',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  color: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _showModifierGroupDialog(initialGroup: group, editIndex: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  color: AppColors.error,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () {
                                    setState(() {
                                      _modifierGroups.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (group.options.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: group.options.map((opt) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Text(
                                      '${opt.nama}${opt.harga > 0 ? ' (+${CurrencyFormatter.format(opt.harga)})' : ' (+Rp 0)'}',
                                      style: TextStyle(fontSize: 10.sp, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            if (widget.product != null) ...[
              Text(
                'Status Produk',
                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              SizedBox(height: 4),
              RadioGroup<int>(
                groupValue: _status,
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: Text('Aktif', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                        value: 1,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: Text('Nonaktif', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
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
      ),
    );
  }

  void _showModifierGroupDialog({ProductModifierGroup? initialGroup, int? editIndex}) {
    final nameCtrl = TextEditingController(text: initialGroup?.nama ?? '');
    final scrollController = ScrollController();
    bool isRequired = initialGroup?.isRequired ?? false;
    bool isSingleSelect = initialGroup?.isSingleSelect ?? true;
    final List<Map<String, dynamic>> optionsList = (initialGroup != null && initialGroup.options.isNotEmpty)
        ? initialGroup.options
            .map<Map<String, dynamic>>((o) => <String, dynamic>{
                  'id': (o.id.isNotEmpty ? o.id : null) ?? const Uuid().v4(),
                  'nameCtrl': TextEditingController(text: o.nama),
                  'priceCtrl': TextEditingController(text: o.harga > 0 ? CurrencyFormatter.formatNumber(o.harga) : '0'),
                })
            .toList()
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'id': const Uuid().v4(),
              'nameCtrl': TextEditingController(text: ''),
              'priceCtrl': TextEditingController(text: '0'),
            }
          ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 500 ? 12.0 : 32.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void addNewOption() {
              setDialogState(() {
                optionsList.add(<String, dynamic>{
                  'id': const Uuid().v4(),
                  'nameCtrl': TextEditingController(text: ''),
                  'priceCtrl': TextEditingController(text: '0'),
                });
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients && scrollController.position.hasContentDimensions) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });
            }

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.radius24,
              ),
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.l,
                right: AppSpacing.l,
                top: AppSpacing.l,
                bottom: AppSpacing.s,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.s,
              ),
              actionsPadding: const EdgeInsets.all(AppSpacing.l),
              title: Text(
                initialGroup == null ? 'Tambah Kelompok Varian / Topping' : 'Ubah Kelompok Varian',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                  minWidth: screenWidth < 500 ? (screenWidth - 64) : 460,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: nameCtrl,
                        labelText: 'Nama Kelompok Varian',
                        hintText: 'Contoh: Ukuran / Topping / Level Pedas',
                        prefixIcon: Icons.label_outline,
                        maxLength: 50,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => isSingleSelect = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSingleSelect ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSingleSelect ? AppColors.primary : AppColors.divider),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.radio_button_checked, size: 16, color: isSingleSelect ? AppColors.primary : AppColors.textSecondary),
                                    const SizedBox(height: 4),
                                    Text('Pilih 1 (Radio)', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: isSingleSelect ? AppColors.primary : AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => isSingleSelect = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: !isSingleSelect ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: !isSingleSelect ? AppColors.primary : AppColors.divider),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.check_box_outlined, size: 16, color: !isSingleSelect ? AppColors.primary : AppColors.textSecondary),
                                    const SizedBox(height: 4),
                                    Text('Pilih Banyak (Topping)', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: !isSingleSelect ? AppColors.primary : AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text('Wajib Dipilih Oleh Pelanggan', style: AppTypography.titleMedium.copyWith(fontSize: 12.sp)),
                        subtitle: Text(
                          isRequired ? 'Pelanggan harus memilih minimal 1 opsi' : 'Pelanggan bebas tidak memilih opsi ini',
                          style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
                        ),
                        value: isRequired,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => isRequired = val),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Daftar Opsi Varian',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: addNewOption,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Tambah Opsi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...optionsList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final optMap = entry.value;
                        final optKey = (optMap['id'] as String?)?.isNotEmpty == true
                            ? optMap['id'] as String
                            : 'opt_$idx';
                        return Padding(
                          key: ValueKey(optKey),
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: optMap['nameCtrl'] as TextEditingController,
                                  maxLength: 50,
                                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  decoration: InputDecoration(
                                    labelText: 'Nama Opsi #${idx + 1}',
                                    hintText: 'Maks. 50 karakter',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: optMap['priceCtrl'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '+ Harga',
                                    prefixText: 'Rp ',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (optionsList.length > 1) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    setDialogState(() {
                                      optionsList.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final groupName = nameCtrl.text.trim();
                    if (groupName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama kelompok varian tidak boleh kosong'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    if (groupName.length > 50) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama kelompok varian maksimal 50 karakter'), backgroundColor: AppColors.error),
                      );
                      return;
                    }

                    final validOptions = <ProductModifierOption>[];
                    for (var optMap in optionsList) {
                      final n = (optMap['nameCtrl'] as TextEditingController).text.trim();
                      if (n.isNotEmpty) {
                        if (n.length > 50) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Nama opsi "$n" melebihi batas 50 karakter'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        final pStr = (optMap['priceCtrl'] as TextEditingController).text.replaceAll('.', '');
                        final pr = double.tryParse(pStr) ?? 0.0;
                        validOptions.add(ProductModifierOption(
                          id: optMap['id'] as String? ?? const Uuid().v4(),
                          groupId: initialGroup?.id ?? '',
                          nama: n,
                          harga: pr,
                          sortOrder: validOptions.length,
                        ));
                      }
                    }

                    if (validOptions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Minimal harus ada 1 nama opsi varian yang diisi'), backgroundColor: AppColors.error),
                      );
                      return;
                    }

                    final newGroup = ProductModifierGroup(
                      id: initialGroup?.id ?? const Uuid().v4(),
                      productId: widget.product?.id ?? '',
                      nama: groupName,
                      isRequired: isRequired,
                      allowMultiple: !isSingleSelect,
                      minSelect: isRequired ? 1 : 0,
                      maxSelect: isSingleSelect ? 1 : 99,
                      sortOrder: editIndex ?? _modifierGroups.length,
                      options: validOptions,
                    );

                    setState(() {
                      if (editIndex != null && editIndex < _modifierGroups.length) {
                        _modifierGroups[editIndex] = newGroup;
                      } else {
                        _modifierGroups.add(newGroup);
                      }
                    });

                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategoryId == null) return false;

      if (_isPackage && _packageItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk paket bundling harus memiliki minimal 1 item komponen!'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }

      final cleanPriceText = _priceController.text.replaceAll('.', '');
      final double harga = double.tryParse(cleanPriceText) ?? 0.0;
      
      final int stockVal = _isPackage ? 0 : (_isAlwaysAvailable ? -1 : (int.tryParse(_stockController.text) ?? 0));

      widget.onSubmit(
        nama: _nameController.text.trim(),
        kategoriId: _selectedCategoryId!,
        harga: harga,
        stok: stockVal,
        status: _status,
        isPackage: _isPackage,
        packageItems: _packageItems,
        modifierGroups: _modifierGroups,
        image: _imagePath,
      );
      return true;
    }
    return false;
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  final int maxDigits;
  RupiahInputFormatter({this.maxDigits = 10});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
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
