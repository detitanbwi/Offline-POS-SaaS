import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/category/domain/models/category.dart';
import 'package:frontend/features/product/domain/models/product.dart';
import 'package:frontend/features/product/domain/models/product_modifier.dart';
import 'package:frontend/features/product/presentation/widgets/product_form.dart';

void main() {
  testWidgets('Modifier group edit dialog allows adding new option, editing, and saving', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final existingGroup = ProductModifierGroup(
      id: 'grp-1',
      productId: 'prod-1',
      nama: 'Varian',
      isRequired: false,
      allowMultiple: false,
      minSelect: 0,
      maxSelect: 1,
      options: [
        ProductModifierOption(
          id: 'opt-1',
          groupId: 'grp-1',
          nama: 'Biasa',
          harga: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final product = Product(
      id: 'prod-1',
      kategoriId: 'cat-1',
      nama: 'Test Product',
      harga: 10000,
      stok: 10,
      modifierGroups: [existingGroup],
      createdAt: now,
      updatedAt: now,
    );

    final categories = [
      Category(
        id: 'cat-1',
        nama: 'Makanan',
        status: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    List<ProductModifierGroup>? savedModifierGroups;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            home: Scaffold(
              body: ProductForm(
                product: product,
                categories: categories,
                onSubmit: ({
                  required String nama,
                  required String kategoriId,
                  required double harga,
                  required int stok,
                  required int status,
                  required bool isPackage,
                  required List<PackageItem> packageItems,
                  required List<ProductModifierGroup> modifierGroups,
                  String? image,
                }) {
                  savedModifierGroups = modifierGroups;
                },
              ),
            ),
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    // Find the edit button for the modifier group
    final editButtonFinder = find.byIcon(Icons.edit_outlined);
    expect(editButtonFinder, findsOneWidget);

    await tester.ensureVisible(editButtonFinder);
    await tester.pumpAndSettle();

    // Tap edit button to open Ubah Kelompok Varian dialog
    await tester.tap(editButtonFinder);
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.text('Ubah Kelompok Varian'), findsOneWidget);
    expect(find.text('Nama Opsi #1'), findsOneWidget);
    expect(find.text('Nama Opsi #2'), findsNothing);

    // Find and tap "Tambah Opsi" button
    final addOptionButtonFinder = find.widgetWithText(ElevatedButton, 'Tambah Opsi');
    expect(addOptionButtonFinder, findsOneWidget);

    // Click Tambah Opsi 1st time
    await tester.tap(addOptionButtonFinder);
    await tester.pumpAndSettle();

    // Verify Nama Opsi #2 is added
    expect(find.text('Nama Opsi #2'), findsOneWidget);

    // Click Tambah Opsi 2nd time
    await tester.tap(addOptionButtonFinder);
    await tester.pumpAndSettle();

    // Verify Nama Opsi #3 is added
    expect(find.text('Nama Opsi #3'), findsOneWidget);

    // Enter name for Option #2 and Option #3
    final opt2Field = find.widgetWithText(TextFormField, 'Nama Opsi #2');
    final opt3Field = find.widgetWithText(TextFormField, 'Nama Opsi #3');
    await tester.enterText(opt2Field, 'Pedas');
    await tester.enterText(opt3Field, 'Ekstra Pedas');
    await tester.pumpAndSettle();

    // Save dialog
    final saveDialogButton = find.widgetWithText(ElevatedButton, 'Simpan');
    await tester.tap(saveDialogButton);
    await tester.pumpAndSettle();

    // Verify dialog closed and ProductForm now has the updated options
    expect(find.text('Ubah Kelompok Varian'), findsNothing);
    expect(find.text('Biasa (+Rp 0)'), findsOneWidget);
    expect(find.text('Pedas (+Rp 0)'), findsOneWidget);
    expect(find.text('Ekstra Pedas (+Rp 0)'), findsOneWidget);
  });
}
