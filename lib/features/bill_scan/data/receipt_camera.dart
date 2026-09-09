import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/captured_image.dart';

/// Where a receipt photo comes from.
enum CaptureSource { camera, gallery }

/// A seam over `image_picker` so the controller and its tests never touch the
/// platform plugin. **Camera capture is device-unverified** (no Android SDK).
abstract interface class ReceiptCamera {
  /// One photo from the camera, or null if the user backed out.
  Future<CapturedImage?> capture();

  /// One or more photos from the gallery (empty if cancelled).
  Future<List<CapturedImage>> pickFromGallery();
}

class ImagePickerReceiptCamera implements ReceiptCamera {
  ImagePickerReceiptCamera([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final _log = AppLog.of('bill_scan.camera');

  // Downscale at pick time — a phone camera JPEG is comfortably under the
  // Edge Function's 8MB limit at these bounds, no separate image package.
  static const _maxWidth = 2000.0;
  static const _quality = 80;

  @override
  Future<CapturedImage?> capture() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxWidth,
        imageQuality: _quality,
      );
      return file == null ? null : await _toCaptured(file);
    } catch (error, stack) {
      _log.warning('camera capture failed (device-unverified)', error, stack);
      rethrow;
    }
  }

  @override
  Future<List<CapturedImage>> pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: _maxWidth,
        imageQuality: _quality,
        limit: kMaxScanImages,
      );
      return [for (final f in files) await _toCaptured(f)];
    } catch (error, stack) {
      _log.warning('gallery pick failed', error, stack);
      rethrow;
    }
  }

  Future<CapturedImage> _toCaptured(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? mimeFromPath(file.path) ?? 'image/jpeg';
    return CapturedImage(bytes: bytes, mimeType: mime);
  }
}

final receiptCameraProvider = Provider<ReceiptCamera>(
  (ref) => ImagePickerReceiptCamera(),
  name: 'receiptCamera',
);
