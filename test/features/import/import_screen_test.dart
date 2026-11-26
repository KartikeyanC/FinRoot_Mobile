import 'dart:convert';

import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/import/data/import_gateway.dart';
import 'package:finroot_mobile/features/import/data/pdf_text_reader.dart';
import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:finroot_mobile/features/import/domain/pdf_statement.dart';
import 'package:finroot_mobile/features/import/presentation/import_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements ImportGateway {
  List<ImportRow>? sent;
  @override
  Future<ImportOutcome> importRows({
    required String tenantId,
    required String userId,
    required List<ImportRow> rows,
  }) async {
    sent = rows;
    // Pretend one row was already stored.
    return ImportOutcome(inserted: rows.length - 1, attempted: rows.length);
  }
}

const _statement =
    'Date,Narration,Withdrawal Amt.,Deposit Amt.\n'
    '23/11/26,UPI-SWIGGY,450.00,\n'
    '22/11/26,NEFT SALARY,,85000.00\n'
    '21/11/26,UPI-UBER,220.00,\n';

/// A one-row PDF statement as PDFium would hand it over.
List<PdfWord> _pdfWords() {
  PdfWord w(String t, double x, double y) =>
      PdfWord(t, left: x, right: x + t.length * 5, top: y, bottom: y + 10);
  return [
    w('Date', 20, 20),
    w('Narration', 90, 20),
    w('Debit', 300, 20),
    w('23/11/2026', 20, 36),
    w('UPI-ZOMATO', 90, 36),
    w('640.00', 300, 36),
  ];
}

Future<void> _pumpPdf(WidgetTester tester, PdfWordReader reader) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
        currentTenantIdProvider.overrideWithValue('t1'),
        currentUserIdProvider.overrideWithValue('u1'),
        isOnlineProvider.overrideWithValue(true),
        effectiveMenusProvider.overrideWith(
          (ref) async => {for (final m in FeatureMenu.values) m.id},
        ),
        importGatewayProvider.overrideWithValue(_Gateway()),
        importFilePickerProvider.overrideWithValue(
          () async => (name: 'sbi-nov.pdf', bytes: const [1, 2, 3]),
        ),
        importPdfReaderProvider.overrideWithValue(reader),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const ImportScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('import-pick-file')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a protected PDF asks for its password, says when it is wrong', (
    tester,
  ) async {
    final tried = <String?>[];
    await _pumpPdf(tester, (bytes, {password}) async {
      tried.add(password);
      if (password == null) {
        throw const PdfReadException(PdfReadProblem.needsPassword);
      }
      if (password != 'ABCD0101') {
        throw const PdfReadException(PdfReadProblem.wrongPassword);
      }
      return _pdfWords();
    });
    expect(find.text('Password-protected PDF'), findsOneWidget);
    expect(find.textContaining('date of birth, PAN'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('import-pdf-password')),
      'nope',
    );
    await tester.tap(find.byKey(const ValueKey('import-pdf-password-open')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(find.textContaining("didn't open sbi-nov.pdf"), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('import-pdf-password')),
      'ABCD0101',
    );
    await tester.tap(find.byKey(const ValueKey('import-pdf-password-open')));
    await tester.pumpAndSettle();
    expect(tried, [null, 'nope', 'ABCD0101']);
    expect(find.text('sbi-nov.pdf'), findsOneWidget);
    expect(find.text('UPI-ZOMATO'), findsOneWidget);
    expect(find.text('Import 1 transaction'), findsOneWidget);
  });

  testWidgets('cancelling the password, and a scanned PDF, explain why', (
    tester,
  ) async {
    await _pumpPdf(
      tester,
      (bytes, {password}) async =>
          throw const PdfReadException(PdfReadProblem.needsPassword),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is password-protected'), findsOneWidget);

    await _pumpPdf(
      tester,
      (bytes, {password}) async =>
          throw const PdfReadException(PdfReadProblem.noText),
    );
    expect(find.textContaining('scanned image'), findsOneWidget);
    expect(find.textContaining('as Excel or CSV'), findsOneWidget);
  });

  testWidgets('pick a statement, untick a row, import the rest', (
    tester,
  ) async {
    final gateway = _Gateway();
    var refreshed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          currentTenantIdProvider.overrideWithValue('t1'),
          currentUserIdProvider.overrideWithValue('u1'),
          isOnlineProvider.overrideWithValue(true),
          effectiveMenusProvider.overrideWith(
            (ref) async => {for (final m in FeatureMenu.values) m.id},
          ),
          importGatewayProvider.overrideWithValue(gateway),
          importRefreshProvider.overrideWithValue(() async => refreshed = true),
          importFilePickerProvider.overrideWithValue(
            () async => (name: 'hdfc-nov.csv', bytes: utf8.encode(_statement)),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ImportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-pick-file')));
    await tester.pumpAndSettle();
    expect(find.text('hdfc-nov.csv'), findsOneWidget);
    expect(find.text('UPI-SWIGGY'), findsOneWidget);
    expect(find.text('NEFT SALARY'), findsOneWidget);
    expect(find.text('Import 3 transactions'), findsOneWidget);

    await tester.tap(find.text('UPI-UBER'));
    await tester.pump();
    expect(find.text('Import 2 transactions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-save')));
    await tester.pumpAndSettle();
    expect(gateway.sent!.map((r) => r.description), [
      'UPI-SWIGGY',
      'NEFT SALARY',
    ]);
    expect(gateway.sent![1].type, 'income');
    expect(refreshed, isTrue);
    expect(
      find.textContaining('Added 1 transaction. 1 was already in FinRoot'),
      findsOneWidget,
    );
  });
}
