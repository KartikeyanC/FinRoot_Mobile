/// Billing & plans: web `src/pages/Billing.tsx` on the phone.
///
/// Every value here comes from the same place the web reads it:
///  * the subscription, its Paddle transactions and the caller's role from the
///    `billing-api` Edge Function (GET, workspace sent explicitly);
///  * purchasable plans from `upgradeable_plans()` (paid + Paddle-mapped);
///  * the plain catalogue from `plans` (active, cheapest first) when nothing is
///    purchasable, which is the web's "get in touch" state;
///  * what a plan includes from the landing pricing copy
///    (`site_settings.landing_pricing`), linked to a plan by name.
///
/// Money is never taken here: checkout is a Paddle overlay on the web page.
library;

import 'package:intl/intl.dart';

import '../../workspace/domain/membership.dart';

/// Where "contact us to upgrade" mail goes. Mirrors `SUPPORT_EMAIL` in the
/// web's `src/lib/support.ts` (the one place the web keeps it). Change both
/// together.
const kBillingSupportEmail = 'finroot95@gmail.com';

/// Statuses the web treats as a live plan (`isActive` in Billing.tsx).
const _liveStatuses = {'active', 'trialing', 'past_due', 'paused'};

/// Transaction statuses that have a receipt to download (web `canDownload`).
const _downloadableStatuses = {'completed', 'paid', 'billed'};

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

double? _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// The `subscriptions` row for the workspace, as `billing-api` returns it.
class BillingSubscription {
  const BillingSubscription({
    required this.status,
    this.planName,
    this.currency,
    this.unitAmount,
    this.billingInterval,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAt,
    this.customerId,
    this.paddleSubscriptionId,
  });

  /// `active` | `trialing` | `past_due` | `paused` | `canceled` | `inactive`.
  final String status;
  final String? planName;
  final String? currency;

  /// Major units (the webhook stores Paddle's minor units / 100).
  final double? unitAmount;

  /// `month` / `year` (webhook `intervalLabel`).
  final String? billingInterval;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;

  /// Set when a cancellation is scheduled for the end of the period.
  final DateTime? cancelAt;

  /// Paddle customer id (`paddle_customer_id`), shown as "Customer ID".
  final String? customerId;

  /// Null for a plan the Product Owner assigned by hand (`provider='manual'`),
  /// which has nothing at Paddle to cancel or resume.
  final String? paddleSubscriptionId;

  factory BillingSubscription.fromJson(Map<String, dynamic> j) =>
      BillingSubscription(
        status: _str(j['status']) ?? 'inactive',
        planName: _str(j['plan_name']),
        currency: _str(j['currency']),
        unitAmount: _num(j['unit_amount']),
        billingInterval: _str(j['billing_interval']),
        currentPeriodStart: _date(j['current_period_start']),
        currentPeriodEnd: _date(j['current_period_end']),
        cancelAt: _date(j['cancel_at']),
        customerId: _str(j['paddle_customer_id']),
        paddleSubscriptionId: _str(j['paddle_subscription_id']),
      );
}

/// One Paddle transaction, passed through `billing-api` untouched.
class BillingTransaction {
  const BillingTransaction({
    required this.id,
    required this.status,
    this.invoiceNumber,
    this.billedAt,
    this.createdAt,
    this.currencyCode,
    this.grandTotal,
  });

  final String id;

  /// Lower-cased, as the web compares it.
  final String status;
  final String? invoiceNumber;
  final DateTime? billedAt;
  final DateTime? createdAt;
  final String? currencyCode;

  /// `details.totals.grand_total`: a string in minor units.
  final String? grandTotal;

  factory BillingTransaction.fromJson(Map<String, dynamic> j) {
    final details = j['details'];
    final totals = details is Map ? details['totals'] : null;
    final total = totals is Map ? totals['grand_total'] : null;
    return BillingTransaction(
      id: (j['id'] ?? '').toString(),
      status: (_str(j['status']) ?? '').toLowerCase(),
      invoiceNumber: _str(j['invoice_number']),
      billedAt: _date(j['billed_at']),
      createdAt: _date(j['created_at']),
      currencyCode: _str(j['currency_code']),
      grandTotal: total?.toString(),
    );
  }

  /// When it was billed, else when it was created (web).
  DateTime? get date => billedAt ?? createdAt;

  /// The invoice number, else the last 10 characters of the id (web).
  String get invoiceLabel =>
      invoiceNumber ?? (id.length > 10 ? id.substring(id.length - 10) : id);

  String get statusLabel =>
      status.isEmpty ? '—' : status.replaceFirst('_', ' ').toUpperCase();

  bool get canDownload => _downloadableStatuses.contains(status);

  String get totalLabel {
    final raw = grandTotal;
    if (raw == null || raw.isEmpty) return '—';
    final minor = double.tryParse(raw);
    if (minor == null) return '—';
    return formatBillingMoney(minor / 100, currencyCode);
  }
}

/// Everything `billing-api` GET returns that the screen shows.
class BillingOverview {
  const BillingOverview({
    this.subscription,
    this.transactions = const [],
    this.role,
  });

  static const empty = BillingOverview();

  final BillingSubscription? subscription;
  final List<BillingTransaction> transactions;

  /// The caller's role in this workspace as the function resolved it. The web
  /// decides who may act from this, not from its own membership list.
  final WorkspaceRole? role;

  factory BillingOverview.fromJson(Map<String, dynamic> j) {
    final sub = j['subscription'];
    final txs = j['transactions'];
    final role = _str(j['role']);
    return BillingOverview(
      subscription: sub is Map
          ? BillingSubscription.fromJson(Map<String, dynamic>.from(sub))
          : null,
      transactions: [
        if (txs is List)
          for (final t in txs)
            if (t is Map)
              BillingTransaction.fromJson(Map<String, dynamic>.from(t)),
      ],
      role: role == null ? null : WorkspaceRole.fromWire(role),
    );
  }

  /// `inactive` when the workspace has no subscription row (web).
  String get status => subscription?.status ?? 'inactive';

  String get statusLabel => status.replaceFirst('_', ' ').toUpperCase();

  bool get isActive => _liveStatuses.contains(status);

  bool get scheduledCancel =>
      subscription?.cancelAt != null && status != 'canceled';

  /// Has a Paddle subscription that cancel / resume could act on.
  bool get hasPaddleSubscription => subscription?.paddleSubscriptionId != null;

  /// "₹299.00 / month", or null when there is no amount (web `priceLabel`).
  String? get priceLabel {
    final s = subscription;
    final amount = s?.unitAmount;
    if (s == null || amount == null || amount == 0) return null;
    final money = formatBillingMoney(amount, s.currency);
    final interval = s.billingInterval == null ? '' : '/ ${s.billingInterval}';
    return '$money $interval'.trim();
  }

  /// The web's "Current period": start → end, or a dash.
  String get periodLabel {
    final s = subscription;
    if (s?.currentPeriodStart == null) return '—';
    return '${formatBillingDate(s!.currentPeriodStart)} → '
        '${formatBillingDate(s.currentPeriodEnd)}';
  }

  /// The web marks a plan current by name, and only while the plan is live.
  bool isCurrentPlan(String planName) =>
      isActive && subscription?.planName == planName;
}

/// A row of `plans` (or of `upgradeable_plans()`).
class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.interval,
  });

  final String id;
  final String name;
  final int priceCents;
  final String currency;

  /// `month` / `year`.
  final String interval;

  factory BillingPlan.fromJson(Map<String, dynamic> j) => BillingPlan(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    priceCents: _num(j['price_cents'])?.round() ?? 0,
    currency: _str(j['currency']) ?? 'INR',
    interval: _str(j['interval']) ?? 'month',
  );
}

/// The plans to show, and which of the web's two states they belong to.
class BillingPlans {
  const BillingPlans({required this.selfServe, required this.plans});

  /// True when `upgradeable_plans()` returned something: a plan can be bought
  /// on the web page's Paddle checkout. False is the web's "Self-serve
  /// checkout isn't available yet" state, listing the plain catalogue.
  final bool selfServe;
  final List<BillingPlan> plans;
}

/// What a plan includes, from the landing pricing card linked to it.
class PlanBlurb {
  const PlanBlurb({this.blurb, this.features = const []});

  final String? blurb;
  final List<String> features;

  bool get isEmpty => (blurb == null || blurb!.isEmpty) && features.isEmpty;
}

/// Reads `site_settings.landing_pricing.value` into blurbs keyed by the
/// lower-cased plan name each card links to (web `resolvePricingCards`).
/// A card with no `plan` link sells nothing and is skipped.
Map<String, PlanBlurb> planBlurbsFromPricing(Object? value) {
  if (value is! Map) return const {};
  final cards = value['cards'];
  if (cards is! List) return const {};
  final out = <String, PlanBlurb>{};
  for (final c in cards) {
    if (c is! Map) continue;
    final plan = (c['plan'] ?? '').toString().trim().toLowerCase();
    if (plan.isEmpty) continue;
    final features = c['features'];
    out[plan] = PlanBlurb(
      blurb: _str(c['blurb']),
      features: [
        if (features is List)
          for (final f in features)
            if (f is String && f.trim().isNotEmpty) f.trim(),
      ],
    );
  }
  return out;
}

/// Who may do what with billing. The server (`billing-api`) enforces the same
/// rule; this only decides what the phone offers.
extension BillingRole on WorkspaceRole {
  /// Changing, cancelling or resuming the plan spends money: owner only
  /// (web `isOwner`, billing-api `requireRole("owner")`).
  bool get canManageBilling => this == WorkspaceRole.owner;

  /// Receipts are a financial record an admin may need (billing-api
  /// `invoice_pdf` needs admin).
  bool get canDownloadInvoices =>
      this == WorkspaceRole.owner || this == WorkspaceRole.admin;
}

/// Web `formatMoney`: the currency's own format, two decimals, "—" when
/// there is no amount.
String formatBillingMoney(num? amount, String? currency) {
  if (amount == null || amount.isNaN) return '—';
  final code = (currency ?? 'USD').toUpperCase();
  try {
    return NumberFormat.simpleCurrency(
      locale: 'en_IN',
      name: code,
    ).format(amount);
  } catch (_) {
    return '$amount $code'.trim();
  }
}

/// Web `formatPlanPrice` (lib/pricing.ts): "Free", or "₹299" / "₹299.50" with
/// a "/mo" or "/yr" period.
({String price, String period}) formatPlanPrice(BillingPlan plan) {
  if (plan.priceCents <= 0) return (price: 'Free', period: '');
  final major = plan.priceCents / 100;
  // Whole units read better on a plan card; keep paise only when they exist.
  final digits = plan.priceCents % 100 == 0 ? 0 : 2;
  String price;
  try {
    price = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      name: plan.currency,
      decimalDigits: digits,
    ).format(major);
  } catch (_) {
    price = '${plan.currency} ${major.toStringAsFixed(digits)}';
  }
  const periods = {'month': '/mo', 'year': '/yr'};
  return (price: price, period: periods[plan.interval] ?? '/${plan.interval}');
}

/// Web `formatDate`: "26 Nov 2026", or "—".
String formatBillingDate(DateTime? d) =>
    d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

/// Web `contactUpgradeHref`: a `mailto:` for a manual upgrade request,
/// pre-filled so the reply is actionable. Encoded like `encodeURIComponent`
/// (spaces as %20, not +, which mail apps would show literally).
Uri contactUpgradeUri(String? planName, String? workspace) {
  final subject = planName == null ? 'Upgrade my plan' : 'Upgrade to $planName';
  final body = [
    planName == null
        ? "I'd like to upgrade my plan."
        : "I'd like to upgrade to the $planName plan.",
    if (workspace != null && workspace.isNotEmpty) 'Workspace: $workspace',
  ].join('\n\n');
  return Uri.parse(
    'mailto:$kBillingSupportEmail'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}
