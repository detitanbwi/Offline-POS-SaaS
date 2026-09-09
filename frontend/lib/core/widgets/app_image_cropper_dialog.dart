import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'app_button.dart';

class AppImageCropperDialog extends StatefulWidget {
  final File sourceImage;

  const AppImageCropperDialog({
    super.key,
    required this.sourceImage,
  });

  static Future<String?> show(BuildContext context, {required File sourceImage}) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppImageCropperDialog(sourceImage: sourceImage),
    );
  }

  @override
  State<AppImageCropperDialog> createState() => _AppImageCropperDialogState();
}

class _AppImageCropperDialogState extends State<AppImageCropperDialog> {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _cropAreaKey = GlobalKey();

  Uint8List? _imageBytes;
  img.Image? _decodedImage;
  bool _isLoading = true;
  bool _isProcessing = false;
  double _scale = 1.0;
  double _initialTx = 0.0;
  double _initialTy = 0.0;
  double _fittedW = 280.0;
  double _fittedH = 280.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.sourceImage.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Automatically correct phone camera EXIF orientation
        decoded = img.bakeOrientation(decoded);
      }

      if (decoded == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context, null);
        }
        return;
      }

      final bakedBytes = Uint8List.fromList(img.encodePng(decoded));

      // Calculate initial fitted size (BoxFit.cover) for 280x280 viewport
      const boxSize = 280.0;
      final origW = decoded.width.toDouble();
      final origH = decoded.height.toDouble();
      final scaleToCover = (boxSize / origW) > (boxSize / origH) ? (boxSize / origW) : (boxSize / origH);
      final fittedW = origW * scaleToCover;
      final fittedH = origH * scaleToCover;
      final initialTx = (boxSize - fittedW) / 2;
      final initialTy = (boxSize - fittedH) / 2;

      _transformController.value = Matrix4.identity()..translate(initialTx, initialTy);

      if (mounted) {
        setState(() {
          _imageBytes = bakedBytes;
          _decodedImage = decoded;
          _fittedW = fittedW;
          _fittedH = fittedH;
          _initialTx = initialTx;
          _initialTy = initialTy;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, null);
      }
    }
  }

  Future<void> _cropAndSave() async {
    if (_decodedImage == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final origImg = _decodedImage!;
      final matrix = _transformController.value;

      final currentScale = matrix.getMaxScaleOnAxis();
      final tx = matrix.getTranslation().x;
      final ty = matrix.getTranslation().y;

      final renderBox = _cropAreaKey.currentContext?.findRenderObject() as RenderBox?;
      final boxSize = renderBox?.size.width ?? 280.0;

      final origW = origImg.width.toDouble();
      final origH = origImg.height.toDouble();
      final scaleToCover = (boxSize / origW) > (boxSize / origH) ? (boxSize / origW) : (boxSize / origH);
      final fittedW = origW * scaleToCover;

      // Coordinate mapping: child fitted image space
      final cropLeftInFitted = -tx / currentScale;
      final cropTopInFitted = -ty / currentScale;
      final cropSizeInFitted = boxSize / currentScale;

      // Pixel ratio from fitted display size to original image pixels
      final pixelRatio = origW / fittedW;

      final cropX = (cropLeftInFitted * pixelRatio).round();
      final cropY = (cropTopInFitted * pixelRatio).round();
      final cropSize = (cropSizeInFitted * pixelRatio).round();

      img.Image cropped;
      if (cropX >= 0 && cropY >= 0 && cropX + cropSize <= origImg.width && cropY + cropSize <= origImg.height) {
        cropped = img.copyCrop(
          origImg,
          x: cropX,
          y: cropY,
          width: cropSize,
          height: cropSize,
        );
      } else {
        // If panned with margin, place onto square transparent canvas
        final targetCanvas = img.Image(width: cropSize, height: cropSize, numChannels: 4);
        img.fill(targetCanvas, color: img.ColorRgba8(255, 255, 255, 0));
        img.compositeImage(
          targetCanvas,
          origImg,
          dstX: -cropX,
          dstY: -cropY,
        );
        cropped = targetCanvas;
      }

      // Resize to 300x300 high-res bitmap
      final resized = img.copyResize(
        cropped,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.linear,
      );

      final pngBytes = img.encodePng(resized);

      final appDir = await getApplicationSupportDirectory();
      final logosDir = Directory(p.join(appDir.path, 'logos'));
      if (!await logosDir.exists()) {
        await logosDir.create(recursive: true);
      }

      final fileName = 'store_logo_${const Uuid().v4().substring(0, 8)}.png';
      final destFile = File(p.join(logosDir.path, fileName));
      await destFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, destFile.path);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = 280.w;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 480.w),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 16.w, 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.crop_rounded, color: AppColors.primary, size: 22.r),
                      SizedBox(width: 8.w),
                      Text(
                        'Sesuaikan Logo (1:1 Square)',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isProcessing ? null : () => Navigator.pop(context, null),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Cropper Canvas Area
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Container(
                  key: _cropAreaKey,
                  width: boxSize,
                  height: boxSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 1.0,
                              maxScale: 4.0,
                              boundaryMargin: EdgeInsets.all(boxSize),
                              onInteractionUpdate: (_) {
                                setState(() {
                                  _scale = _transformController.value.getMaxScaleOnAxis();
                                });
                              },
                              child: SizedBox(
                                width: _fittedW,
                                height: _fittedH,
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),

                            // 1:1 Rule of thirds grid overlay
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _GridOverlayPainter(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // Controls (Zoom Slider & Instruction)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  Text(
                    'Geser & cubit/zoom gambar untuk memposisikan logo di dalam kotak',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.zoom_out_rounded, size: 18.r, color: AppColors.textSecondary),
                      Expanded(
                        child: Slider(
                          value: _scale.clamp(1.0, 4.0),
                          min: 1.0,
                          max: 4.0,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _scale = val;
                              _transformController.value = Matrix4.identity()
                                ..translate(_initialTx, _initialTy)
                                ..scale(val);
                            });
                          },
                        ),
                      ),
                      Icon(Icons.zoom_in_rounded, size: 18.r, color: AppColors.textSecondary),
                      IconButton(
                        icon: const Icon(Icons.restart_alt_rounded),
                        tooltip: 'Reset Posisi',
                        onPressed: () {
                          setState(() {
                            _scale = 1.0;
                            _transformController.value = Matrix4.identity()..translate(_initialTx, _initialTy);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Dialog Footer Actions
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context, null),
                    child: const Text('Batal'),
                  ),
                  SizedBox(width: 12.w),
                  AppButton(
                    text: 'Potong & Pasang Logo',
                    isLoading: _isProcessing,
                    icon: Icons.check_rounded,
                    onPressed: _cropAndSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final oneThirdW = size.width / 3;
    final twoThirdW = 2 * size.width / 3;
    final oneThirdH = size.height / 3;
    final twoThirdH = 2 * size.height / 3;

    // Vertical lines
    canvas.drawLine(Offset(oneThirdW, 0), Offset(oneThirdW, size.height), paint);
    canvas.drawLine(Offset(twoThirdW, 0), Offset(twoThirdW, size.height), paint);

    // Horizontal lines
    canvas.drawLine(Offset(0, oneThirdH), Offset(size.width, oneThirdH), paint);
    canvas.drawLine(Offset(0, twoThirdH), Offset(size.width, twoThirdH), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
