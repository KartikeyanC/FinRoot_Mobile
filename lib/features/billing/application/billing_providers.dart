import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/membership.dart';
import '../data/billing_gateway.dart';
import '../domain/billing.dart';

/// The active workspace's subscription, payment history and the caller's
/// role, from `billing-api`.
final billingOverviewProvider = FutureProvider<BillingOverview>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return BillingOverview.empty;
  return ref.watch(billingGatewayProvider).overview(tenantId);
}, name: 'billingOverview');

/// The plans to offer. Web: a plan mapped to a Paddle price can be bought
/// (`upgradeable_plans()`); with none, upgrades are set up by hand and the
/// page lists the plain catalogue with a "get in touch" instead.
final billingPlansProvider = FutureProvider<BillingPlans>((ref) async {
  final gateway = ref.watch(billingGatewayProvider);
  final purchasable = await gateway.upgradeablePlans();
  if (purchasable.isNotEmpty) {
    return BillingPlans(selfServe: true, plans: purchasable);
  }
  return BillingPlans(selfServe: false, plans: await gateway.catalogue());
}, name: 'billingPlans');

/// What each plan includes. Decoration only: if the pricing copy can't be
/// read, plans show without it rather than failing the screen.
final planFeaturesProvider = FutureProvider<Map<String, PlanBlurb>>((
  ref,
) async {
  try {
    return await ref.watch(billingGatewayProvider).planFeatures();
  } catch (_) {
    return const {};
  }
}, name: 'planFeatures');

/// The caller's role for billing: what `billing-api` resolved (the web acts
/// on that), else the membership role. Null = unknown, which is read-only.
final billingRoleProvider = Provider<WorkspaceRole?>((ref) {
  final fromApi = ref.watch(billingOverviewProvider).value?.role;
  return fromApi ?? ref.watch(currentRoleProvider);
}, name: 'billingRole');

class BillingController {
  BillingController(this._ref);
  final Ref _ref;

  /// A receipt link for [transactionId]. Owner or admin only; the function
  /// also checks the transaction belongs to this workspace's customer.
  Future<Uri> invoiceUrl(String transactionId) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(billingRoleProvider);
    if (role == null || !role.canDownloadInvoices) {
      throw const PermissionFailure(
        message: 'Only a workspace owner or admin can get invoices.',
      );
    }
    return _ref
        .read(billingGatewayProvider)
        .invoiceUrl(tenantId, transactionId);
  }
}

final billingControllerProvider = Provider<BillingController>(
  (ref) => BillingController(ref),
  name: 'billingController',
);
