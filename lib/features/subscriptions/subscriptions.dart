import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../../core/error/failure.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../workspace/application/workspace_providers.dart';

/// A recurring service you pay for (Netflix, gym…) from the web's
/// Subscriptions page — `tracked_subscriptions` (`src/lib/subscriptionsStore.ts`).
class TrackedSubscription {
  const TrackedSubscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.active,
    this.icon,
    this.renewal,
    this.category,
  });

  factory TrackedSubscription.fromRow(Map<String, dynamic> r) =>
      TrackedSubscription(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? 'Subscription',
        icon: r['icon'] as String?,
        amount: asDouble(r['amount']),
        currency: (r['currency'] as String?) ?? 'INR',
        frequency: (r['frequency'] as String?) ?? 'monthly',
        renewal: asDate(r['renewal_date']),
        active: r['status'] != 'cancel',
        category: r['category'] as String?,
      );

  final String id;
  final String name;
  final String? icon; // emoji
  final double amount;
  final String currency;
  final String frequency; // weekly | monthly | annual
  final DateTime? renewal;
  final bool active; // web status: active | cancel
  final String? category;

  /// The web's `monthlyEquivalent`.
  double get perMonth => switch (frequency) {
    'monthly' => amount,
    'weekly' => amount * 52 / 12,
    _ => amount / 12,
  };

  String get frequencyLabel => switch (frequency) {
    'weekly' => 'week',
    'annual' => 'year',
    _ => 'month',
  };
}

abstract interface class SubscriptionsGateway {
  Future<List<Map<String, dynamic>>> fetch(String tenantId);
  Future<void> setActive(String tenantId, String id, {required bool active});
  Future<void> insert(Map<String, dynamic> row);
  Future<void> update(String tenantId, String id, Map<String, dynamic> patch);
  Future<void> delete(String tenantId, String id);
}

class SupabaseSubscriptionsGateway implements SubscriptionsGateway {
  SupabaseSubscriptionsGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async {
    try {
      final rows = await _client
          .from('tracked_subscriptions')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> setActive(
    String tenantId,
    String id, {
    required bool active,
  }) async {
    try {
      await _client
          .from('tracked_subscriptions')
          .update({'status': active ? 'active' : 'cancel'})
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> insert(Map<String, dynamic> row) async {
    try {
      await _client.from('tracked_subscriptions').insert(row);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> update(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async {
    try {
      await _client
          .from('tracked_subscriptions')
          .update(patch)
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    try {
      await _client
          .from('tracked_subscriptions')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final subscriptionsGatewayProvider = Provider<SubscriptionsGateway>(
  (ref) => SupabaseSubscriptionsGateway(ref.watch(supabaseClientProvider)),
  name: 'subscriptionsGateway',
);

final trackedSubscriptionsProvider = FutureProvider<List<TrackedSubscription>>((
  ref,
) async {
  final rows = await watchCachedRows(
    ref,
    'tracked_subscriptions',
    ref.watch(subscriptionsGatewayProvider).fetch,
  );
  return [for (final r in rows) TrackedSubscription.fromRow(r)];
}, name: 'trackedSubscriptions');

/// Cancel (or resume) tracking a subscription — the web's status toggle.
Future<void> setSubscriptionActive(
  WidgetRef ref,
  TrackedSubscription s, {
  required bool active,
}) async {
  final tenantId = ref.read(currentTenantIdProvider);
  if (tenantId == null) throw AuthFailure.sessionExpired();
  if (!ref.read(isOnlineProvider)) {
    throw const ValidationFailure(
      'Connect to the internet to change a subscription.',
    );
  }
  await ref
      .read(subscriptionsGatewayProvider)
      .setActive(tenantId, s.id, active: active);
  ref.invalidate(trackedSubscriptionsProvider);
}

/// What the person typed for a subscription (web `SubscriptionRecord`).
class SubscriptionDraft {
  const SubscriptionDraft({
    required this.name,
    required this.amount,
    required this.frequency,
    required this.renewal,
    this.icon = '💳',
  });

  final String name;
  final String icon;
  final double amount;

  /// weekly | monthly | annual (web `BillingFrequency`).
  final String frequency;
  final DateTime renewal;

  /// The columns the web's `recordToRow` writes for these fields.
  Map<String, dynamic> toRow() => {
    'name': name.trim(),
    'icon': icon.trim().isEmpty ? null : icon.trim(),
    'amount': amount,
    'frequency': frequency,
    'renewal_date':
        '${renewal.year.toString().padLeft(4, '0')}-'
        '${renewal.month.toString().padLeft(2, '0')}-'
        '${renewal.day.toString().padLeft(2, '0')}',
  };
}

/// The renewal after [from]: a week, a month or a year on.
DateTime nextRenewal(DateTime from, String frequency) => switch (frequency) {
  'weekly' => DateTime(from.year, from.month, from.day + 7),
  'annual' => DateTime(from.year + 1, from.month, from.day),
  _ => DateTime(from.year, from.month + 1, from.day),
};

/// The first renewal on or after [today], stepping from a date that passed.
DateTime catchUpRenewal(DateTime renewal, String frequency, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  var d = renewal;
  for (var i = 0; i < 1000 && d.isBefore(day); i++) {
    d = nextRenewal(d, frequency);
  }
  return d;
}

/// Add, edit and delete tracked subscriptions (the web's SubscriptionsPanel).
class SubscriptionEditor {
  SubscriptionEditor(this._ref);
  final Ref _ref;

  SubscriptionsGateway get _gw => _ref.read(subscriptionsGatewayProvider);

  String _check() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }

  Future<void> add(SubscriptionDraft d) async {
    final tenantId = _check();
    await _gw.insert({
      ...d.toRow(),
      'tenant_id': tenantId,
      'currency': 'INR',
      'status': 'active',
    });
    _ref.invalidate(trackedSubscriptionsProvider);
  }

  Future<void> edit(TrackedSubscription s, SubscriptionDraft d) async {
    final tenantId = _check();
    await _gw.update(tenantId, s.id, d.toRow());
    _ref.invalidate(trackedSubscriptionsProvider);
  }

  Future<void> delete(TrackedSubscription s) async {
    final tenantId = _check();
    await _gw.delete(tenantId, s.id);
    _ref.invalidate(trackedSubscriptionsProvider);
  }
}

final subscriptionEditorProvider = Provider<SubscriptionEditor>(
  (ref) => SubscriptionEditor(ref),
  name: 'subscriptionEditor',
);
