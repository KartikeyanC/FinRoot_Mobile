import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:finroot_mobile/features/import/domain/office_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Password-protected copies of statement.xls / statement.xlsx, password
// "Fin@2026":
// - statement_protected.xlsx: Excel 2016 "Encrypt with Password" (Agile,
//   AES-256, SHA-512, 100 000 spins).
// - statement_protected.xls: Excel 2016, Excel 97-2003 format (RC4
//   CryptoAPI).
// - statement_protected_rc4.xls: Office 97/2000 RC4, built by a stdlib
//   Python script and checked by opening it in Excel with the password (and
//   Excel refusing a wrong one).
// - statement_standard.info / .package: the EncryptionInfo and
//   EncryptedPackage streams of statement.xlsx under ECMA-376 Standard
//   encryption (AES-128, SHA-1), from the same script.
// - statement_xor.xls: XOR obfuscation ([MS-OFFCRYPTO] 2.3.7, FILEPASS
//   wEncryptionType 0), which only Excel 2002/2003 save. Built from
//   statement.xls by a stdlib Python script written from the 2.3.7.1–2.3.7.3
//   pseudocode on Microsoft Learn (FILEPASS put after the BOF, the stream
//   positions in BOUNDSHEET, INDEX and EXTSST moved to match). Checked in
//   Excel 2016 (16.0, through COM): it opens with "Fin@2026" with every cell
//   of the first sheet the same as statement.xls, and "Fin@2025" is refused.
//
// Workbooks with no password to open but encrypted with Excel's built-in
// "VelvetSweatshop" (each checked by Excel 2016 opening it with no password
// prompt, cells the same as the plain file):
// - statement_velvet.xls: Excel 2016 through COM, statement.xls with its
//   workbook structure and first sheet protected with "Fin@2026", saved as
//   Excel 97-2003. Excel encrypted it by itself, with Office 97/2000 RC4.
// - statement_velvet_cryptoapi.xls: Excel 2016, statement.xls saved with
//   "VelvetSweatshop" as its password to open (RC4 CryptoAPI).
// - statement_velvet.xlsx: Excel 2016, statement.xlsx saved with
//   "VelvetSweatshop" as its password to open (Agile).
// - statement_xor_velvet.xls: XOR obfuscation with "VelvetSweatshop", from
//   the Python script above.
// - statement_writeres.xls: Excel 2016, statement.xls with only a password
//   to modify ("Fin@2026"): Excel doesn't encrypt those (WRITEPROT and
//   FILESHARING records, no FILEPASS).
// protected.xls (older fixture) has a password we don't know.
Uint8List _fixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

const _pw = 'Fin@2026';

List<Object> _summary(List<List<Object?>> table) {
  final p = parseImportTable(table);
  return [for (final r in p.rows) r.importHash, p.skipped, p.undated];
}

/// The (opcode, data) records of [book], a BIFF8 Workbook stream.
Iterable<(int, Uint8List)> _records(Uint8List book) sync* {
  final d = ByteData.sublistView(book);
  for (var pos = 0; pos + 4 <= book.length;) {
    final len = d.getUint16(pos + 2, Endian.little);
    yield (
      d.getUint16(pos, Endian.little),
      Uint8List.sublistView(book, pos + 4, pos + 4 + len),
    );
    pos += 4 + len;
  }
}

/// statement_protected.xls's Workbook stream with its FILEPASS changed by
/// [patch] (given the FILEPASS data), as a compound file.
Uint8List _patchedFilePass(void Function(ByteData fp) patch) {
  final book = CompoundFile(_fixture('statement_protected.xls'))
      .stream('Workbook')!;
  final copy = Uint8List.fromList(book);
  // FILEPASS follows the 20-byte BOF record.
  expect(ByteData.sublistView(copy).getUint16(20, Endian.little), 0x2F);
  patch(ByteData.sublistView(copy, 24));
  return compoundFileWith('Workbook', copy);
}

/// An Agile EncryptionInfo stream around [xml].
Uint8List _agileInfo(String xml) => Uint8List.fromList([
  0x04, 0x00, 0x04, 0x00, 0x40, 0x00, 0x00, 0x00, //
  ...utf8.encode(xml),
]);

Matcher _unsupported(OfficeEncryption kind, [String? detail]) => throwsA(
  isA<UnsupportedSpreadsheetProtectionException>()
      .having((e) => e.kind, 'kind', kind)
      .having((e) => e.detail, 'detail', detail),
);

void main() {
  test('kinds of protection', () {
    for (final (name, kind) in [
      ('statement_protected.xlsx', OfficeEncryption.xlsxAgile),
      ('statement_velvet.xlsx', OfficeEncryption.xlsxAgile),
      ('statement_protected.xls', OfficeEncryption.xlsRc4CryptoApi),
      ('statement_velvet_cryptoapi.xls', OfficeEncryption.xlsRc4CryptoApi),
      ('statement_protected_rc4.xls', OfficeEncryption.xlsRc4),
      ('statement_velvet.xls', OfficeEncryption.xlsRc4),
      ('statement_xor.xls', OfficeEncryption.xlsXor),
      ('statement_xor_velvet.xls', OfficeEncryption.xlsXor),
      ('statement_writeres.xls', OfficeEncryption.none),
      ('statement.xls', OfficeEncryption.none),
      ('statement.xlsx', OfficeEncryption.none),
    ]) {
      expect(officeEncryptionOf(_fixture(name)), kind, reason: name);
    }
  });

  final plainXlsx = _summary(xlsxTable(_fixture('statement.xlsx')));
  final plainXls = _summary(xlsTable(_fixture('statement.xls')));

  test('.xlsx Agile: right password gives the same rows', () {
    final t = xlsxTable(_fixture('statement_protected.xlsx'), password: _pw);
    expect(t, xlsxTable(_fixture('statement.xlsx')));
    expect(_summary(t), plainXlsx);
    // Named .xls by a bank, read the same.
    expect(
      _summary(xlsTable(_fixture('statement_protected.xlsx'), password: _pw)),
      plainXlsx,
    );
  });

  test('.xlsx Standard: right password gives the original zip', () {
    final zip = decryptOoxmlStreams(
      _fixture('statement_standard.info'),
      _fixture('statement_standard.package'),
      _pw,
    );
    expect(zip, _fixture('statement.xlsx'));
    expect(
      () => decryptOoxmlStreams(
        _fixture('statement_standard.info'),
        _fixture('statement_standard.package'),
        'fin@2026',
      ),
      throwsA(isA<OfficeWrongPasswordException>()),
    );
  });

  test('.xlsx Standard: version 2.2 headers (Office 2007 SP) read too', () {
    final info = Uint8List.fromList(_fixture('statement_standard.info'));
    ByteData.sublistView(info).setUint16(0, 2, Endian.little);
    expect(
      decryptOoxmlStreams(info, _fixture('statement_standard.package'), _pw),
      _fixture('statement.xlsx'),
    );
  });

  for (final name in [
    'statement_protected.xls',
    'statement_protected_rc4.xls',
    'statement_xor.xls',
  ]) {
    test('$name: right password gives the same rows', () {
      final t = xlsTable(_fixture(name), password: _pw);
      expect(t, xlsTable(_fixture('statement.xls')));
      expect(_summary(t), plainXls);
    });
  }

  for (final name in [
    'statement_protected.xlsx',
    'statement_protected.xls',
    'statement_protected_rc4.xls',
    'statement_xor.xls',
  ]) {
    test('$name: no password, then a wrong one', () {
      expect(
        () => xlsTable(_fixture(name)),
        throwsA(
          isA<ProtectedSpreadsheetException>().having(
            (e) => e.wrongPassword,
            'wrongPassword',
            false,
          ),
        ),
      );
      expect(
        () => xlsTable(_fixture(name), password: 'Fin@2025'),
        throwsA(
          isA<ProtectedSpreadsheetException>().having(
            (e) => e.wrongPassword,
            'wrongPassword',
            true,
          ),
        ),
      );
    });
  }

  group('VelvetSweatshop, Excel\'s built-in password', () {
    for (final name in [
      'statement_velvet.xls',
      'statement_velvet_cryptoapi.xls',
      'statement_xor_velvet.xls',
    ]) {
      test('$name opens with no password asked', () {
        final t = xlsTable(_fixture(name));
        expect(t, xlsTable(_fixture('statement.xls')));
        expect(_summary(t), plainXls);
      });
    }

    test('statement_velvet.xlsx opens with no password asked', () {
      final t = xlsxTable(_fixture('statement_velvet.xlsx'));
      expect(t, xlsxTable(_fixture('statement.xlsx')));
      expect(_summary(xlsTable(_fixture('statement_velvet.xlsx'))), plainXlsx);
    });

    test('a password to modify only is no encryption: reads as is', () {
      expect(
        xlsTable(_fixture('statement_writeres.xls')),
        xlsTable(_fixture('statement.xls')),
      );
    });
  });

  group('XOR obfuscation', () {
    test('the XorMatrix table has no typos', () {
      // [MS-OFFCRYPTO] 2.3.7.2's table is 15 rows of a CRC-16/CCITT shift
      // register: each value is the one before shifted left, XOR 0x1021
      // when the top bit falls off.
      expect(xorMatrix, hasLength(15 * 7));
      for (var row = 0; row < 15; row++) {
        for (var k = 0; k < 6; k++) {
          final x = xorMatrix[row * 7 + k];
          final next = ((x << 1) & 0xFFFF) ^ (x & 0x8000 != 0 ? 0x1021 : 0);
          expect(xorMatrix[row * 7 + k + 1], next, reason: 'row $row, $k');
        }
      }
    });

    test('the verifier matches what Excel itself stores', () {
      // The well-known Excel sheet-protection hash of "password".
      expect(xorPasswordVerifier('password'), 0x83AF);
      // Excel 2016 wrote statement_velvet.xls with its workbook and sheet
      // protected by "Fin@2026": both Password records hold that verifier.
      final book = CompoundFile(
        decryptOfficeFile(
          _fixture('statement_velvet.xls'),
          officeDefaultPassword,
        ),
      ).stream('Workbook')!;
      final stored = [
        for (final (op, data) in _records(book))
          if (op == 0x13)
            ByteData.sublistView(data).getUint16(0, Endian.little),
      ];
      expect(stored, [xorPasswordVerifier(_pw), xorPasswordVerifier(_pw)]);
    });

    test('key and verifier from the file\'s FILEPASS', () {
      final book = CompoundFile(_fixture('statement_xor.xls'))
          .stream('Workbook')!;
      final (op, fp) = _records(book).elementAt(1);
      expect(op, 0x2F);
      final d = ByteData.sublistView(fp);
      expect(d.getUint16(0, Endian.little), 0); // wEncryptionType: XOR
      expect(d.getUint16(2, Endian.little), xorObfuscationKey(_pw));
      expect(d.getUint16(4, Endian.little), xorPasswordVerifier(_pw));
    });
  });

  group('protection that can\'t be opened says what it is', () {
    test('Information Rights Management', () {
      final binary = compoundFileWith('\x09DRMContent', Uint8List(4096));
      final ooxml = compoundFileWith('DRMEncryptedTransform', Uint8List(4096));
      for (final f in [binary, ooxml]) {
        expect(officeEncryptionOf(f), OfficeEncryption.irm);
        expect(() => xlsTable(f), _unsupported(OfficeEncryption.irm));
        expect(
          () => xlsxTable(f, password: _pw),
          _unsupported(OfficeEncryption.irm),
        );
      }
    });

    test('an encrypted package with no EncryptionInfo', () {
      final f = compoundFileWith('EncryptedPackage', Uint8List(4096));
      expect(officeEncryptionOf(f), OfficeEncryption.other);
      expect(() => xlsxTable(f), _unsupported(OfficeEncryption.other));
    });

    test('a certificate instead of a password', () {
      final info = _agileInfo(
        '<encryption><keyData saltSize="16" blockSize="16" keyBits="256" '
        'hashSize="64" cipherAlgorithm="AES" cipherChaining="ChainingModeCBC" '
        'hashAlgorithm="SHA512" saltValue="AAAA"/><keyEncryptors>'
        '<keyEncryptor uri="http://schemas.microsoft.com/office/2006/'
        'keyEncryptor/certificate"><c:encryptedKey encryptedKeyValue="AAAA" '
        'X509Certificate="AAAA" certVerifier="AAAA"/></keyEncryptor>'
        '</keyEncryptors></encryption>',
      );
      expect(
        () => decryptOoxmlStreams(info, Uint8List(16), _pw),
        throwsA(
          isA<OfficeUnsupportedEncryptionException>().having(
            (e) => e.kind,
            'kind',
            OfficeEncryption.certificate,
          ),
        ),
      );
    });

    test('a cipher other than AES-CBC in Agile', () {
      final info = CompoundFile(_fixture('statement_protected.xlsx'))
          .stream('EncryptionInfo')!;
      final text = utf8.decode(info.sublist(8));
      for (final (from, to, detail) in [
        ('cipherAlgorithm="AES"', 'cipherAlgorithm="3DES"', '3DES encryption'),
        (
          'cipherChaining="ChainingModeCBC"',
          'cipherChaining="ChainingModeCFB"',
          'AES encryption in CFB mode',
        ),
        (
          'hashAlgorithm="SHA512"',
          'hashAlgorithm="WHIRLPOOL"',
          'WHIRLPOOL hashing',
        ),
      ]) {
        expect(text, contains(from));
        expect(
          () => decryptOoxmlStreams(
            _agileInfo(text.replaceAll(from, to)),
            Uint8List(16),
            _pw,
          ),
          throwsA(
            isA<OfficeUnsupportedEncryptionException>()
                .having((e) => e.kind, 'kind', OfficeEncryption.other)
                .having((e) => e.detail, 'detail', detail),
          ),
        );
      }
    });

    test('extensible encryption, and Standard with a non-AES cipher', () {
      final info = Uint8List.fromList(_fixture('statement_standard.info'));
      final d = ByteData.sublistView(info);
      // Version 4.3: extensible (a third-party module).
      d.setUint16(2, 3, Endian.little);
      expect(
        () => decryptOoxmlStreams(info, Uint8List(16), _pw),
        throwsA(
          isA<OfficeUnsupportedEncryptionException>().having(
            (e) => e.kind,
            'kind',
            OfficeEncryption.extensible,
          ),
        ),
      );
      // Back to Standard (x.2), with RC4 as the AlgID.
      d
        ..setUint16(2, 2, Endian.little)
        ..setUint32(12 + 8, 0x6801, Endian.little);
      expect(
        () => decryptOoxmlStreams(info, Uint8List(16), _pw),
        throwsA(
          isA<OfficeUnsupportedEncryptionException>().having(
            (e) => e.detail,
            'detail',
            'RC4 encryption',
          ),
        ),
      );
    });

    test('.xls CryptoAPI with a cipher or hash other than RC4 / SHA-1', () {
      // EncryptionHeader starts 14 bytes into FILEPASS: AlgID at +8, the
      // hash's AlgID at +12.
      final aes = _patchedFilePass(
        (fp) => fp.setUint32(14 + 8, 0x660E, Endian.little),
      );
      expect(officeEncryptionOf(aes), OfficeEncryption.other);
      expect(
        () => xlsTable(aes),
        _unsupported(OfficeEncryption.other, 'AES-128 encryption'),
      );
      final md5 = _patchedFilePass(
        (fp) => fp.setUint32(14 + 12, 0x8003, Endian.little),
      );
      expect(
        () => xlsTable(md5, password: _pw),
        _unsupported(OfficeEncryption.other, 'MD5 hashing'),
      );
    });

    test('the messages', () {
      const name = 'hdfc-nov.xls';
      expect(
        const UnsupportedSpreadsheetProtectionException(OfficeEncryption.irm)
            .message(name),
        'hdfc-nov.xls is protected with Information Rights Management (a '
        'sensitivity label or Restrict Access), which FinRoot can\'t open. '
        'Open it in Excel and save a copy without the restriction or a '
        'password, then import that copy.',
      );
      expect(
        const UnsupportedSpreadsheetProtectionException(
          OfficeEncryption.certificate,
        ).message(name),
        'hdfc-nov.xls is encrypted with a digital certificate instead of a '
        'password, which FinRoot can\'t open. Open it in Excel and save it '
        'without a password, then import it again.',
      );
      expect(
        const UnsupportedSpreadsheetProtectionException(
          OfficeEncryption.extensible,
        ).message(name),
        'hdfc-nov.xls is encrypted by a third-party encryption add-in, which '
        'FinRoot can\'t open. Open it in Excel and save it without a '
        'password, then import it again.',
      );
      expect(
        const UnsupportedSpreadsheetProtectionException(
          OfficeEncryption.other,
          'DES encryption',
        ).message(name),
        'hdfc-nov.xls is protected with DES encryption, which FinRoot can\'t '
        'open. Open it in Excel and save it without a password, then import '
        'it again.',
      );
      expect(
        const UnsupportedSpreadsheetProtectionException(OfficeEncryption.other)
            .message(name),
        'hdfc-nov.xls uses a kind of encryption FinRoot can\'t open. Open it '
        'in Excel and save it without a password, then import it again.',
      );
    });
  });

  test('the compound file writer round-trips a stream', () {
    final data = Uint8List.fromList(List.generate(70000, (i) => i * 7 & 0xFF));
    final back = CompoundFile(compoundFileWith('Workbook', data));
    expect(back.stream('workbook'), data);
    expect(back.stream('Book'), isNull);
  });
}
