import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The stored FinRoot PIN: a versioned PBKDF2-SHA256 record, the same shape
/// as the web app's `appLock.ts` (`{v:2, salt, iter, hash}`), never a bare
/// digest (web BUG-091).
///
/// ⚠️ This raises the price of a guess; it does NOT make a 4–6 digit secret
/// strong. Six digits is ~20 bits — anyone holding the record can still walk
/// the whole space. The app lock is a curtain over the screen; RLS on the
/// server is the real gate. The mitigations that matter are the 6-digit
/// default and the "don't reuse these digits" line where the PIN is chosen.
class PinRecord {
  const PinRecord({
    required this.salt,
    required this.iterations,
    required this.hash,
  });

  /// The OWASP figure for PBKDF2-SHA256, as on the web. The record carries
  /// its own count, so raising this later costs nothing: [needsRehash] tells
  /// the caller to re-store the record the next time the right PIN is typed.
  static const currentIterations = 310000;
  static const version = 2;

  final String salt; // hex, 16 random bytes
  final int iterations;
  final String hash; // hex, 32 bytes

  bool get needsRehash => iterations < currentIterations;

  /// A new record for [pin] with a fresh random salt. Runs the KDF on a
  /// background isolate so the UI does not stall.
  static Future<PinRecord> create(
    String pin, {
    int iterations = currentIterations,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = _toHex(List<int>.generate(16, (_) => rng.nextInt(256)));
    final hash = await _deriveOffThread(pin, salt, iterations);
    return PinRecord(salt: salt, iterations: iterations, hash: hash);
  }

  /// True when [pin] is the PIN this record was made from.
  Future<bool> verify(String pin) async {
    final candidate = await _deriveOffThread(pin, salt, iterations);
    return _constantTimeEquals(candidate, hash);
  }

  String encode() => jsonEncode({
    'v': version,
    'salt': salt,
    'iter': iterations,
    'hash': hash,
  });

  /// Null for anything that is not a well-formed v2 record.
  static PinRecord? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final v = m['v'];
      final salt = m['salt'];
      final iter = m['iter'];
      final hash = m['hash'];
      if (v != version || salt is! String || hash is! String || iter is! int) {
        return null;
      }
      if (iter <= 0 || salt.isEmpty || hash.length != 64) return null;
      return PinRecord(salt: salt, iterations: iter, hash: hash);
    } on FormatException {
      return null;
    }
  }
}

Future<String> _deriveOffThread(String pin, String saltHex, int iterations) {
  // Small counts (tests) are not worth an isolate.
  if (iterations < 5000) {
    return Future.value(pbkdf2Sha256Hex(pin, saltHex, iterations));
  }
  return Isolate.run(() => pbkdf2Sha256Hex(pin, saltHex, iterations));
}

/// PBKDF2-HMAC-SHA256 (RFC 8018), one 32-byte block, as hex. Pure Dart on
/// top of `package:crypto`'s HMAC; matches WebCrypto's `deriveBits(…, 256)`.
String pbkdf2Sha256Hex(String password, String saltHex, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final salt = _fromHex(saltHex);
  final first = Uint8List(salt.length + 4)
    ..setAll(0, salt)
    ..setAll(salt.length, const [0, 0, 0, 1]); // block index 1, big-endian
  var u = hmac.convert(first).bytes;
  final t = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return _toHex(t);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _fromHex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
