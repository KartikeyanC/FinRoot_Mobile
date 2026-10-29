import 'dart:convert';

import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/backup/backup_data.dart';
import 'package:finroot_mobile/features/backup/drive_backup.dart';
import 'package:finroot_mobile/features/backup/drive_client.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class _Auth implements DriveAuth {
  _Auth(this.value);
  final String? value;
  final asked = <bool>[];
  @override
  Future<String?> token({required bool interactive}) async {
    asked.add(interactive);
    return value;
  }

  @override
  Future<void> disconnect() async {}
}

class _Data extends BackupDataSource {
  _Data() : super(SupabaseClient('http://localhost', 'anon'));
  WorkspaceBackup? restored;

  @override
  Future<WorkspaceBackup> export(String tenantId, String workspaceName) async => WorkspaceBackup(
        tenantId: tenantId,
        workspaceName: workspaceName,
        createdAt: DateTime(2026, 10, 29, 21, 5),
        tables: {
          'transactions': [
            {'id': 'x1', 'tenant_id': tenantId, 'amount': 100},
          ],
        },
      );

  @override
  Future<RestoreReport> restoreMissing(String tenantId, WorkspaceBackup backup) async {
    restored = backup;
    return const RestoreReport(sent: {'transactions': 1}, failed: {});
  }
}

/// A tiny in-memory Drive: one folder, files by id.
class _FakeDrive {
  final files = <String, ({String name, String body})>{};
  String? folder;
  var _n = 0;

  MockClient get client => MockClient((req) async {
        final u = req.url;
        if (req.method == 'GET' && u.path.endsWith('/files') && (u.queryParameters['q'] ?? '').contains('mimeType')) {
          return http.Response(jsonEncode({'files': [if (folder != null) {'id': folder}]}), 200);
        }
        if (req.method == 'POST' && u.path == '/drive/v3/files') {
          folder = 'folder1';
          return http.Response(jsonEncode({'id': folder}), 200);
        }
        if (req.method == 'POST' && u.path.startsWith('/upload/')) {
          final body = req.body;
          // --boundary, part headers, blank line, metadata; then the same for the file.
          final lines = body.split('\r\n');
          final meta = jsonDecode(lines[3]) as Map;
          final content = lines[7];
          final id = 'f${++_n}';
          files[id] = (name: meta['name'] as String, body: content);
          return http.Response(
            jsonEncode({'id': id, 'name': meta['name'], 'modifiedTime': '2026-10-29T15:35:00Z'}),
            200,
          );
        }
        if (req.method == 'GET' && u.path.endsWith('/files')) {
          return http.Response(
            jsonEncode({
              'files': [
                for (final e in files.entries) {'id': e.key, 'name': e.value.name, 'modifiedTime': '2026-10-29T15:35:00Z'},
              ],
            }),
            200,
          );
        }
        if (req.method == 'GET' && u.queryParameters['alt'] == 'media') {
          return http.Response(files[u.pathSegments.last]!.body, 200);
        }
        return http.Response('{"error":{"message":"unexpected ${req.method} $u"}}', 400);
      });
}

Future<ProviderContainer> _container({
  required _Auth auth,
  required _FakeDrive drive,
  required _Data data,
  WorkspaceRole role = WorkspaceRole.owner,
  String tenant = 't1',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    isOnlineProvider.overrideWithValue(true),
    currentTenantIdProvider.overrideWithValue(tenant),
    currentRoleProvider.overrideWithValue(role),
    currentMembershipProvider.overrideWithValue(
      Membership(tenantId: tenant, name: 'Kumar Household', role: role, tenantStatus: 'active'),
    ),
    driveAuthProvider.overrideWithValue(auth),
    driveClientFactoryProvider.overrideWithValue((t) => DriveClient(t, httpClient: drive.client)),
    backupDataSourceProvider.overrideWithValue(data),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('file names are dated and safe', () {
    expect(backupFileName('Kumar Household!', DateTime(2026, 10, 29, 21, 5)),
        'FinRoot-Kumar-Household-2026-10-29-2105.json');
    expect(backupFileName('***', DateTime(2026, 1, 2, 3, 4)), 'FinRoot-workspace-2026-01-02-0304.json');
  });

  test('a daily backup is due only when on and over a day old', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(autoBackupDue(enabled: false, now: now), isFalse);
    expect(autoBackupDue(enabled: true, now: now), isTrue);
    expect(autoBackupDue(enabled: true, last: now.subtract(const Duration(hours: 5)), now: now), isFalse);
    expect(autoBackupDue(enabled: true, last: now.subtract(const Duration(hours: 25)), now: now), isTrue);
  });

  test('a backup survives the round trip and a newer format is refused', () {
    final b = WorkspaceBackup(
      tenantId: 't1',
      workspaceName: 'W',
      createdAt: DateTime.utc(2026, 10, 29),
      tables: {
        'goals': [
          {'id': 'g', 'title': 'Car'},
        ],
      },
    );
    final back = WorkspaceBackup.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
    expect(back.tenantId, 't1');
    expect(back.tables['goals']!.single['title'], 'Car');
    expect(back.rowCount, 1);
    expect(
      () => WorkspaceBackup.fromJson({...b.toJson(), 'format': backupFormatVersion + 1}),
      throwsFormatException,
    );
  });

  test('every table a restore needs comes before what points at it', () {
    final names = backupTables.map((t) => t.name).toList();
    expect(names.indexOf('accounts'), lessThan(names.indexOf('transactions')));
    expect(names.indexOf('trackers'), lessThan(names.indexOf('transactions')));
    expect(backupTables.firstWhere((t) => t.name == 'insurance').columns, isNot(contains('document_data_url')));
  });

  test('back up now uploads to the FinRoot Backups folder and remembers when', () async {
    final drive = _FakeDrive();
    final c = await _container(auth: _Auth('tok'), drive: drive, data: _Data());

    final b = await c.read(driveBackupProvider.notifier).backUpNow();

    expect(b.rowCount, 1);
    expect(drive.folder, 'folder1');
    expect(drive.files.values.single.name, 'FinRoot-Kumar-Household-2026-10-29-2105.json');
    final saved = jsonDecode(drive.files.values.single.body) as Map<String, dynamic>;
    expect(saved['tenant_id'], 't1');
    expect(c.read(driveBackupProvider).lastBackupAt, isNotNull);
  });

  test('no Google account chosen: says so, uploads nothing', () async {
    final drive = _FakeDrive();
    final c = await _container(auth: _Auth(null), drive: drive, data: _Data());
    expect(() => c.read(driveBackupProvider.notifier).backUpNow(), throwsA(isA<ValidationFailure>()));
    expect(drive.files, isEmpty);
  });

  test('restore puts back missing rows, only into the same workspace', () async {
    final drive = _FakeDrive();
    final data = _Data();
    final c = await _container(auth: _Auth('tok'), drive: drive, data: data);
    await c.read(driveBackupProvider.notifier).backUpNow();
    final file = (await c.read(driveBackupProvider.notifier).listBackups()).single;

    final r = await c.read(driveBackupProvider.notifier).restore(file);
    expect(r.sent['transactions'], 1);
    expect(data.restored!.tables['transactions']!.single['id'], 'x1');
  });

  test('a viewer cannot restore', () async {
    final drive = _FakeDrive()..files['f9'] = (name: 'x.json', body: '{}');
    final c = await _container(auth: _Auth('tok'), drive: drive, data: _Data(), role: WorkspaceRole.viewer);
    final file = DriveFile(id: 'f9', name: 'x.json', modified: DateTime(2026));
    expect(() => c.read(driveBackupProvider.notifier).restore(file), throwsA(isA<PermissionFailure>()));
  });

  test('the daily backup is silent and skipped when off', () async {
    final auth = _Auth('tok');
    final c = await _container(auth: auth, drive: _FakeDrive(), data: _Data());
    await c.read(driveBackupProvider.notifier).autoBackupIfDue();
    expect(auth.asked, isEmpty, reason: 'off by default');

    await c.read(driveBackupProvider.notifier).setAuto(true);
    await c.read(driveBackupProvider.notifier).autoBackupIfDue();
    expect(auth.asked, [false], reason: 'never shows the Google picker');
  });
}
