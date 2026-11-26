import 'dart:math';

import 'package:finroot_mobile/features/app_lock/pin_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pbkdf2Sha256Hex', () {
    // RFC 7914 §11 / well-known PBKDF2-HMAC-SHA256 vectors ("password",
    // "salt"); salt is passed as hex.
    test('matches the published vectors', () {
      expect(
        pbkdf2Sha256Hex('password', '73616c74', 1),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        pbkdf2Sha256Hex('password', '73616c74', 4096),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('PinRecord', () {
    test('the right PIN verifies, a wrong one does not', () async {
      final r = await PinRecord.create('482913', iterations: 1000);
      expect(await r.verify('482913'), isTrue);
      expect(await r.verify('482914'), isFalse);
      expect(await r.verify('48291'), isFalse);
      expect(await r.verify(''), isFalse);
    });

    test('is salted: the same PIN twice gives different records', () async {
      final a = await PinRecord.create('1234', iterations: 100);
      final b = await PinRecord.create('1234', iterations: 100);
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
    });

    test('round-trips as a v2 record', () async {
      final r = await PinRecord.create(
        '1234',
        iterations: 100,
        random: Random(7),
      );
      final raw = r.encode();
      expect(raw, contains('"v":2'));
      final back = PinRecord.tryParse(raw)!;
      expect(back.salt, r.salt);
      expect(back.iterations, 100);
      expect(back.hash, r.hash);
      expect(await back.verify('1234'), isTrue);
    });

    test('rejects anything that is not a v2 record', () {
      expect(PinRecord.tryParse(null), isNull);
      expect(PinRecord.tryParse(''), isNull);
      expect(PinRecord.tryParse('not json'), isNull);
      // A bare digest (the web's v1 shape) is not accepted here.
      expect(PinRecord.tryParse('a' * 64), isNull);
      expect(
        PinRecord.tryParse('{"v":1,"salt":"00","iter":1,"hash":"${'a' * 64}"}'),
        isNull,
      );
      expect(
        PinRecord.tryParse('{"v":2,"salt":"00","iter":0,"hash":"${'a' * 64}"}'),
        isNull,
      );
    });

    test('a record below the current cost asks to be re-hashed', () async {
      final low = await PinRecord.create('1234', iterations: 10);
      expect(low.needsRehash, isTrue);
      const current = PinRecord(
        salt: '00',
        iterations: PinRecord.currentIterations,
        hash: '',
      );
      expect(current.needsRehash, isFalse);
    });

    test('full cost runs off the UI thread in reasonable time', () async {
      final sw = Stopwatch()..start();
      final r = await PinRecord.create('123456');
      sw.stop();
      // ignore: avoid_print
      print(
        'PBKDF2 x${PinRecord.currentIterations}: ${sw.elapsedMilliseconds} ms',
      );
      expect(r.iterations, PinRecord.currentIterations);
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
    });
  });
}
