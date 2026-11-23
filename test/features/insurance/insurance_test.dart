// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gw implements InsuranceGateway {
  final log = <String>[];
  final inserted = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async => const [];

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    log.add('insert');
    inserted.add(row);
  }

  @override
  Future<void> update(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async {
    log.add('update');
    updates.add({'id': id, ...patch});
  }

  @override
  Future<void> delete(String tenantId, String id) async =>
      log.add('delete $id');

  @override
  Future<void> upload(String path, List<int> bytes, String mime) async =>
      log.add('upload $path $mime');

  @override
  Future<void> removeObject(String path) async => log.add('remove $path');

  @override
  Future<String?> signedUrl(String path) async => 'https://signed/$path';
}

Future<ProviderContainer> _container(_Gw gw, {bool menuOn = true}) async {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      isOnlineProvider.overrideWithValue(true),
      insuranceGatewayProvider.overrideWithValue(gw),
      effectiveMenusProvider.overrideWith(
        (ref) async => {
          for (final m in FeatureMenu.values)
            if (menuOn || m != FeatureMenu.insurance) m.id,
        },
      ),
    ],
  );
  await c.read(effectiveMenusProvider.future);
  return c;
}

const _draft = PolicyDraft(
  name: ' Family health ',
  category: 'health',
  provider: 'Star Health',
  policyNumber: 'P-123',
  sumInsured: 500000,
  premium: 18000,
  frequency: 'Annual',
  payStructure: 'Regular-Pay',
);

InsurancePolicy _policy({String? doc}) => InsurancePolicy.fromRow({
  'id': 'p1',
  'policy_name': 'Family health',
  'category': 'health',
  'premium': 1500,
  'sum_insured': 500000,
  'payment_frequency': 'Monthly',
  'document_path': doc,
});

void main() {
  test("file names are cleaned the way the web's safeFileName does", () {
    // Expected values printed by the web's own function.
    expect(safeFileName('../../etc/passwd'), 'passwd');
    expect(
      safeFileName('folder/Star Health (2026).pdf'),
      'Star Health _2026_.pdf',
    );
    expect(safeFileName('..hidden..pdf'), 'hidden.pdf');
    expect(safeFileName('₹ policy#1.jpg'), '_ policy_1.jpg');
    expect(safeFileName('   '), 'document');
    expect(
      insuranceDocPath('t1', 'p1', 'a b.pdf', now: DateTime.utc(2026, 11, 23)),
      't1/p1/${DateTime.utc(2026, 11, 23).millisecondsSinceEpoch}-a b.pdf',
    );
  });

  test('only PDFs and photos up to 10 MB attach', () {
    expect(docRejectionReason('policy.pdf', 1000), isNull);
    expect(docRejectionReason('scan.JPG', 1000), isNull);
    expect(docRejectionReason('policy.docx', 1000), isNotNull);
    expect(docRejectionReason('policy.pdf', 0), isNotNull);
    expect(docRejectionReason('policy.pdf', 11 * 1024 * 1024), isNotNull);
    expect(docMimeFor('x.jpeg'), 'image/jpeg');
  });

  test('the row matches the web, and premiums count a year', () {
    final row = _draft.toRow();
    expect(row['policy_name'], 'Family health');
    expect(row['payment_frequency'], 'Annual');
    expect(row['pay_structure'], 'Regular-Pay');
    expect(row['due_date'], isNull);
    expect(row['notes'], isNull);
    expect(_policy().yearlyPremium, 18000); // 1,500 a month
    expect(_policy().categoryLabel, 'Health');
    expect(insuranceCategoryLabel('travel'), 'Travel');
  });

  test(
    'adding with a document: row first, then the file, then the link',
    () async {
      final gw = _Gw();
      final c = await _container(gw);
      addTearDown(c.dispose);
      await c
          .read(insuranceEditorProvider)
          .add(_draft, doc: (name: 'policy.pdf', bytes: [1, 2, 3]));
      expect(gw.log[0], 'insert');
      expect(gw.log[1], startsWith('upload t1/'));
      expect(gw.log[1], endsWith('-policy.pdf application/pdf'));
      expect(gw.log[2], 'update');
      final id = gw.inserted.single['id'];
      expect(gw.updates.single['id'], id);
      expect(gw.updates.single['document_name'], 'policy.pdf');
      expect(gw.updates.single['document_mime'], 'application/pdf');
    },
  );

  test('replacing or removing a document deletes the old file', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    final p = _policy(doc: 't1/p1/1-old.pdf');
    await c
        .read(insuranceEditorProvider)
        .edit(p, _draft, doc: (name: 'new.png', bytes: [1]));
    expect(gw.log.last, 'remove t1/p1/1-old.pdf');
    expect(gw.updates.single['document_mime'], 'image/png');

    gw.log.clear();
    gw.updates.clear();
    await c.read(insuranceEditorProvider).edit(p, _draft, removeDoc: true);
    expect(gw.updates.single['document_path'], isNull);
    expect(gw.updates.single.containsKey('document_path'), isTrue);
    expect(gw.log.last, 'remove t1/p1/1-old.pdf');

    gw.log.clear();
    await c.read(insuranceEditorProvider).edit(p, _draft);
    expect(gw.log, ['update']); // no file touched
  });

  test('deleting a policy takes its document with it', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    await c.read(insuranceEditorProvider).delete(_policy(doc: 't1/p1/1-a.pdf'));
    expect(gw.log, ['delete p1', 'remove t1/p1/1-a.pdf']);
  });

  test('a bad file or a locked menu writes nothing', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    await expectLater(
      c
          .read(insuranceEditorProvider)
          .add(_draft, doc: (name: 'x.exe', bytes: [1])),
      throwsA(isA<ValidationFailure>()),
    );
    expect(gw.log, isEmpty);

    final c2 = await _container(gw, menuOn: false);
    addTearDown(c2.dispose);
    await expectLater(
      c2.read(insuranceEditorProvider).add(_draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gw.log, isEmpty);
  });
}
