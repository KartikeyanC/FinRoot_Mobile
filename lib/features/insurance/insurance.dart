import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/error_mapper.dart';
import '../../core/error/failure.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../../domain/constants.dart';
import '../menus/application/menu_providers.dart';
import '../workspace/application/workspace_providers.dart';

/// Insurance policies (`insurance` table) — the phone half of the web's
/// Insurance page (`src/pages/Insurance.tsx`, `src/lib/insuranceStore.ts`):
/// the same fields and options, and policy documents in the same private
/// `insurance-docs` bucket under the same path scheme
/// (`src/lib/insuranceDocs.ts`), so a policy made on either app opens on the
/// other.

/// Category id → label and emoji (web `CATEGORY_META`, same order).
const kInsuranceCategories = {
  'health': ('Health', '🏥'),
  'life': ('Life', '🛡️'),
  'vehicle': ('Vehicle', '🚗'),
  'gadget': ('Gadget', '📱'),
  'other': ('Other', '📦'),
};

/// Web `PAY_STRUCTURES`.
const kPayStructures = ['1-Pay', 'Limited-Pay', 'Regular-Pay'];

/// Web `PAYMENT_FREQUENCIES` with `FREQUENCY_MULTIPLIER` (premiums a year).
const kPaymentFrequencies = {
  'Monthly': 12,
  'Quarterly': 4,
  'Half-Yearly': 2,
  'Annual': 1,
  'One-Time': 0,
};

String insuranceCategoryLabel(String id) =>
    kInsuranceCategories[id]?.$1 ??
    (id.isEmpty ? 'Other' : id[0].toUpperCase() + id.substring(1));

class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.name,
    required this.category,
    required this.premium,
    required this.sumInsured,
    this.provider,
    this.policyNumber,
    this.frequency,
    this.payStructure,
    this.due,
    this.notes,
    this.documentPath,
    this.documentName,
    this.hasLegacyDocument = false,
  });

  factory InsurancePolicy.fromRow(Map<String, dynamic> r) => InsurancePolicy(
    id: r['id'] as String,
    name: (r['policy_name'] as String?) ?? 'Policy',
    category: (r['category'] as String?) ?? '',
    premium: asDouble(r['premium']),
    sumInsured: asDouble(r['sum_insured']),
    provider: r['provider'] as String?,
    policyNumber: r['policy_number'] as String?,
    frequency: r['payment_frequency'] as String?,
    payStructure: r['pay_structure'] as String?,
    due: asDate(r['due_date']),
    notes: r['notes'] as String?,
    documentPath: r['document_path'] as String?,
    documentName: r['document_name'] as String?,
    hasLegacyDocument: r['has_legacy_document'] == true,
  );

  final String id;
  final String name;
  final String category;
  final double premium;
  final double sumInsured;
  final String? provider;
  final String? policyNumber;
  final String? frequency;
  final String? payStructure;
  final DateTime? due;
  final String? notes;

  /// Object path in `insurance-docs` (null without a document).
  final String? documentPath;
  final String? documentName;

  /// A pre-Storage inline document, viewable on the web only.
  final bool hasLegacyDocument;

  String get categoryLabel => insuranceCategoryLabel(category);

  /// What this policy costs a year (web: premium × FREQUENCY_MULTIPLIER).
  double get yearlyPremium => premium * (kPaymentFrequencies[frequency] ?? 1);
}

/// What the person typed for a policy.
class PolicyDraft {
  const PolicyDraft({
    required this.name,
    required this.category,
    required this.provider,
    required this.policyNumber,
    required this.sumInsured,
    required this.premium,
    required this.frequency,
    required this.payStructure,
    this.due,
    this.notes = '',
  });

  final String name;
  final String category;
  final String provider;
  final String policyNumber;
  final double sumInsured;
  final double premium;
  final String frequency;
  final String payStructure;
  final DateTime? due;
  final String notes;

  /// The columns the web's `policyToRow` writes for these fields.
  Map<String, dynamic> toRow() => {
    'policy_name': name.trim(),
    'category': category,
    'provider': provider.trim(),
    'policy_number': policyNumber.trim(),
    'sum_insured': sumInsured,
    'premium': premium,
    'payment_frequency': frequency,
    'pay_structure': payStructure,
    'due_date': due == null
        ? null
        : '${due!.year.toString().padLeft(4, '0')}-'
              '${due!.month.toString().padLeft(2, '0')}-'
              '${due!.day.toString().padLeft(2, '0')}',
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };
}

// ── Documents (web `insuranceDocs.ts`) ─────────────────────────────────────

const kInsuranceBucket = 'insurance-docs';

/// The bucket's `file_size_limit`.
const kMaxDocBytes = 10 * 1024 * 1024;

const _mimeByExt = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
};

/// The MIME type the bucket accepts for [fileName], or null when it doesn't.
String? docMimeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _mimeByExt[fileName.substring(dot + 1).toLowerCase()];
}

/// Why a file can't be attached, or null when it can (web
/// `documentRejectionReason`).
String? docRejectionReason(String fileName, int size) {
  if (size == 0) return 'That file is empty.';
  if (size > kMaxDocBytes) return 'Documents can be up to 10 MB.';
  if (docMimeFor(fileName) == null) {
    return 'Attach a PDF or a photo (PNG, JPG or WebP).';
  }
  return null;
}

/// Web `safeFileName`: one path segment, no traversal, at most 120 chars.
String safeFileName(String name) {
  final base = name.split(RegExp(r'[\\/]')).last;
  var cleaned = base
      .replaceAll(RegExp(r'[^\w.\- ]+'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .replaceAll(RegExp(r'^\.+'), '')
      .trim();
  if (cleaned.isEmpty) cleaned = 'document';
  return cleaned.length > 120
      ? cleaned.substring(cleaned.length - 120)
      : cleaned;
}

/// Web `documentPath`: `<tenant>/<policy>/<millis>-<file>`. The bucket's RLS
/// reads the first segment as the workspace, so this is the only shape used.
String insuranceDocPath(
  String tenantId,
  String policyId,
  String fileName, {
  DateTime? now,
}) =>
    '$tenantId/$policyId/${(now ?? DateTime.now()).millisecondsSinceEpoch}-'
    '${safeFileName(fileName)}';

// ── Data ───────────────────────────────────────────────────────────────────

abstract interface class InsuranceGateway {
  Future<List<Map<String, dynamic>>> fetch(String tenantId);
  Future<void> insert(Map<String, dynamic> row);
  Future<void> update(String tenantId, String id, Map<String, dynamic> patch);
  Future<void> delete(String tenantId, String id);
  Future<void> upload(String path, List<int> bytes, String mime);
  Future<void> removeObject(String path);
  Future<String?> signedUrl(String path);
}

class SupabaseInsuranceGateway implements InsuranceGateway {
  SupabaseInsuranceGateway(this._client);
  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) => _guard(() async {
    // Not the inline legacy document (document_data_url can be megabytes).
    final rows = await _client
        .from('insurance')
        .select(
          'id, policy_name, category, premium, sum_insured, provider, '
          'policy_number, payment_frequency, pay_structure, due_date, notes, '
          'document_path, document_name, has_legacy_document',
        )
        .eq('tenant_id', tenantId)
        .order('due_date', ascending: true, nullsFirst: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  });

  @override
  Future<void> insert(Map<String, dynamic> row) =>
      _guard(() => _client.from('insurance').insert(row));

  @override
  Future<void> update(String tenantId, String id, Map<String, dynamic> patch) =>
      _guard(
        () => _client
            .from('insurance')
            .update(patch)
            .eq('id', id)
            .eq('tenant_id', tenantId),
      );

  @override
  Future<void> delete(String tenantId, String id) => _guard(
    () => _client
        .from('insurance')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId),
  );

  @override
  Future<void> upload(String path, List<int> bytes, String mime) => _guard(
    () => _client.storage
        .from(kInsuranceBucket)
        .uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mime),
        ),
  );

  @override
  Future<void> removeObject(String path) =>
      _guard(() => _client.storage.from(kInsuranceBucket).remove([path]));

  @override
  Future<String?> signedUrl(String path) async {
    try {
      // Five minutes, as on the web: long enough to open, short enough that
      // a shared link goes stale.
      return await _client.storage
          .from(kInsuranceBucket)
          .createSignedUrl(path, 300);
    } on Object {
      return null;
    }
  }
}

final insuranceGatewayProvider = Provider<InsuranceGateway>(
  (ref) => SupabaseInsuranceGateway(ref.watch(supabaseClientProvider)),
  name: 'insuranceGateway',
);

final insuranceProvider = FutureProvider<List<InsurancePolicy>>((ref) async {
  final rows = await watchCachedRows(
    ref,
    'insurance',
    ref.watch(insuranceGatewayProvider).fetch,
  );
  return [for (final r in rows) InsurancePolicy.fromRow(r)];
}, name: 'insurance');

/// A picked document: its name and bytes.
typedef PolicyDoc = ({String name, List<int> bytes});

/// Add, edit and delete policies and their documents. Online only, owners
/// and admins only, and only where the Insurance menu is on (RLS).
class InsuranceEditor {
  InsuranceEditor(this._ref, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Ref _ref;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  InsuranceGateway get _gw => _ref.read(insuranceGatewayProvider);

  String _check() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.insurance)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Insurance isn\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }

  void _checkDoc(PolicyDoc doc) {
    final why = docRejectionReason(doc.name, doc.bytes.length);
    if (why != null) throw ValidationFailure(why);
  }

  /// Uploads [doc] for policy [id] and returns the row fields that point at
  /// it.
  Future<Map<String, dynamic>> _store(
    String tenantId,
    String id,
    PolicyDoc doc,
  ) async {
    final path = insuranceDocPath(tenantId, id, doc.name, now: _clock());
    final mime = docMimeFor(doc.name)!;
    await _gw.upload(path, doc.bytes, mime);
    return {
      'document_path': path,
      'document_name': doc.name,
      'document_mime': mime,
    };
  }

  Future<void> add(PolicyDraft d, {PolicyDoc? doc}) async {
    final tenantId = _check();
    if (doc != null) _checkDoc(doc);
    final id = _uuid.v4();
    await _gw.insert({'id': id, 'tenant_id': tenantId, ...d.toRow()});
    if (doc != null) {
      final fields = await _store(tenantId, id, doc);
      await _gw.update(tenantId, id, fields);
    }
    _ref.invalidate(insuranceProvider);
  }

  /// Saves changes; [doc] replaces the attached document, [removeDoc] drops
  /// it. A replaced or removed object is deleted from the bucket after the
  /// row stops pointing at it (best effort, as on the web).
  Future<void> edit(
    InsurancePolicy p,
    PolicyDraft d, {
    PolicyDoc? doc,
    bool removeDoc = false,
  }) async {
    final tenantId = _check();
    if (doc != null) _checkDoc(doc);
    final patch = d.toRow();
    if (doc != null) {
      patch.addAll(await _store(tenantId, p.id, doc));
    } else if (removeDoc) {
      patch.addAll({
        'document_path': null,
        'document_name': null,
        'document_mime': null,
      });
    }
    await _gw.update(tenantId, p.id, patch);
    final old = p.documentPath;
    if (old != null && (doc != null || removeDoc)) {
      try {
        await _gw.removeObject(old);
      } on Failure {
        // An orphaned object is better than a row pointing at nothing.
      }
    }
    _ref.invalidate(insuranceProvider);
  }

  /// Deletes the policy and its document.
  Future<void> delete(InsurancePolicy p) async {
    final tenantId = _check();
    await _gw.delete(tenantId, p.id);
    final doc = p.documentPath;
    if (doc != null) {
      try {
        await _gw.removeObject(doc);
      } on Failure {
        // best effort
      }
    }
    _ref.invalidate(insuranceProvider);
  }
}

final insuranceEditorProvider = Provider<InsuranceEditor>(
  (ref) => InsuranceEditor(ref),
  name: 'insuranceEditor',
);
