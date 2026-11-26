import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../web_link/presentation/web_link_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/membership.dart';
import '../application/billing_providers.dart';
import '../domain/billing.dart';

/// Billing & plans (web `Billing.tsx`): the workspace's plan and its status,
/// the plans on offer with the current one marked, and the payment history.
/// Menu-gated, online-only.
///
/// Nothing here takes a payment. Upgrading, cancelling and resuming open the
/// web billing page in the browser, where checkout is a Paddle overlay; when
/// no plan can be bought yet, the owner gets the web's "Contact us" mail.
/// The owner may change the plan, an owner or admin may get receipts, and
/// everyone else sees it read-only (billing-api enforces the same).
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  static const route = '/billing';

  /// The web page under `/app/`.
  static const webPath = 'billing';

  static const _title = 'Billing & plans';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(menuStatusProvider(FeatureMenu.billing)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: _title,
        body: MenuLockedView(
          feature: 'Billing',
          icon: Icons.credit_card_outlined,
        ),
      );
    }
    final online = ref.watch(isOnlineProvider);
    final overview = ref.watch(billingOverviewProvider);

    void reload() {
      ref.invalidate(billingOverviewProvider);
      ref.invalidate(billingPlansProvider);
      ref.invalidate(planFeaturesProvider);
    }

    return AppPage(
      title: _title,
      subtitle: 'Your subscription and payment receipts',
      padBody: false,
      actions: [
        RoundIconButton(
          icon: Icons.open_in_new_rounded,
          tooltip: 'Open billing on the web',
          onPressed: () => openWebAppPage(context, ref, webPath),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => reload(),
        child: !online && !overview.hasValue
            ? const _Scrollable(child: _OfflineView())
            : overview.when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    _Scrollable(child: ErrorView(e, onRetry: reload)),
                data: (o) => _BillingBody(overview: o, online: online),
              ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: c.maxHeight, child: child),
    ),
  );
}

class _OfflineView extends StatelessWidget {
  const _OfflineView();

  @override
  Widget build(BuildContext context) => const EmptyView(
    icon: Icons.cloud_off_outlined,
    title: "You're offline",
    message: 'Billing needs a connection. Connect, then pull to refresh.',
  );
}

class _BillingBody extends ConsumerStatefulWidget {
  const _BillingBody({required this.overview, required this.online});

  final BillingOverview overview;
  final bool online;

  @override
  ConsumerState<_BillingBody> createState() => _BillingBodyState();
}

class _BillingBodyState extends ConsumerState<_BillingBody> {
  /// The transaction whose receipt is being fetched.
  String? _fetching;

  Future<void> _open(Uri uri, String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await ref.read(urlOpenerProvider)(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failure)));
  }

  Future<void> _receipt(BillingTransaction t) async {
    setState(() => _fetching = t.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = await ref.read(billingControllerProvider).invoiceUrl(t.id);
      if (!mounted) return;
      await _open(uri, "Couldn't open the browser.");
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapError(e).message)));
    } finally {
      if (mounted) setState(() => _fetching = null);
    }
  }

  void _contact(String planName) {
    final workspace = ref.read(currentMembershipProvider)?.name;
    _open(
      contactUpgradeUri(planName, workspace),
      "Couldn't open your mail app. Write to $kBillingSupportEmail.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.overview;
    final online = widget.online;
    final role = ref.watch(billingRoleProvider);
    final canManage = online && (role?.canManageBilling ?? false);
    final canReceipts = role?.canDownloadInvoices ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        if (!online)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: _Note(
              "You're offline — billing actions need a connection.",
              warning: true,
              icon: Icons.cloud_off_outlined,
            ),
          ),
        _PlanCard(
          overview: o,
          canManage: canManage,
          onManage: () => openWebAppPage(context, ref, BillingScreen.webPath),
        ),
        if (!(role?.canManageBilling ?? false))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _Note(_readOnlyNote(role), icon: Icons.lock_outline),
          ),
        _PlansSection(
          overview: o,
          canManage: canManage,
          onUpgrade: () => openWebAppPage(context, ref, BillingScreen.webPath),
          onContact: _contact,
        ),
        _HistorySection(
          transactions: o.transactions,
          canReceipts: canReceipts,
          online: online,
          fetching: _fetching,
          onReceipt: _receipt,
        ),
      ],
    );
  }
}

String _readOnlyNote(WorkspaceRole? role) => switch (role) {
  WorkspaceRole.admin =>
    'Only the workspace owner can change or cancel the plan. You can '
        'download receipts.',
  _ => 'Only the workspace owner can change or cancel the plan.',
};

/// The current plan: name, status, price, period and what happens next.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.overview,
    required this.canManage,
    required this.onManage,
  });

  final BillingOverview overview;
  final bool canManage;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final o = overview;
    final s = o.subscription;
    final price = o.priceLabel;
    final ends = formatBillingDate(
      o.scheduledCancel ? s?.cancelAt : s?.currentPeriodEnd,
    );
    // Cancel / resume act on the Paddle subscription, so they only make sense
    // when there is one; a hand-assigned plan has nothing there to change.
    final webAction = !canManage || !o.isActive || !o.hasPaddleSubscription
        ? null
        : o.scheduledCancel
        ? 'Resume subscription on the web'
        : 'Cancel subscription on the web';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Current plan'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s?.planName ?? 'No active plan',
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
              _StatusBadge(status: o.status, label: o.statusLabel),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              price,
              style: AppTypography.display.copyWith(
                color: palette.ink,
                fontSize: 24,
                height: 30 / 24,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: AppSpacing.lg),
          _Detail(label: 'Current period', value: o.periodLabel),
          _Detail(
            label: o.scheduledCancel ? 'Cancels on' : 'Next billing date',
            value: ends,
          ),
          _Detail(
            label: 'Customer ID',
            value: s?.customerId ?? '—',
            mono: true,
          ),
          if (o.scheduledCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            _Note(
              'Your subscription will end on $ends. '
              "You'll keep access until then.",
              warning: true,
              icon: Icons.verified_user_outlined,
            ),
          ],
          if (webAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(webAction),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _Note(
              'Billing changes are made on the web page, in your browser.',
              icon: Icons.info_outline,
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.body.copyWith(
      color: context.palette.ink,
      fontFamily: mono ? 'monospace' : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 2),
          // An id is something people copy into a support mail.
          if (mono)
            SelectableText(value, style: style)
          else
            Text(value, style: style),
        ],
      ),
    );
  }
}

/// Status pill in the web's colours: green live, blue trial, amber at risk,
/// red cancelled, grey otherwise.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tone(context, status);
    return StatusPill(label, background: bg, foreground: fg);
  }
}

(Color, Color) _tone(BuildContext context, String status) {
  final dark = context.palette.isDark;
  return switch (status) {
    'active' || 'completed' || 'paid' =>
      dark
          ? (AppColors.mintDark, AppColors.mintFgDark)
          : (AppColors.mintLight, AppColors.mintFgLight),
    'trialing' || 'billed' =>
      dark
          ? (AppColors.skyDark, AppColors.skyFgDark)
          : (AppColors.skyLight, AppColors.skyFgLight),
    'past_due' || 'paused' =>
      dark
          ? (AppColors.butterDark, AppColors.butterFgDark)
          : (AppColors.butterLight, AppColors.butterFgLight),
    'canceled' =>
      dark
          ? (AppColors.coralDark, AppColors.coralFgDark)
          : (AppColors.coralLight, AppColors.coralFgLight),
    _ => (context.palette.subtle, context.palette.muted),
  };
}

/// The plans on offer, the current one marked. Self-serve: "Upgrade to X"
/// opens the web billing page, whose checkout takes the payment. Otherwise
/// the web's hand-run upgrade: the catalogue and a "Contact us" mail.
class _PlansSection extends ConsumerWidget {
  const _PlansSection({
    required this.overview,
    required this.canManage,
    required this.onUpgrade,
    required this.onContact,
  });

  final BillingOverview overview;
  final bool canManage;
  final VoidCallback onUpgrade;
  final void Function(String planName) onContact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plans = ref.watch(billingPlansProvider);
    final blurbs = ref.watch(planFeaturesProvider).value ?? const {};

    return plans.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle('Plans'),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Plans'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Note(
                  "Couldn't load the plans. ${mapError(e).message}",
                  warning: true,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(billingPlansProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
      data: (p) {
        // The web shows no Plans section when there is nothing to list.
        if (p.plans.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Plans'),
            if (!p.selfServe)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.md),
                child: Text(
                  "Self-serve checkout isn't available yet — we set up "
                  'upgrades by hand. Get in touch and we\'ll switch your '
                  'workspace over, usually the same day.',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
              ),
            for (final plan in p.plans)
              _PlanOption(
                plan: plan,
                selfServe: p.selfServe,
                current: overview.isCurrentPlan(plan.name),
                blurb: blurbs[plan.name.trim().toLowerCase()],
                canManage: canManage,
                onUpgrade: onUpgrade,
                onContact: () => onContact(plan.name),
              ),
            if (p.selfServe && canManage)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: _Note(
                  'Checkout opens in your browser. Payment never happens in '
                  'the app.',
                  icon: Icons.lock_outline,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.selfServe,
    required this.current,
    required this.blurb,
    required this.canManage,
    required this.onUpgrade,
    required this.onContact,
  });

  final BillingPlan plan;
  final bool selfServe;
  final bool current;
  final PlanBlurb? blurb;
  final bool canManage;
  final VoidCallback onUpgrade;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The web formats the two lists differently; keep each as it reads there.
    final String price;
    final String period;
    if (selfServe) {
      price = formatBillingMoney(plan.priceCents / 100, plan.currency);
      period = '/ ${plan.interval}';
    } else {
      final f = formatPlanPrice(plan);
      price = f.price;
      period = f.period;
    }
    final b = blurb;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: price,
                          style: AppTypography.display.copyWith(
                            color: palette.ink,
                            fontSize: 22,
                            height: 28 / 22,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          children: [
                            if (period.isNotEmpty)
                              TextSpan(
                                text: ' $period',
                                style: AppTypography.body.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (current)
                  StatusPill(
                    'Current plan',
                    background: palette.tint,
                    foreground: palette.accentText,
                    icon: Icons.check_rounded,
                  ),
              ],
            ),
            if (b != null && !b.isEmpty) ...[
              if (b.blurb != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  b.blurb!,
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
              ],
              if (b.features.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              for (final f in b.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: palette.accentText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTypography.body.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (!current && canManage) ...[
              const SizedBox(height: AppSpacing.md),
              if (selfServe)
                PillButton(
                  label: 'Upgrade to ${plan.name}',
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onPressed: onUpgrade,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Contact us'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Payment history from Paddle, newest first, with a receipt per paid row.
class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.transactions,
    required this.canReceipts,
    required this.online,
    required this.fetching,
    required this.onReceipt,
  });

  final List<BillingTransaction> transactions;
  final bool canReceipts;
  final bool online;
  final String? fetching;
  final void Function(BillingTransaction t) onReceipt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final n = transactions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Payment history',
          trailing: n == 0
              ? null
              : Text(
                  n == 1 ? '1 record' : '$n records',
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
        ),
        if (n == 0)
          const CardEmpty(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            message: "Your invoices will appear here once you're charged.",
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: palette.line,
                    ),
                  _TransactionRow(
                    t: transactions[i],
                    showReceipt: canReceipts,
                    enabled: online && fetching == null,
                    busy: fetching == transactions[i].id,
                    onReceipt: () => onReceipt(transactions[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.t,
    required this.showReceipt,
    required this.enabled,
    required this.busy,
    required this.onReceipt,
  });

  final BillingTransaction t;
  final bool showReceipt;
  final bool enabled;
  final bool busy;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = _tone(context, t.status);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        showReceipt ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatBillingDate(t.date),
                  style: AppTypography.bodyStrong.copyWith(color: palette.ink),
                ),
                Text(
                  t.invoiceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: palette.muted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.totalLabel,
                style: AppTypography.bodyStrong.copyWith(
                  color: palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              StatusPill(t.statusLabel, background: bg, foreground: fg),
            ],
          ),
          if (showReceipt)
            busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Download receipt',
                    icon: const Icon(Icons.download_rounded),
                    onPressed: enabled && t.canDownload ? onReceipt : null,
                  ),
        ],
      ),
    );
  }
}

/// A small inline note (amber for warnings).
class _Note extends StatelessWidget {
  const _Note(this.text, {this.warning = false, this.icon});

  final String text;
  final bool warning;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = warning ? context.finance.warning : context.palette.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? Icons.info_outline, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
