import 'package:finroot_mobile/features/billing/domain/billing.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fakes.dart';

void main() {
  group('billing-api payload', () {
    test('reads the subscription, transactions and role', () {
      final o = BillingOverview.fromJson(
        activeCanopy(transactions: [paidTxn('txn_0123456789abcdef')]),
      );
      expect(o.subscription!.planName, 'Canopy');
      expect(o.status, 'active');
      expect(o.isActive, isTrue);
      expect(o.scheduledCancel, isFalse);
      expect(o.hasPaddleSubscription, isTrue);
      expect(o.priceLabel, '₹299.00 / month');
      expect(o.periodLabel, '26 Nov 2026 → 26 Dec 2026');
      expect(o.role, WorkspaceRole.owner);
      expect(o.isCurrentPlan('Canopy'), isTrue);
      expect(o.isCurrentPlan('Heritage'), isFalse);

      final t = o.transactions.single;
      expect(t.invoiceLabel, 'INV-txn_0123456789abcdef');
      expect(t.totalLabel, '₹299.00');
      expect(t.statusLabel, 'COMPLETED');
      expect(t.canDownload, isTrue);
    });

    test('no subscription row reads as inactive, nothing current', () {
      final o = BillingOverview.fromJson(const {
        'subscription': null,
        'transactions': <Object>[],
        'role': 'viewer',
      });
      expect(o.status, 'inactive');
      expect(o.statusLabel, 'INACTIVE');
      expect(o.isActive, isFalse);
      expect(o.priceLabel, isNull);
      expect(o.periodLabel, '—');
      expect(o.isCurrentPlan('Roots'), isFalse);
      expect(o.role, WorkspaceRole.viewer);
    });

    test('a cancelled plan is not current; a scheduled cancel is flagged', () {
      final cancelled = BillingOverview.fromJson(
        activeCanopy(status: 'canceled', cancelAt: '2026-12-26T12:00:00Z'),
      );
      expect(cancelled.isActive, isFalse);
      expect(cancelled.scheduledCancel, isFalse);
      expect(cancelled.isCurrentPlan('Canopy'), isFalse);

      final ending = BillingOverview.fromJson(
        activeCanopy(cancelAt: '2026-12-26T12:00:00Z'),
      );
      expect(ending.scheduledCancel, isTrue);
      expect(ending.statusLabel, 'ACTIVE');

      final pastDue = BillingOverview.fromJson(
        activeCanopy(status: 'past_due'),
      );
      expect(pastDue.isActive, isTrue);
      expect(pastDue.statusLabel, 'PAST DUE');
    });

    test('a transaction without an invoice number shows the id tail', () {
      final t = BillingTransaction.fromJson(const {
        'id': 'txn_0123456789abcdef',
        'status': 'past_due',
        'created_at': '2026-11-26T12:00:00Z',
        'currency_code': 'USD',
      });
      expect(t.invoiceLabel, '6789abcdef');
      expect(t.totalLabel, '—');
      expect(t.statusLabel, 'PAST DUE');
      expect(t.canDownload, isFalse);
      expect(formatBillingDate(t.date), '26 Nov 2026');
    });
  });

  group('plan prices read as the web shows them', () {
    test('catalogue (formatPlanPrice)', () {
      expect(formatPlanPrice(roots), (price: 'Free', period: ''));
      expect(formatPlanPrice(canopy), (price: '₹299', period: '/mo'));
      expect(
        formatPlanPrice(
          const BillingPlan(
            id: 'x',
            name: 'Yearly',
            priceCents: 299950,
            currency: 'INR',
            interval: 'year',
          ),
        ),
        (price: '₹2,999.50', period: '/yr'),
      );
    });

    test('money (formatMoney)', () {
      expect(formatBillingMoney(299, 'INR'), '₹299.00');
      expect(formatBillingMoney(129900, 'INR'), '₹1,29,900.00');
      expect(formatBillingMoney(9, 'usd'), r'$9.00');
      expect(formatBillingMoney(null, 'INR'), '—');
    });
  });

  test('landing pricing cards give each linked plan its features', () {
    final blurbs = planBlurbsFromPricing({
      'cards': [
        {
          'plan': 'Canopy',
          'blurb': 'For households serious about wealth.',
          'features': ['Unlimited budgets & goals', ''],
        },
        {
          'plan': '',
          'name': 'Talk to us',
          'features': ['Nothing to buy'],
        },
        'not a card',
      ],
    });
    expect(blurbs.keys, ['canopy']);
    expect(blurbs['canopy']!.blurb, 'For households serious about wealth.');
    expect(blurbs['canopy']!.features, ['Unlimited budgets & goals']);
    expect(planBlurbsFromPricing(null), isEmpty);
  });

  test('contact mail is pre-filled like the web', () {
    final uri = contactUpgradeUri('Canopy', 'Kumar Household');
    expect(uri.scheme, 'mailto');
    expect(uri.path, kBillingSupportEmail);
    expect(uri.toString(), contains('subject=Upgrade%20to%20Canopy'));
    expect(
      Uri.decodeComponent(uri.toString().split('body=').last),
      "I'd like to upgrade to the Canopy plan.\n\nWorkspace: Kumar Household",
    );
  });

  test('only an owner manages billing; an admin may get receipts', () {
    expect(WorkspaceRole.owner.canManageBilling, isTrue);
    expect(WorkspaceRole.admin.canManageBilling, isFalse);
    expect(WorkspaceRole.viewer.canManageBilling, isFalse);
    expect(WorkspaceRole.owner.canDownloadInvoices, isTrue);
    expect(WorkspaceRole.admin.canDownloadInvoices, isTrue);
    expect(WorkspaceRole.viewer.canDownloadInvoices, isFalse);
  });
}
