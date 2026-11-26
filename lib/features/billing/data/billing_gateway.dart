import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../domain/billing.dart';

/// Reads billing the way the web's `Billing.tsx` does. Live, not cached
/// (online-only, like Trips). The only call that is not a plain read is
/// `invoice_pdf`, which asks Paddle for a receipt link; cancel / resume and
/// checkout stay on the web page.
abstract interface class BillingGateway {
  /// `billing-api` GET with the workspace in `x-tenant-id` (the function
  /// refuses to guess for a multi-workspace user, BUG-023).
  Future<BillingOverview> overview(String tenantId);

  /// `upgradeable_plans()`: paid plans mapped to a Paddle price.
  Future<List<BillingPlan>> upgradeablePlans();

  /// `plans` where `is_active`, cheapest first (web `usePlansCatalogue`).
  Future<List<BillingPlan>> catalogue();

  /// Landing pricing copy, by lower-cased plan name.
  Future<Map<String, PlanBlurb>> planFeatures();

  /// `billing-api` POST `invoice_pdf`: a short-lived Paddle receipt URL.
  Future<Uri> invoiceUrl(String tenantId, String transactionId);
}

class SupabaseBillingGateway implements BillingGateway {
  SupabaseBillingGateway(this._client);
  final SupabaseClient _client;

  static const _function = 'billing-api';

  @override
  Future<BillingOverview> overview(String tenantId) async {
    try {
      final res = await _client.functions.invoke(
        _function,
        method: HttpMethod.get,
        headers: {'x-tenant-id': tenantId},
      );
      final data = res.data;
      if (data is! Map) throw const UnexpectedFailure();
      return BillingOverview.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<List<BillingPlan>> upgradeablePlans() async {
    try {
      final rows = await _client.rpc<dynamic>('upgradeable_plans');
      return [
        if (rows is List)
          for (final r in rows)
            if (r is Map) BillingPlan.fromJson(Map<String, dynamic>.from(r)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<List<BillingPlan>> catalogue() async {
    try {
      final rows = await _client
          .from('plans')
          .select('id,name,price_cents,currency,interval,is_active')
          .eq('is_active', true)
          .order('price_cents', ascending: true);
      return [
        for (final r in rows)
          BillingPlan.fromJson(Map<String, dynamic>.from(r)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<Map<String, PlanBlurb>> planFeatures() async {
    try {
      final row = await _client
          .from('site_settings')
          .select('value')
          .eq('key', 'landing_pricing')
          .maybeSingle();
      return planBlurbsFromPricing(row?['value']);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<Uri> invoiceUrl(String tenantId, String transactionId) async {
    try {
      final res = await _client.functions.invoke(
        _function,
        body: {
          'action': 'invoice_pdf',
          'transaction_id': transactionId,
          'tenant_id': tenantId,
        },
      );
      final data = res.data;
      // Web: `data?.data?.url || data?.url`.
      Object? url;
      if (data is Map) {
        final inner = data['data'];
        url = (inner is Map ? inner['url'] : null) ?? data['url'];
      }
      final uri = url is String ? Uri.tryParse(url) : null;
      // Only ever hand the browser a web address.
      if (uri == null || uri.scheme != 'https') {
        throw const ValidationFailure('The invoice link is not available.');
      }
      return uri;
    } on FunctionException catch (e) {
      throw _mapFunctionError(e, invoice: true);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  /// Plain-language copy per status; the function's own text is not shown.
  Failure _mapFunctionError(FunctionException e, {bool invoice = false}) {
    if (e is FunctionsFetchException) return NetworkFailure(cause: e);
    return switch (e.status) {
      401 => AuthFailure.sessionExpired(),
      403 =>
        invoice
            ? PermissionFailure(
                message: 'Only a workspace owner or admin can get invoices.',
                cause: e,
              )
            : PermissionFailure(
                message: "You don't have access to billing in this workspace.",
                cause: e,
              ),
      400 when invoice => ValidationFailure(
        "There's no paid subscription to get an invoice from.",
        cause: e,
      ),
      _ => UnexpectedFailure(cause: e),
    };
  }
}

final billingGatewayProvider = Provider<BillingGateway>(
  (ref) => SupabaseBillingGateway(ref.watch(supabaseClientProvider)),
  name: 'billingGateway',
);
