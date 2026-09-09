import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One receipt photo staged for a scan.
class CapturedImage {
  CapturedImage({required this.bytes, required this.mimeType, String? id})
    : id = id ?? _uuid.v4();

  final String id;
  final Uint8List bytes;
  final String mimeType;

  /// base64 (no `data:` prefix) — the `scan-receipt` payload shape.
  String toBase64() => base64Encode(bytes);
}

const List<String> kAllowedScanMime = ['image/jpeg', 'image/png', 'image/webp'];
const int kMaxScanImageBytes = 8 * 1024 * 1024; // matches the Edge Function
const int kMaxScanImages = 5;

/// Guess a mime type from a file path extension (image_picker's `XFile.mimeType`
/// is null on several platforms).
String? mimeFromPath(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.webp')) return 'image/webp';
  return null;
}

class RejectedImage {
  const RejectedImage(this.reason);
  final String reason;
}

/// Validate newly picked images against the count / size / type limits (web
/// `validateNewFiles`). Returns what to keep and why the rest were dropped.
({List<CapturedImage> accepted, List<RejectedImage> rejected}) validateNewImages(
  int existingCount,
  List<CapturedImage> incoming,
) {
  final accepted = <CapturedImage>[];
  final rejected = <RejectedImage>[];
  var count = existingCount;
  for (final img in incoming) {
    if (count >= kMaxScanImages) {
      rejected.add(const RejectedImage('Only $kMaxScanImages images per scan'));
      continue;
    }
    if (!kAllowedScanMime.contains(img.mimeType)) {
      rejected.add(const RejectedImage('Use a JPG, PNG or WEBP photo'));
      continue;
    }
    if (img.bytes.lengthInBytes > kMaxScanImageBytes) {
      rejected.add(const RejectedImage('That image is larger than 8MB'));
      continue;
    }
    accepted.add(img);
    count++;
  }
  return (accepted: accepted, rejected: rejected);
}
