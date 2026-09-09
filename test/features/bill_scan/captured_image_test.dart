import 'dart:typed_data';

import 'package:finroot_mobile/features/bill_scan/domain/captured_image.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedImage _img(String mime, int bytes) =>
    CapturedImage(bytes: Uint8List(bytes), mimeType: mime);

void main() {
  test('accepts a normal JPEG', () {
    final v = validateNewImages(0, [_img('image/jpeg', 1024)]);
    expect(v.accepted, hasLength(1));
    expect(v.rejected, isEmpty);
  });

  test('rejects an unsupported type', () {
    final v = validateNewImages(0, [_img('image/gif', 1024)]);
    expect(v.accepted, isEmpty);
    expect(v.rejected.single.reason, contains('JPG'));
  });

  test('rejects an image over 8MB', () {
    final v = validateNewImages(0, [_img('image/png', 9 * 1024 * 1024)]);
    expect(v.accepted, isEmpty);
    expect(v.rejected.single.reason, contains('8MB'));
  });

  test('caps the running total at 5', () {
    final v = validateNewImages(4, [
      _img('image/jpeg', 10),
      _img('image/jpeg', 10),
    ]);
    expect(v.accepted, hasLength(1));
    expect(v.rejected.single.reason, contains('5 images'));
  });

  test('mimeFromPath covers the common extensions', () {
    expect(mimeFromPath('/x/IMG_1.JPG'), 'image/jpeg');
    expect(mimeFromPath('shot.png'), 'image/png');
    expect(mimeFromPath('a.webp'), 'image/webp');
    expect(mimeFromPath('a.heic'), isNull);
  });

  test('toBase64 round-trips', () {
    final img = _img('image/jpeg', 3);
    expect(img.toBase64(), isNotEmpty);
  });
}
