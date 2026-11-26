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
// - statement_protected_rc4.xls: Office 97/2000 RC4, which Excel 2016 can't
//   save; built by a stdlib Python script and checked by opening it in
//   Excel with the password (and Excel refusing a wrong one).
// - statement_standard.info / .package: the EncryptionInfo and
//   EncryptedPackage streams of statement.xlsx under ECMA-376 Standard
//   encryption (AES-128, SHA-1), from the same script.
// protected.xls (older fixture) has a password we don't know.
Uint8List _fixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

const _pw = 'Fin@2026';

List<Object> _summary(List<List<Object?>> table) {
  final p = parseImportTable(table);
  return [for (final r in p.rows) r.importHash, p.skipped, p.undated];
}

void main() {
  test('kinds of protection', () {
    expect(
      officeEncryptionOf(_fixture('statement_protected.xlsx')),
      OfficeEncryption.xlsxAgile,
    );
    expect(
      officeEncryptionOf(_fixture('statement_protected.xls')),
      OfficeEncryption.xlsRc4CryptoApi,
    );
    expect(
      officeEncryptionOf(_fixture('statement_protected_rc4.xls')),
      OfficeEncryption.xlsRc4,
    );
    expect(
      officeEncryptionOf(_fixture('statement.xls')),
      OfficeEncryption.none,
    );
    expect(
      officeEncryptionOf(_fixture('statement.xlsx')),
      OfficeEncryption.none,
    );
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

  for (final name in [
    'statement_protected.xls',
    'statement_protected_rc4.xls',
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

  test('XOR obfuscation is reported as unsupported', () {
    // BOF, then FILEPASS with wEncryptionType 0 (XOR), then EOF.
    final book = Uint8List.fromList([
      0x09, 0x08, 0x04, 0x00, 0x00, 0x06, 0x05, 0x00, //
      0x2F, 0x00, 0x06, 0x00, 0x00, 0x00, 0x12, 0x34, 0x56, 0x78,
      0x0A, 0x00, 0x00, 0x00,
    ]);
    final file = compoundFileWith('Workbook', book);
    expect(officeEncryptionOf(file), OfficeEncryption.xlsXor);
    expect(
      () => xlsTable(file, password: _pw),
      throwsA(isA<UnsupportedSpreadsheetProtectionException>()),
    );
  });

  test('the compound file writer round-trips a stream', () {
    final data = Uint8List.fromList(List.generate(70000, (i) => i * 7 & 0xFF));
    final back = CompoundFile(compoundFileWith('Workbook', data));
    expect(back.stream('workbook'), data);
    expect(back.stream('Book'), isNull);
  });
}
