import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ImageCompressionUtil {
  /// Crop image to 1:1 square centered and resize/compress to target size (default 256x256).
  static Future<String?> processStoreLogo(String sourcePath, {int targetSize = 256}) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Crop center square 1:1
      final minDimension = image.width < image.height ? image.width : image.height;
      final cropX = (image.width - minDimension) ~/ 2;
      final cropY = (image.height - minDimension) ~/ 2;

      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: minDimension,
        height: minDimension,
      );

      // Resize to targetSize
      final resized = img.copyResize(
        cropped,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.linear,
      );

      // Encode as PNG
      final pngBytes = img.encodePng(resized);

      // Save into app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final logosDir = Directory(p.join(appDir.path, 'logos'));
      if (!await logosDir.exists()) {
        await logosDir.create(recursive: true);
      }

      final fileName = 'store_logo_${const Uuid().v4().substring(0, 8)}.png';
      final destFile = File(p.join(logosDir.path, fileName));
      await destFile.writeAsBytes(pngBytes);

      return destFile.path;
    } catch (e) {
      debugPrint('Error processing store logo: $e');
      return null;
    }
  }
}
