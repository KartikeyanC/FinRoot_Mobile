import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../../core/error/failure.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../workspace/application/workspace_providers.dart';

/// One EMI of a debt — the web's `DebtInstallment` (`src/lib/debtsStore.ts`),
/// stored inside `debts.installments` jsonb.
class DebtInstallment {
  const DebtInstallment({
    required this.month,
    required this.dueDate,
    required this.amount,
    required this.paid,
    this.raw = const {},
  });

  factory DebtInstallment.fromJson(Map<String, dynamic> j) => DebtInstallment(
        month: (j['month'] as num?)?.toInt() ?? 0,
        dueDate: asDate(j['dueDate']),
        amount: asDouble(j['amount']),
        paid: j['status'] == 'paid',
        raw: j,
      );

  final int month; // 1-based
  final DateTime? dueDate;
  final double amount;
  final bool paid;

  /// The stored object, so fields this app doesn't know (reminderId,
  /// transactionId…) survive a write.
  final Map<String, dynamic> raw;
}

/// A loan / EMI plan from the web's Debts page (`debts` table).
class Debt {
  const Debt({
    required this.id,
    required this.lender,
    required this.category,
    required this.currency,
    required this.total,
    required this.monthly,
    required this.duration,
    required this.installments,
    this.notes,
  });

  factory Debt.fromRow(Map<String, dynamic> r) => Debt(
        id: r['id'] as String,
        lender: (r['lender'] as String?) ?? 'Debt',
        category: (r['category'] as String?) ?? '',
        currency: (r['currency'] as String?) ?? 'INR',
        total: asDouble(r['total_amount']),
        monthly: asDouble(r['monthly']),
        duration: (r['duration'] as num?)?.toInt() ?? 0,
        notes: r['notes'] as String?,
        installments: [
          for (final i in (r['installments'] as List<dynamic>? ?? const []))
            if (i is Map) DebtInstallment.fromJson(Map<String, dynamic>.from(i)),
        ],
      );

  final String id;
  final String lender;
  final String category;
  final String currency;
  final double total;
  final double monthly;
  final int duration;
  final String? notes;
  final List<DebtInstallment> installments;

  // Same arithmetic as the web's `debtSummary`.
  double get paidAmount => installments.where((i) => i.paid).fold(0, (s, i) => s + i.amount);
  double get remaining => total - paidAmount;
  int get paidCount => installments.where((i) => i.paid).length;
  int get remainingCount => duration - paidCount;
  double get progress => total > 0 ? (paidAmount / total).clamp(0, 1) : 0;
  bool get isClosed => installments.isNotEmpty && installments.every((i) => i.paid);

  /// The first unpaid instalment, or null when all are paid.
  DebtInstallment? get nextDue {
    for (final i in installments) {
      if (!i.paid) return i;
    }
    return null;
  }
}

/// [debt]'s installments JSON with [month] marked paid at [now].
List<Map<String, dynamic>> installmentsPaying(Debt debt, int month, DateTime now) => [
      for (final i in debt.installments)
        i.month == month
            ? {...i.raw, 'status': 'paid', 'paidAt': now.toUtc().toIso8601String()}
            : i.raw,
    ];

abstract interface class DebtsGateway {
  Future<List<Map<String, dynamic>>> fetch(String tenantId);
  Future<void> setInstallments(String tenantId, String debtId, List<Map<String, dynamic>> installments);
}

class SupabaseDebtsGateway implements DebtsGateway {
  SupabaseDebtsGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async {
    try {
      final rows = await _client
          .from('debts')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> setInstallments(
    String tenantId,
    String debtId,
    List<Map<String, dynamic>> installments,
  ) async {
    try {
      await _client
          .from('debts')
          .update({'installments': installments})
          .eq('id', debtId)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final debtsGatewayProvider = Provider<DebtsGateway>(
  (ref) => SupabaseDebtsGateway(ref.watch(supabaseClientProvider)),
  name: 'debtsGateway',
);

final debtsProvider = FutureProvider<List<Debt>>((ref) async {
  final rows = await watchCachedRows(ref, 'debts', ref.watch(debtsGatewayProvider).fetch);
  return [for (final r in rows) Debt.fromRow(r)];
}, name: 'debts');

/// Marks one instalment paid, as the web's "Mark paid" does (without logging
/// a transaction — add the expense separately if you want it in the ledger).
Future<void> markInstallmentPaid(WidgetRef ref, Debt debt, int month) async {
  final tenantId = ref.read(currentTenantIdProvider);
  if (tenantId == null) throw AuthFailure.sessionExpired();
  if (!ref.read(isOnlineProvider)) {
    throw const ValidationFailure('Connect to the internet to update a debt.');
  }
  await ref
      .read(debtsGatewayProvider)
      .setInstallments(tenantId, debt.id, installmentsPaying(debt, month, DateTime.now()));
  ref.invalidate(debtsProvider);
}
