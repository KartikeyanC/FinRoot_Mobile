import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/features/billing/data/billing_gateway.dart';
import 'package:finroot_mobile/features/billing/domain/billing.dart';

/// In-memory billing. [overviewJson] is what `billing-api` GET would return;
/// [failOverview] makes that call throw, like a network or server error.
class FakeBillingGateway implements BillingGateway {
  FakeBillingGateway({
    Map<String, dynamic>? overviewJson,
    this.upgradeable = const [],
    this.catalogueRows = const [],
    this.features = const {},
    this.failOverview,
    this.failPlans,
    this.invoice = 'https://sandbox-invoice.example/receipt.pdf',
  }) : overviewJson = overviewJson ?? const {'subscription': null};

  Map<String, dynamic> overviewJson;
  List<BillingPlan> upgradeable;
  List<BillingPlan> catalogueRows;
  Map<String, PlanBlurb> features;
  Failure? failOverview;
  Failure? failPlans;
  String invoice;

  final overviewCalls = <String>[];
  final invoiceCalls = <(String, String)>[];

  @override
  Future<BillingOverview> overview(String tenantId) async {
    overviewCalls.add(tenantId);
    final f = failOverview;
    if (f != null) throw f;
    return BillingOverview.fromJson(overviewJson);
  }

  @override
  Future<List<BillingPlan>> upgradeablePlans() async {
    final f = failPlans;
    if (f != null) throw f;
    return upgradeable;
  }

  @override
  Future<List<BillingPlan>> catalogue() async {
    final f = failPlans;
    if (f != null) throw f;
    return catalogueRows;
  }

  @override
  Future<Map<String, PlanBlurb>> planFeatures() async => features;

  @override
  Future<Uri> invoiceUrl(String tenantId, String transactionId) async {
    invoiceCalls.add((tenantId, transactionId));
    return Uri.parse(invoice);
  }
}

const roots = BillingPlan(
  id: 'p0',
  name: 'Roots',
  priceCents: 0,
  currency: 'INR',
  interval: 'month',
);
const canopy = BillingPlan(
  id: 'p1',
  name: 'Canopy',
  priceCents: 29900,
  currency: 'INR',
  interval: 'month',
);
const heritage = BillingPlan(
  id: 'p2',
  name: 'Heritage',
  priceCents: 89900,
  currency: 'INR',
  interval: 'month',
);

/// A `billing-api` GET body: Canopy, active, paid through Paddle.
Map<String, dynamic> activeCanopy({
  String role = 'owner',
  String status = 'active',
  String? cancelAt,
  String? paddleSubscriptionId = 'sub_01',
  List<Map<String, dynamic>> transactions = const [],
}) => {
  'subscription': {
    'id': 's1',
    'paddle_subscription_id': paddleSubscriptionId,
    'paddle_customer_id': 'ctm_01abc',
    'plan_name': 'Canopy',
    'status': status,
    'currency': 'INR',
    'unit_amount': 299,
    'billing_interval': 'month',
    'current_period_start': '2026-11-26T12:00:00Z',
    'current_period_end': '2026-12-26T12:00:00Z',
    'cancel_at': cancelAt,
    'canceled_at': null,
    'raw': {'ignored': true},
  },
  'transactions': transactions,
  'env': 'sandbox',
  'tenant_id': 't1',
  'role': role,
};

Map<String, dynamic> paidTxn(String id, {String status = 'completed'}) => {
  'id': id,
  'status': status,
  'invoice_number': 'INV-$id',
  'billed_at': '2026-11-26T12:00:00Z',
  'created_at': '2026-11-26T11:00:00Z',
  'currency_code': 'INR',
  'details': {
    'totals': {'grand_total': '29900'},
  },
};
