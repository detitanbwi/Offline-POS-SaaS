import 'dart:convert';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterConfigModel {
  final String id;
  final String name;
  final String? label;
  final String address;
  final String type; // 'cashier' or 'kitchen'
  final int paperSize; // 58 or 80
  final int charsPerLine; // 0 = Auto, or explicit number (e.g. 32, 48)
  final bool autoCut;
  final bool openDrawer;
  final String printDensity; // 'normal', 'light', 'dark'
  final bool autoReconnect;
  final bool isConnected;
  final List<String> categoryIds;
  final DateTime createdAt;

  const PrinterConfigModel({
    required this.id,
    required this.name,
    this.label,
    required this.address,
    required this.type,
    this.paperSize = 58,
    this.charsPerLine = 0,
    this.autoCut = false,
    this.openDrawer = false,
    this.printDensity = 'normal',
    this.autoReconnect = true,
    this.isConnected = false,
    this.categoryIds = const [],
    required this.createdAt,
  });

  String get displayName => (label != null && label!.trim().isNotEmpty) ? label!.trim() : name;

  bool get isCashier => type == 'cashier';
  bool get isKitchen => type == 'kitchen';

  /// Effective characters per line: if 0 (Auto), defaults to 32 for 58mm and 48 for 80mm
  int get effectiveCharsPerLine {
    if (charsPerLine > 0) return charsPerLine;
    return paperSize == 80 ? 48 : 32;
  }

  PaperSize get escPosPaperSize => paperSize == 80 ? PaperSize.mm80 : PaperSize.mm58;

  PrinterConfigModel copyWith({
    String? id,
    String? name,
    String? label,
    String? address,
    String? type,
    int? paperSize,
    int? charsPerLine,
    bool? autoCut,
    bool? openDrawer,
    String? printDensity,
    bool? autoReconnect,
    bool? isConnected,
    List<String>? categoryIds,
    DateTime? createdAt,
  }) {
    return PrinterConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      label: label ?? this.label,
      address: address ?? this.address,
      type: type ?? this.type,
      paperSize: paperSize ?? this.paperSize,
      charsPerLine: charsPerLine ?? this.charsPerLine,
      autoCut: autoCut ?? this.autoCut,
      openDrawer: openDrawer ?? this.openDrawer,
      printDensity: printDensity ?? this.printDensity,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      isConnected: isConnected ?? this.isConnected,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'address': address,
      'type': type,
      'paper_size': paperSize,
      'chars_per_line': charsPerLine,
      'auto_cut': autoCut ? 1 : 0,
      'open_drawer': openDrawer ? 1 : 0,
      'print_density': printDensity,
      'auto_reconnect': autoReconnect ? 1 : 0,
      'is_connected': isConnected ? 1 : 0,
      'category_ids': jsonEncode(categoryIds),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PrinterConfigModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedCategories = [];
    if (map['category_ids'] != null) {
      try {
        final decoded = jsonDecode(map['category_ids'] as String);
        if (decoded is List) {
          parsedCategories = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return PrinterConfigModel(
      id: map['id'] as String,
      name: map['name'] as String,
      label: map['label'] as String?,
      address: map['address'] as String,
      type: map['type'] as String,
      paperSize: (map['paper_size'] as int?) ?? 58,
      charsPerLine: (map['chars_per_line'] as int?) ?? 0,
      autoCut: ((map['auto_cut'] as int?) ?? 0) == 1,
      openDrawer: ((map['open_drawer'] as int?) ?? 0) == 1,
      printDensity: (map['print_density'] as String?) ?? 'normal',
      autoReconnect: ((map['auto_reconnect'] as int?) ?? 1) == 1,
      isConnected: ((map['is_connected'] as int?) ?? 0) == 1,
      categoryIds: parsedCategories,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
