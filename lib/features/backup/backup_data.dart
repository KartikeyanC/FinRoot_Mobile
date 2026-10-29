import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';

/// One workspace table in a backup, and how a restore puts rows back.
class BackupTable {
  const BackupTable(this.name, {this.columns = '*', this.conflict = 'id'});

  final String name;

  /// What to export. Insurance leaves out its inline document (megabytes).
  final String columns;

  /// The unique key a restore matches on (rows already there are left alone).
  final String conflict;
}

/// Everything a workspace owns on the web dashboard and the phone, in the
/// order a restore needs (accounts and trackers before the transactions that
/// point at them).
const backupTables = <BackupTable>[
  BackupTable('accounts'),
  BackupTable('trackers'),
  BackupTable('budgets'),
  BackupTable('goals'),
  BackupTable('transactions'),
  BackupTable('recurring_items'),
  BackupTable('recurring_reminders'),
  BackupTable('reminders'),
  BackupTable('debts'),
  BackupTable('tracked_subscriptions'),
  BackupTable(
    'insurance',
    columns: 'id, tenant_id, user_id, policy_name, category, premium, sum_insured, provider, '
        'policy_number, payment_frequency, pay_structure, due_date, notes, created_at, updated_at',
  ),
  BackupTable('investments'),
  BackupTable('demat_accounts'),
  BackupTable('demat_ledger'),
  BackupTable('net_worth_entries'),
  BackupTable('net_worth_snapshots'),
  BackupTable('trips'),
  BackupTable('tenant_settings', conflict: 'tenant_id,key'),
];

/// Bumped if the file layout ever changes, so an old app can refuse a newer file.
const backupFormatVersion = 1;

/// A backup file's contents.
class WorkspaceBackup {
  const WorkspaceBackup({
    required this.tenantId,
    required this.workspaceName,
    required this.createdAt,
    required this.tables,
    this.skipped = const {},
  });

  factory WorkspaceBackup.fromJson(Map<String, dynamic> j) {
    final version = (j['format'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > backupFormatVersion) {
      throw const FormatException('This backup was made by a newer FinRoot. Update the app first.');
    }
    final tables = <String, List<Map<String, dynamic>>>{};
    final raw = j['tables'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) {
          tables[k as String] = [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)];
        }
      });
    }
    return WorkspaceBackup(
      tenantId: j['tenant_id'] as String? ?? '',
      workspaceName: j['workspace'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      tables: tables,
    );
  }

  final String tenantId;
  final String workspaceName;
  final DateTime createdAt;
  final Map<String, List<Map<String, dynamic>>> tables;

  /// Tables that could not be read, and why (they are left out, not fatal).
  final Map<String, String> skipped;

  int get rowCount => tables.values.fold(0, (s, rows) => s + rows.length);

  Map<String, dynamic> toJson() => {
        'app': 'FinRoot',
        'format': backupFormatVersion,
        'tenant_id': tenantId,
        'workspace': workspaceName,
        'created_at': createdAt.toUtc().toIso8601String(),
        'tables': tables,
        if (skipped.isNotEmpty) 'skipped': skipped,
      };
}

/// Reads and writes workspace rows on Supabase for backup and restore. RLS
/// still applies: members read, an owner/admin writes.
class BackupDataSource {
  BackupDataSource(this._client);
  final SupabaseClient _client;

  static const _page = 1000;

  /// Every row of every [backupTables] entry for [tenantId]. A table that
  /// fails (not on this server, no access) is recorded in `skipped`.
  Future<WorkspaceBackup> export(String tenantId, String workspaceName) async {
    final tables = <String, List<Map<String, dynamic>>>{};
    final skipped = <String, String>{};
    for (final t in backupTables) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (var from = 0;; from += _page) {
          final page = await _client
              .from(t.name)
              .select(t.columns)
              .eq('tenant_id', tenantId)
              .range(from, from + _page - 1);
          rows.addAll([for (final r in page) Map<String, dynamic>.from(r)]);
          if (page.length < _page) break;
        }
        tables[t.name] = rows;
      } catch (error, stack) {
        skipped[t.name] = mapError(error, stack).message;
      }
    }
    return WorkspaceBackup(
      tenantId: tenantId,
      workspaceName: workspaceName,
      createdAt: DateTime.now(),
      tables: tables,
      skipped: skipped,
    );
  }

  /// Puts back rows that are missing from [tenantId]; rows that still exist
  /// are left exactly as they are (insert, ignore duplicates). Returns how
  /// many rows were sent per table, and the tables that failed.
  Future<RestoreReport> restoreMissing(String tenantId, WorkspaceBackup backup) async {
    final sent = <String, int>{};
    final failed = <String, String>{};
    for (final t in backupTables) {
      final rows = backup.tables[t.name];
      if (rows == null || rows.isEmpty) continue;
      try {
        for (var i = 0; i < rows.length; i += 500) {
          final chunk = [
            for (final r in rows.skip(i).take(500)) {...r, 'tenant_id': tenantId},
          ];
          await _client.from(t.name).upsert(chunk, onConflict: t.conflict, ignoreDuplicates: true);
        }
        sent[t.name] = rows.length;
      } catch (error, stack) {
        failed[t.name] = mapError(error, stack).message;
      }
    }
    return RestoreReport(sent: sent, failed: failed);
  }
}

class RestoreReport {
  const RestoreReport({required this.sent, required this.failed});
  final Map<String, int> sent;
  final Map<String, String> failed;
}
