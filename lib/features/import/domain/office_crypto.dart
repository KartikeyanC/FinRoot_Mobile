import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';

/// Opening password-protected Excel files ([MS-OFFCRYPTO]), in pure Dart so
/// it is unit-tested on its own (`test/features/import/office_crypto_test.dart`).
///
/// - .xlsx with a password is an OLE2 compound file holding the zip
///   encrypted: Agile (AES, SHA-512, 100 000 spins; Excel 2010 and later) or
///   Standard (AES-128, SHA-1; Excel 2007).
/// - .xls with a password keeps its Workbook stream but encrypts the record
///   data: RC4 CryptoAPI (Excel 2002 and later) or the older RC4. XOR
///   obfuscation (Excel 95 style) is reported as unsupported.
///
/// The password is only used for the call; nothing keeps it.
enum OfficeEncryption {
  /// Not an encrypted Office file.
  none,
  xlsxAgile,
  xlsxStandard,
  xlsRc4,
  xlsRc4CryptoApi,

  /// .xls XOR obfuscation: not supported.
  xlsXor,

  /// Encrypted some other way (extensible encryption, a certificate, DES):
  /// not supported.
  other,
}

/// The password didn't open the file.
class OfficeWrongPasswordException implements Exception {
  const OfficeWrongPasswordException();
}

/// The file is encrypted in a way this reader doesn't handle.
class OfficeUnsupportedEncryptionException implements Exception {
  const OfficeUnsupportedEncryptionException(this.kind);
  final OfficeEncryption kind;
  @override
  String toString() => 'OfficeUnsupportedEncryptionException($kind)';
}

/// The container or its encryption records are damaged.
class OfficeFormatException implements Exception {
  const OfficeFormatException(this.message);
  final String message;
  @override
  String toString() => 'OfficeFormatException: $message';
}

const _ole2 = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

bool isCompoundFile(List<int> bytes) {
  if (bytes.length < 512) return false;
  for (var i = 0; i < _ole2.length; i++) {
    if (bytes[i] != _ole2[i]) return false;
  }
  return true;
}

Uint8List _u8(List<int> b) => b is Uint8List ? b : Uint8List.fromList(b);

/// How [bytes] is encrypted; [OfficeEncryption.none] for anything that isn't
/// an encrypted Office file (a plain .xls, a zip, text).
OfficeEncryption officeEncryptionOf(List<int> bytes) {
  if (!isCompoundFile(bytes)) return OfficeEncryption.none;
  final CompoundFile cfb;
  try {
    cfb = CompoundFile(_u8(bytes));
  } on OfficeFormatException {
    return OfficeEncryption.none;
  }
  final info = cfb.stream('EncryptionInfo');
  if (info != null && cfb.has('EncryptedPackage')) return _ooxmlKind(info);
  final book = cfb.stream('Workbook') ?? cfb.stream('Book');
  if (book == null) return OfficeEncryption.none;
  final fp = _filePass(book);
  return fp == null ? OfficeEncryption.none : _xlsKind(fp.data);
}

OfficeEncryption _ooxmlKind(Uint8List info) {
  if (info.length < 8) return OfficeEncryption.other;
  final d = ByteData.sublistView(info);
  final major = d.getUint16(0, Endian.little);
  final minor = d.getUint16(2, Endian.little);
  if (major == 4 && minor == 4) return OfficeEncryption.xlsxAgile;
  if ((major == 3 || major == 4) && minor == 2) {
    final flags = d.getUint32(4, Endian.little);
    // fCryptoAPI and fAES set, fExternal not.
    if (flags & 0x04 != 0 && flags & 0x20 != 0 && flags & 0x10 == 0) {
      return OfficeEncryption.xlsxStandard;
    }
  }
  return OfficeEncryption.other;
}

OfficeEncryption _xlsKind(Uint8List fp) {
  if (fp.length < 2) return OfficeEncryption.other;
  final d = ByteData.sublistView(fp);
  final type = d.getUint16(0, Endian.little);
  if (type == 0) return OfficeEncryption.xlsXor;
  if (type != 1 || fp.length < 6) return OfficeEncryption.other;
  final major = d.getUint16(2, Endian.little);
  final minor = d.getUint16(4, Endian.little);
  if (major == 1 && minor == 1) return OfficeEncryption.xlsRc4;
  if (major >= 2 && major <= 4 && minor == 2) {
    return OfficeEncryption.xlsRc4CryptoApi;
  }
  return OfficeEncryption.other;
}

/// Opens an encrypted Office file with [password]: for an .xlsx the plain
/// zip, for an .xls a compound file holding the decrypted Workbook stream
/// (both what `Excel.decodeBytes` reads). Throws
/// [OfficeWrongPasswordException], [OfficeUnsupportedEncryptionException] or
/// [OfficeFormatException].
Uint8List decryptOfficeFile(List<int> bytes, String password) {
  final kind = officeEncryptionOf(bytes);
  final cfb = CompoundFile(_u8(bytes));
  switch (kind) {
    case OfficeEncryption.xlsxAgile:
    case OfficeEncryption.xlsxStandard:
      return decryptOoxmlStreams(
        cfb.stream('EncryptionInfo')!,
        cfb.stream('EncryptedPackage')!,
        password,
      );
    case OfficeEncryption.xlsRc4:
    case OfficeEncryption.xlsRc4CryptoApi:
      final book = cfb.stream('Workbook') ?? cfb.stream('Book');
      return compoundFileWith('Workbook', decryptXlsWorkbook(book!, password));
    case OfficeEncryption.none:
      throw const OfficeFormatException('The file is not encrypted.');
    case OfficeEncryption.xlsXor:
    case OfficeEncryption.other:
      throw OfficeUnsupportedEncryptionException(kind);
  }
}

/// An encrypted .xlsx's EncryptionInfo and EncryptedPackage streams to the
/// plain zip (Agile or Standard, by the info's version).
Uint8List decryptOoxmlStreams(
  Uint8List info,
  Uint8List package,
  String password,
) => switch (_ooxmlKind(info)) {
  OfficeEncryption.xlsxAgile => _decryptAgile(info, package, password),
  OfficeEncryption.xlsxStandard => _decryptStandard(info, package, password),
  final k => throw OfficeUnsupportedEncryptionException(k),
};

// ---------------------------------------------------------------------------
// Hashing, AES, RC4.

// Hashes come from `crypto` (native 64-bit ints, several times faster than
// pointycastle's SHA-512 for the 100 000 Agile spins); AES from pointycastle.
Hash _digestNamed(String name) => switch (name.toUpperCase().replaceAll(
  '-',
  '',
)) {
  'SHA1' => sha1,
  'SHA256' => sha256,
  'SHA384' => sha384,
  'SHA512' => sha512,
  'MD5' => md5,
  _ => throw const OfficeUnsupportedEncryptionException(OfficeEncryption.other),
};

Uint8List _hash(Hash d, List<List<int>> parts) {
  final b = BytesBuilder(copy: false);
  for (final p in parts) {
    b.add(p);
  }
  return _u8(d.convert(b.takeBytes()).bytes);
}

/// H(salt + password), then H(iterator + H) [spins] times
/// ([MS-OFFCRYPTO] 2.3.4.7 and 2.3.4.11).
Uint8List _spunHash(Hash d, List<int> salt, String password, int spins) {
  var h = _hash(d, [salt, _utf16le(password)]);
  final buf = Uint8List(4 + h.length);
  final view = ByteData.sublistView(buf);
  for (var i = 0; i < spins; i++) {
    view.setUint32(0, i, Endian.little);
    buf.setRange(4, buf.length, h);
    h = _u8(d.convert(buf).bytes);
  }
  return h;
}

Uint8List _utf16le(String s) {
  final out = Uint8List(s.length * 2);
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    out[i * 2] = c & 0xFF;
    out[i * 2 + 1] = c >> 8;
  }
  return out;
}

Uint8List _le32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);

/// [b] cut or padded (with [pad]) to [n] bytes.
Uint8List _fit(Uint8List b, int n, {int pad = 0x36}) {
  if (b.length >= n) return Uint8List.sublistView(b, 0, n);
  return Uint8List(n)
    ..fillRange(0, n, pad)
    ..setRange(0, b.length, b);
}

bool _sameBytes(List<int> a, List<int> b, int n) {
  if (a.length < n || b.length < n) return false;
  var diff = 0;
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

Uint8List _aesCbcDecrypt(Uint8List key, Uint8List iv, Uint8List data) {
  final aes = AESEngine()..init(false, KeyParameter(key));
  final n = data.length - data.length % 16;
  final out = Uint8List(n);
  final prev = Uint8List.fromList(_fit(iv, 16));
  final block = Uint8List(16);
  for (var o = 0; o < n; o += 16) {
    aes.processBlock(data, o, block, 0);
    for (var i = 0; i < 16; i++) {
      out[o + i] = block[i] ^ prev[i];
    }
    prev.setRange(0, 16, data, o);
  }
  return out;
}

Uint8List _aesEcbDecrypt(Uint8List key, Uint8List data) {
  final aes = AESEngine()..init(false, KeyParameter(key));
  final n = data.length - data.length % 16;
  final out = Uint8List(n);
  for (var o = 0; o < n; o += 16) {
    aes.processBlock(data, o, out, o);
  }
  return out;
}

/// RC4, small enough to keep here (one key per 1024-byte block of an .xls).
class _Rc4 {
  _Rc4(List<int> key) {
    for (var i = 0; i < 256; i++) {
      _s[i] = i;
    }
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) & 0xFF;
      final t = _s[i];
      _s[i] = _s[j];
      _s[j] = t;
    }
  }

  final _s = Uint8List(256);
  int _i = 0;
  int _j = 0;

  /// XORs the key stream into [data] from [start] to [end], in place.
  void apply(Uint8List data, [int start = 0, int? end]) {
    final e = end ?? data.length;
    for (var k = start; k < e; k++) {
      _i = (_i + 1) & 0xFF;
      _j = (_j + _s[_i]) & 0xFF;
      final t = _s[_i];
      _s[_i] = _s[_j];
      _s[_j] = t;
      data[k] ^= _s[(_s[_i] + _s[_j]) & 0xFF];
    }
  }
}

int _u64(Uint8List b) {
  final d = ByteData.sublistView(b);
  return d.getUint32(0, Endian.little) +
      d.getUint32(4, Endian.little) * 0x100000000;
}

// ---------------------------------------------------------------------------
// .xlsx Agile encryption ([MS-OFFCRYPTO] 2.3.4.10–2.3.4.15).

Map<String, String> _attrs(String tag) => {
  for (final m in RegExp(r'([\w:]+)="([^"]*)"').allMatches(tag)) m[1]!: m[2]!,
};

Uint8List _decryptAgile(Uint8List info, Uint8List package, String password) {
  if (info.length < 8) throw const OfficeFormatException('EncryptionInfo');
  final xml = utf8.decode(info.sublist(8), allowMalformed: true);
  final keyDataTag = RegExp(r'<(?:\w+:)?keyData\b[^>]*>').firstMatch(xml)?[0];
  // The password key encryptor (a certificate one has no spinCount).
  final keyTag = RegExp(r'<(?:\w+:)?encryptedKey\b[^>]*>')
      .allMatches(xml)
      .map((m) => m[0]!)
      .where((t) => t.contains('spinCount'));
  if (keyDataTag == null || keyTag.isEmpty) {
    throw const OfficeUnsupportedEncryptionException(OfficeEncryption.other);
  }
  final kd = _attrs(keyDataTag);
  final ke = _attrs(keyTag.first);
  for (final a in [kd, ke]) {
    if ((a['cipherAlgorithm'] ?? 'AES') != 'AES' ||
        (a['cipherChaining'] ?? 'ChainingModeCBC') != 'ChainingModeCBC') {
      throw const OfficeUnsupportedEncryptionException(OfficeEncryption.other);
    }
  }
  Uint8List b64(Map<String, String> a, String k) {
    final v = a[k];
    if (v == null) throw OfficeFormatException('EncryptionInfo has no $k');
    return base64.decode(v);
  }

  final digest = _digestNamed(ke['hashAlgorithm'] ?? 'SHA512');
  final spin = int.tryParse(ke['spinCount'] ?? '') ?? 100000;
  final keyBytes = (int.tryParse(ke['keyBits'] ?? '') ?? 256) ~/ 8;
  final blockSize = int.tryParse(ke['blockSize'] ?? '') ?? 16;
  final salt = b64(ke, 'saltValue');

  final h = _spunHash(digest, salt, password, spin);
  Uint8List keyFor(List<int> blockKey) =>
      _fit(_hash(digest, [h, blockKey]), keyBytes);
  final iv = _fit(salt, blockSize);

  final verifierInput = _aesCbcDecrypt(
    keyFor(const [0xfe, 0xa7, 0xd2, 0x76, 0x3b, 0x4b, 0x9e, 0x79]),
    iv,
    b64(ke, 'encryptedVerifierHashInput'),
  );
  final verifierHash = _aesCbcDecrypt(
    keyFor(const [0xd7, 0xaa, 0x0f, 0x6d, 0x30, 0x61, 0x34, 0x4e]),
    iv,
    b64(ke, 'encryptedVerifierHashValue'),
  );
  final saltSize = int.tryParse(ke['saltSize'] ?? '') ?? salt.length;
  final expected = _hash(digest, [
    Uint8List.sublistView(
      verifierInput,
      0,
      math.min(saltSize, verifierInput.length),
    ),
  ]);
  if (!_sameBytes(expected, verifierHash, expected.length)) {
    throw const OfficeWrongPasswordException();
  }
  final secret = _fit(
    _aesCbcDecrypt(
      keyFor(const [0x14, 0x6e, 0x0b, 0xe7, 0xab, 0xac, 0xd0, 0xd6]),
      iv,
      b64(ke, 'encryptedKeyValue'),
    ),
    (int.tryParse(kd['keyBits'] ?? '') ?? keyBytes * 8) ~/ 8,
  );

  // The package: its size, then 4096-byte segments, each with its own IV.
  if (package.length < 8) throw const OfficeFormatException('package');
  final size = _u64(package);
  final kdDigest = _digestNamed(kd['hashAlgorithm'] ?? 'SHA512');
  final kdSalt = b64(kd, 'saltValue');
  final kdBlock = int.tryParse(kd['blockSize'] ?? '') ?? 16;
  final out = BytesBuilder(copy: false);
  var segment = 0;
  for (var o = 8; o < package.length && out.length < size; o += 4096) {
    final end = math.min(o + 4096, package.length);
    final segIv = _fit(_hash(kdDigest, [kdSalt, _le32(segment++)]), kdBlock);
    out.add(
      _aesCbcDecrypt(secret, segIv, Uint8List.sublistView(package, o, end)),
    );
  }
  final plain = out.takeBytes();
  if (plain.length < size) throw const OfficeFormatException('package size');
  return Uint8List.sublistView(plain, 0, size);
}

// ---------------------------------------------------------------------------
// .xlsx Standard encryption ([MS-OFFCRYPTO] 2.3.4.5–2.3.4.9).

/// The Standard-encryption AES key for [password] (2.3.4.7).
Uint8List standardKey(String password, Uint8List salt, int keyBytes) {
  final h = _spunHash(sha1, salt, password, 50000);
  final hFinal = _hash(sha1, [h, _le32(0)]);
  Uint8List derive(int fill) {
    final buf = Uint8List(64)..fillRange(0, 64, fill);
    for (var i = 0; i < hFinal.length; i++) {
      buf[i] ^= hFinal[i];
    }
    return _hash(sha1, [buf]);
  }

  final x = Uint8List.fromList([...derive(0x36), ...derive(0x5C)]);
  return Uint8List.sublistView(x, 0, keyBytes);
}

Uint8List _decryptStandard(Uint8List info, Uint8List package, String password) {
  final d = ByteData.sublistView(info);
  if (info.length < 12) throw const OfficeFormatException('EncryptionInfo');
  final headerSize = d.getUint32(8, Endian.little);
  const h = 12;
  final v = h + headerSize;
  if (info.length < v + 4 + 16 + 16 + 4 + 32) {
    throw const OfficeFormatException('EncryptionInfo');
  }
  final algId = d.getUint32(h + 8, Endian.little);
  var keyBits = d.getUint32(h + 16, Endian.little);
  if (algId != 0 && (algId < 0x660E || algId > 0x6610)) {
    throw const OfficeUnsupportedEncryptionException(OfficeEncryption.other);
  }
  if (keyBits == 0) keyBits = 128;
  final saltSize = d.getUint32(v, Endian.little);
  final salt = Uint8List.sublistView(info, v + 4, v + 4 + saltSize);
  final encVerifier = Uint8List.sublistView(
    info,
    v + 4 + saltSize,
    v + 20 + saltSize,
  );
  final hashSize = d.getUint32(v + 20 + saltSize, Endian.little);
  final encHash = Uint8List.sublistView(
    info,
    v + 24 + saltSize,
    math.min(info.length, v + 24 + saltSize + 32),
  );
  final key = standardKey(password, salt, keyBits ~/ 8);
  final verifier = _aesEcbDecrypt(key, encVerifier);
  final verifierHash = _aesEcbDecrypt(key, encHash);
  if (!_sameBytes(_hash(sha1, [verifier]), verifierHash, hashSize)) {
    throw const OfficeWrongPasswordException();
  }
  if (package.length < 8) throw const OfficeFormatException('package');
  final size = _u64(package);
  final plain = _aesEcbDecrypt(key, Uint8List.sublistView(package, 8));
  if (plain.length < size) throw const OfficeFormatException('package size');
  return Uint8List.sublistView(plain, 0, size);
}

// ---------------------------------------------------------------------------
// .xls RC4 and RC4 CryptoAPI ([MS-XLS] 2.2.10, [MS-OFFCRYPTO] 2.3.5–2.3.6).

class _Record {
  const _Record(this.opcode, this.offset, this.data);
  final int opcode;

  /// Where the record header starts in the stream.
  final int offset;
  final Uint8List data;
}

Iterable<_Record> _records(Uint8List stream) sync* {
  final d = ByteData.sublistView(stream);
  var pos = 0;
  while (pos + 4 <= stream.length) {
    final op = d.getUint16(pos, Endian.little);
    final len = d.getUint16(pos + 2, Endian.little);
    final end = math.min(pos + 4 + len, stream.length);
    yield _Record(op, pos, Uint8List.sublistView(stream, pos + 4, end));
    pos += 4 + len;
  }
}

/// The FILEPASS record of the workbook globals, or null.
_Record? _filePass(Uint8List book) {
  for (final r in _records(book)) {
    if (r.opcode == 0x2F) return r;
    if (r.opcode == 0x0A) return null; // EOF of the globals
  }
  return null;
}

/// Makes the RC4 key for a 1024-byte block of the stream.
typedef _BlockKey = Uint8List Function(int block);

_BlockKey _xlsKeys(Uint8List fp, String password) {
  final d = ByteData.sublistView(fp);
  final pw = _utf16le(password);
  final major = d.getUint16(2, Endian.little);
  final minor = d.getUint16(4, Endian.little);
  if (major == 1 && minor == 1) {
    // RC4 (Office 97/2000 compatible): MD5 based, 40-bit base key.
    if (fp.length < 54) throw const OfficeFormatException('FILEPASS');
    final salt = Uint8List.sublistView(fp, 6, 22);
    final h0 = Uint8List.sublistView(_hash(md5, [pw]), 0, 5);
    final buf = BytesBuilder();
    for (var i = 0; i < 16; i++) {
      buf
        ..add(h0)
        ..add(salt);
    }
    final base = Uint8List.sublistView(_hash(md5, [buf.takeBytes()]), 0, 5);
    Uint8List key(int block) => _hash(md5, [base, _le32(block)]);
    final verifier = Uint8List.fromList(fp.sublist(22, 38));
    final vHash = Uint8List.fromList(fp.sublist(38, 54));
    _Rc4(key(0))
      ..apply(verifier)
      ..apply(vHash);
    if (!_sameBytes(_hash(md5, [verifier]), vHash, 16)) {
      throw const OfficeWrongPasswordException();
    }
    return key;
  }
  // RC4 CryptoAPI: SHA-1 based.
  const h = 14;
  if (fp.length < h) throw const OfficeFormatException('FILEPASS');
  final headerSize = d.getUint32(10, Endian.little);
  final algIdHash = d.getUint32(h + 12, Endian.little);
  var keyBits = d.getUint32(h + 16, Endian.little);
  if (algIdHash != 0 && algIdHash != 0x8004) {
    throw const OfficeUnsupportedEncryptionException(OfficeEncryption.other);
  }
  if (keyBits == 0) keyBits = 40;
  final v = h + headerSize;
  if (fp.length < v + 4 + 16 + 16 + 4 + 20) {
    throw const OfficeFormatException('FILEPASS');
  }
  final saltSize = d.getUint32(v, Endian.little);
  final salt = Uint8List.sublistView(fp, v + 4, v + 4 + saltSize);
  final h0 = _hash(sha1, [salt, pw]);
  Uint8List key(int block) {
    final f = _hash(sha1, [h0, _le32(block)]);
    // A 40-bit key is used as 128 bits, zero padded.
    return keyBits == 40
        ? _fit(Uint8List.sublistView(f, 0, 5), 16, pad: 0)
        : Uint8List.sublistView(f, 0, keyBits ~/ 8);
  }

  final s = v + 4 + saltSize;
  final verifier = Uint8List.fromList(fp.sublist(s, s + 16));
  final hashSize = d.getUint32(s + 16, Endian.little);
  final vHash = Uint8List.fromList(fp.sublist(s + 20, s + 40));
  _Rc4(key(0))
    ..apply(verifier)
    ..apply(vHash);
  if (!_sameBytes(_hash(sha1, [verifier]), vHash, math.min(hashSize, 20))) {
    throw const OfficeWrongPasswordException();
  }
  return key;
}

/// Records whose data is never encrypted ([MS-XLS] 2.2.10): BOF, FILEPASS,
/// USREXCL, FILELOCK, INTERFACEHDR, RRDINFO, RRDHEAD.
const _plainRecords = {0x809, 0x2F, 0x194, 0x195, 0xE1, 0x196, 0x138};

/// A record no reader acts on, written over FILEPASS once the stream is
/// decrypted, so offsets elsewhere (BOUNDSHEET positions) stay right.
const _ignoredOpcode = 0x0160; // USESELFS

/// An encrypted .xls Workbook stream, decrypted with [password]: every
/// record's data in place, FILEPASS turned into a record readers skip.
Uint8List decryptXlsWorkbook(Uint8List book, String password) {
  final fp = _filePass(book);
  if (fp == null) throw const OfficeFormatException('No FILEPASS record.');
  final kind = _xlsKind(fp.data);
  if (kind != OfficeEncryption.xlsRc4 &&
      kind != OfficeEncryption.xlsRc4CryptoApi) {
    throw OfficeUnsupportedEncryptionException(kind);
  }
  final key = _xlsKeys(fp.data, password);

  // The key stream runs over the whole stream, re-keyed every 1024 bytes,
  // headers included; headers and some records are then put back as they
  // were, since only record data is encrypted.
  final plain = Uint8List.fromList(book);
  for (var o = 0; o < plain.length; o += 1024) {
    _Rc4(key(o ~/ 1024)).apply(plain, o, math.min(o + 1024, plain.length));
  }
  for (final r in _records(book)) {
    final dataAt = r.offset + 4;
    plain.setRange(r.offset, dataAt, book, r.offset);
    if (_plainRecords.contains(r.opcode)) {
      plain.setRange(dataAt, dataAt + r.data.length, r.data);
    } else if (r.opcode == 0x85 && r.data.length >= 4) {
      // BOUNDSHEET: the sheet's stream position is left in the clear.
      plain.setRange(dataAt, dataAt + 4, r.data);
    }
  }
  plain
    ..[fp.offset] = _ignoredOpcode & 0xFF
    ..[fp.offset + 1] = _ignoredOpcode >> 8;
  return plain;
}

// ---------------------------------------------------------------------------
// The compound file (OLE2 / [MS-CFB]) container.

const _endOfChain = 0xFFFFFFFE;
const _freeSect = 0xFFFFFFFF;
const _fatSect = 0xFFFFFFFD;
const _noStream = 0xFFFFFFFF;
const _maxRegSect = 0xFFFFFFFA;

class _Entry {
  const _Entry(this.name, this.type, this.start, this.size);
  final String name;
  final int type;
  final int start;
  final int size;
}

/// Read-only compound file: enough to pull a named stream out of it.
class CompoundFile {
  CompoundFile(this._b) : _d = ByteData.sublistView(_b) {
    if (!isCompoundFile(_b)) throw const OfficeFormatException('Not OLE2.');
    final shift = _d.getUint16(30, Endian.little);
    if (shift != 9 && shift != 12) {
      throw const OfficeFormatException('Bad sector size.');
    }
    _sector = 1 << shift;
    _sectors = _b.length ~/ _sector - 1;
    _miniCutoff = _d.getUint32(56, Endian.little);
    _readFat();
    _readDirectory(_d.getUint32(48, Endian.little));
    for (final s in _chain(_d.getUint32(60, Endian.little))) {
      for (var j = 0; j < _sector ~/ 4; j++) {
        _miniFat.add(_d.getUint32(_at(s) + j * 4, Endian.little));
      }
    }
  }

  final Uint8List _b;
  final ByteData _d;
  late final int _sector;
  late final int _sectors;
  late final int _miniCutoff;
  final _fat = <int>[];
  final _miniFat = <int>[];
  final _entries = <_Entry>[];
  final _miniSectors = <int>[];

  int _at(int sector) => (sector + 1) * _sector;
  int _u32(int o) => _d.getUint32(o, Endian.little);

  void _check(int s) {
    if (s > _maxRegSect || _at(s) + _sector > _b.length) {
      throw const OfficeFormatException('Sector out of range.');
    }
  }

  void _readFat() {
    final difat = [for (var i = 0; i < 109; i++) _u32(76 + i * 4)];
    var next = _u32(68);
    final per = _sector ~/ 4;
    for (var i = 0; i < _u32(72) && next <= _maxRegSect; i++) {
      _check(next);
      if (i > _sectors) throw const OfficeFormatException('DIFAT loop.');
      final base = _at(next);
      for (var j = 0; j < per - 1; j++) {
        difat.add(_u32(base + j * 4));
      }
      next = _u32(base + (per - 1) * 4);
    }
    for (final s in difat) {
      if (s > _maxRegSect) continue;
      _check(s);
      final base = _at(s);
      for (var j = 0; j < per; j++) {
        _fat.add(_u32(base + j * 4));
      }
    }
  }

  List<int> _chain(int first) {
    final out = <int>[];
    var s = first;
    while (s <= _maxRegSect) {
      _check(s);
      out.add(s);
      if (out.length > _sectors) throw const OfficeFormatException('Loop.');
      s = s < _fat.length ? _fat[s] : _endOfChain;
    }
    return out;
  }

  void _readDirectory(int first) {
    for (final s in _chain(first)) {
      final base = _at(s);
      for (var o = base; o + 128 <= base + _sector; o += 128) {
        final nameLen = _d.getUint16(o + 64, Endian.little);
        final type = _b[o + 66];
        if (type == 0 || nameLen < 2 || nameLen > 64) continue;
        final name = String.fromCharCodes([
          for (var i = 0; i < nameLen - 2; i += 2)
            _d.getUint16(o + i, Endian.little),
        ]);
        _entries.add(_Entry(name, type, _u32(o + 116), _u32(o + 120)));
      }
    }
    final root = _entries.where((e) => e.type == 5).firstOrNull;
    if (root != null) _miniSectors.addAll(_chain(root.start));
  }

  _Entry? _entry(String name) {
    final lower = name.toLowerCase();
    return _entries
        .where((e) => e.type == 2 && e.name.toLowerCase() == lower)
        .firstOrNull;
  }

  bool has(String name) => _entry(name) != null;

  /// The stream named [name] (any case), or null.
  Uint8List? stream(String name) {
    final e = _entry(name);
    if (e == null) return null;
    final out = Uint8List(e.size);
    var written = 0;
    if (e.size < _miniCutoff) {
      var mini = e.start;
      final per = _sector ~/ 64;
      var steps = 0;
      while (mini <= _maxRegSect && written < e.size) {
        if (++steps > _miniFat.length + 1) {
          throw const OfficeFormatException('Mini loop.');
        }
        final c = mini ~/ per;
        if (c >= _miniSectors.length) {
          throw const OfficeFormatException('Mini sector out of range.');
        }
        final off = _at(_miniSectors[c]) + (mini % per) * 64;
        final take = math.min(64, e.size - written);
        out.setRange(written, written + take, _b, off);
        written += take;
        if (mini >= _miniFat.length) break;
        mini = _miniFat[mini];
      }
    } else {
      for (final s in _chain(e.start)) {
        if (written >= e.size) break;
        final take = math.min(_sector, e.size - written);
        out.setRange(written, written + take, _b, _at(s));
        written += take;
      }
    }
    if (written < e.size) throw const OfficeFormatException('Truncated.');
    return out;
  }
}

/// A compound file holding one stream, [name] = [data], in 512-byte sectors.
///
/// The mini-stream cutoff is written as 0 so the stream is always read from
/// regular sectors, whatever its size.
Uint8List compoundFileWith(String name, Uint8List data) {
  const sector = 512;
  const per = sector ~/ 4;
  final dataSectors = (data.length + sector - 1) ~/ sector;
  var fatSectors = 1;
  while (fatSectors * per < fatSectors + 1 + dataSectors) {
    fatSectors++;
  }
  if (fatSectors > 109) {
    throw const OfficeFormatException('Workbook too large.');
  }
  final dirSector = fatSectors;
  final firstData = fatSectors + 1;
  final total = fatSectors + 1 + dataSectors;
  final out = Uint8List((total + 1) * sector);
  final d = ByteData.sublistView(out);
  void put32(int o, int v) => d.setUint32(o, v, Endian.little);
  void put16(int o, int v) => d.setUint16(o, v, Endian.little);

  out.setRange(0, 8, _ole2);
  put16(24, 0x3E);
  put16(26, 3);
  put16(28, 0xFFFE);
  put16(30, 9);
  put16(32, 6);
  put32(44, fatSectors);
  put32(48, dirSector);
  put32(56, 0); // mini-stream cutoff: see above
  put32(60, _endOfChain);
  put32(64, 0);
  put32(68, _endOfChain);
  put32(72, 0);
  for (var i = 0; i < 109; i++) {
    put32(76 + i * 4, i < fatSectors ? i : _freeSect);
  }

  int at(int s) => (s + 1) * sector;
  for (var i = 0; i < fatSectors * per; i++) {
    final int v;
    if (i < fatSectors) {
      v = _fatSect;
    } else if (i == dirSector) {
      v = _endOfChain;
    } else if (i >= firstData && i < total) {
      v = i == total - 1 ? _endOfChain : i + 1;
    } else {
      v = _freeSect;
    }
    put32(at(0) + i * 4, v);
  }

  void entry(int idx, String n, int type, int child, int start, int size) {
    final o = at(dirSector) + idx * 128;
    for (var i = 0; i < n.length; i++) {
      put16(o + i * 2, n.codeUnitAt(i));
    }
    put16(o + 64, n.isEmpty ? 0 : (n.length + 1) * 2);
    out[o + 66] = type;
    out[o + 67] = 1; // black
    put32(o + 68, _noStream);
    put32(o + 72, _noStream);
    put32(o + 76, child);
    put32(o + 116, start);
    put32(o + 120, size);
  }

  entry(0, 'Root Entry', 5, 1, _endOfChain, 0);
  entry(
    1,
    name,
    2,
    _noStream,
    dataSectors == 0 ? _endOfChain : firstData,
    data.length,
  );
  entry(2, '', 0, _noStream, 0, 0);
  entry(3, '', 0, _noStream, 0, 0);
  out.setRange(at(firstData), at(firstData) + data.length, data);
  return out;
}
