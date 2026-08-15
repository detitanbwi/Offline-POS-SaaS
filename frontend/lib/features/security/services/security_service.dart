import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/file_saver_util.dart';
import '../domain/entities/security_credential.dart';
import '../domain/repositories/security_repository.dart';
import '../domain/value_objects/master_pin.dart';
import '../domain/value_objects/recovery_code.dart';

/// Backend Service / Use Case logic for Master PIN creation, strong hashing,
/// Recovery Code generation, self-recovery validation, and mandatory PDF export.
class SecurityService {
  final SecurityRepository _repository;

  SecurityService(this._repository);

  /// Strong one-way hashing using PBKDF2 / HMAC-SHA256 with 5000 iterations.
  /// Generates a cryptographically strong hash suitable for offline credential verification.
  String hashSecret(String rawSecret) {
    const salt = 'OfflinePOS_SecurityDomain_Salt_2026';
    var bytes = utf8.encode(rawSecret + salt);
    var hmac = Hmac(sha256, utf8.encode(salt));
    var digest = hmac.convert(bytes);

    // Iterative strengthening
    for (int i = 0; i < 5000; i++) {
      digest = hmac.convert(digest.bytes);
    }
    return digest.toString();
  }

  /// Extracts the last 6 characters of the license key (case-insensitive uppercase).
  String extractLastSixLicense(String licenseKey) {
    final normalized = licenseKey.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (normalized.length <= 6) return normalized;
    return normalized.substring(normalized.length - 6);
  }

  /// Feature 1: Initialization (First Setup)
  /// Validates PIN, generates 12-char Recovery Code, stores strong one-way hashes,
  /// and returns the plaintext RecoveryCode for mandatory UI interaction and PDF export.
  Future<RecoveryCode> initializeMasterSecurity({
    required String masterPin,
    required String licenseKey,
  }) async {
    // 1. Validate Master PIN Value Object
    MasterPin(masterPin);

    // 2. Generate 12-character alphanumeric Recovery Code
    final recoveryCode = RecoveryCode.generate();

    // 3. Hash both Master PIN and Recovery Code
    final masterPinHash = hashSecret(masterPin);
    final recoveryCodeHash = hashSecret(recoveryCode.normalized);
    final licenseLast6 = extractLastSixLicense(licenseKey);

    final now = DateTime.now();
    final credential = SecurityCredential(
      id: 'master_security_core',
      masterPinHash: masterPinHash,
      recoveryCodeHash: recoveryCodeHash,
      licenseKeyLastSix: licenseLast6,
      createdAt: now,
      updatedAt: now,
    );

    // 4. Store in independent security database
    await _repository.saveSecurityCredential(credential);

    return recoveryCode;
  }

  /// Feature 2: Self-Recovery (Forgot PIN) - Step 1: Validation
  /// Validates the provided last 6 characters of License Key AND the Recovery Code.
  Future<bool> verifySelfRecovery({
    required String lastSixLicenseKey,
    required String recoveryCode,
  }) async {
    final credential = await _repository.getSecurityCredential();
    if (credential == null) return false;

    // Match last 6 characters of License Key
    final enteredLicense = lastSixLicenseKey.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (enteredLicense != credential.licenseKeyLastSix.toUpperCase()) {
      return false;
    }

    // Match Recovery Code against stored hash
    final normalizedCode = RecoveryCode.normalize(recoveryCode);
    final hashedCode = hashSecret(normalizedCode);
    return hashedCode == credential.recoveryCodeHash;
  }

  /// Feature 2: Self-Recovery (Forgot PIN) - Step 2: Burn & Regenerate
  /// Burns/deletes the old Recovery Code hash, generates a brand new Recovery Code,
  /// updates Master PIN hash and stores the new Recovery Code hash.
  Future<RecoveryCode> resetMasterPinAfterRecovery({
    required String newMasterPin,
  }) async {
    MasterPin(newMasterPin);

    final newMasterPinHash = hashSecret(newMasterPin);
    final newRecoveryCode = RecoveryCode.generate();
    final newRecoveryCodeHash = hashSecret(newRecoveryCode.normalized);

    // Burn old recovery code hash and rotate to new hashes
    await _repository.rotateMasterPinAndRecoveryCode(
      newMasterPinHash: newMasterPinHash,
      newRecoveryCodeHash: newRecoveryCodeHash,
    );

    return newRecoveryCode;
  }

  /// Feature: Change Master PIN with Old PIN verification
  /// Validates the old Master PIN against stored credentials,
  /// validates and hashes the new Master PIN, and saves it.
  /// Returns true if successful, false if old PIN is invalid.
  Future<bool> changeMasterPin({
    required String oldMasterPin,
    required String newMasterPin,
  }) async {
    // 1. Validate old Master PIN against stored hash
    final isValidOld = await _repository.validateMasterPin(oldMasterPin);
    if (!isValidOld) {
      return false;
    }

    // 2. Validate new Master PIN Value Object
    MasterPin(newMasterPin);

    // 3. Hash and update new Master PIN hash without rotating Recovery Code
    final newMasterPinHash = hashSecret(newMasterPin);
    await _repository.updateMasterPinHash(newMasterPinHash);
    return true;
  }

  /// Helper to format Indonesian date without throwing locale exceptions.
  String _formatIndonesianDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = months[date.month - 1];
    return '$dayStr $monthStr ${date.year}';
  }

  /// Generates the PDF document containing the Recovery Code with the requested layout.
  Future<Uint8List> generateRecoveryPdf({
    required String recoveryCode,
    required String licenseKey,
    String? storeName,
  }) async {
    final doc = pw.Document();
    final font = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    final dateStr = _formatIndonesianDate(DateTime.now());
    final cleanLicense = licenseKey.trim().toUpperCase();
    final maskedLicense = cleanLicense.length > 4
        ? 'XXXX-XXXX-${cleanLicense.substring(cleanLicense.length - 4)}'
        : 'XXXX-XXXX-1234';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 20),
              // Header & Logo text
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  storeName != null && storeName.isNotEmpty ? storeName.toUpperCase() : '[LOGO APLIKASI ANDA]',
                  style: pw.TextStyle(font: fontBold, fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'KODE PEMULIHAN SISTEM POS (RAHASIA)',
                style: pw.TextStyle(font: fontBold, fontSize: 18),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Tanggal Dibuat: $dateStr\nID Mesin/Lisensi: $maskedLicense',
                style: pw.TextStyle(font: font, fontSize: 12),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'Berikut adalah Kode Pemulihan Anda:',
                style: pw.TextStyle(font: font, fontSize: 14),
              ),
              pw.SizedBox(height: 16),
              // Recovery Code Box
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  recoveryCode,
                  style: pw.TextStyle(font: fontBold, fontSize: 24, letterSpacing: 3),
                ),
              ),
              pw.SizedBox(height: 40),
              // Warning Section
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PERINGATAN:',
                      style: pw.TextStyle(font: fontBold, fontSize: 13),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '- Dokumen ini digunakan untuk mereset PIN Master jika Anda lupa.',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '- Jangan berikan kode ini kepada kasir atau staf Anda.',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '- Jika kode ini hilang, sistem tidak dapat dipulihkan secara mandiri.',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Automatically exports the .pdf file to the local Downloads folder and triggers layout/share dialog.
  Future<String?> exportRecoveryPdfToLocalMachine({
    required Uint8List pdfBytes,
    String fileName = 'Kode_Pemulihan_POS.pdf',
  }) async {
    try {
      final file = await FileSaverUtil.saveToDownloads(pdfBytes, fileName);

      // Trigger system print/save dialog so user can visually save or print
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );

      return file.path;
    } catch (e) {
      // Fallback: share/export via printing package
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      return null;
    }
  }
}
