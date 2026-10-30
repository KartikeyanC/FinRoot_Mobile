import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';
import 'gradient_fab.dart';

/// The NineFlow screen vocabulary for the phone app. Every screen is built
/// from these so the app reads as one system:
///
///   [AppPage]       screen frame: big bold title, subtitle, round back button
///   [Eyebrow]       the small uppercase label over a figure ("TODAY'S LOAD")
///   [MetricCard]    eyebrow + big figure + status line + optional pill action
///   [StatStrip]     one card of 3-5 figures split by hairlines
///   [SegmentedBar]  thin multi-colour progress bar with a dot legend
///   [InfoPill]      the round banner ("Plan your day · 2 min")
///   [IconTile]      the 40-48dp tinted rounded square that holds an icon
///   [ListRow]       a card row: icon tile, title, subtitle, trailing, chevron
///   [FilterPills]   a horizontally scrolling row of round chips
///   [CardEmpty]     an empty state inside a card, with a pill action
///   [PillButton]    the gradient pill CTA, with an optional circled arrow
///
/// All sizes follow design-system/finroot-nineflow-tokens.css.

/// Screen frame. Replaces `Scaffold` + `AppBar` on every screen.
///
/// NineFlow phone screens have no app bar: a large bold title (30/36, -0.025em)
/// sits on the page colour with an optional muted subtitle under it, and
/// pushed screens get a round back button to the left of the title row.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.actions = const [],
    this.showBack,
    this.floatingActionButton,
    this.header,
    this.bottom,
    required this.body,
    this.padBody = true,
  });

  final String title;
  final String? subtitle;

  /// Small uppercase line above the title ("PREFERENCES").
  final String? eyebrow;

  /// Round icon buttons on the right of the title row.
  final List<Widget> actions;

  /// Defaults to true when the route can pop.
  final bool? showBack;
  final Widget? floatingActionButton;

  /// Extra content between the title and the body (a segmented control, a
  /// search field, filter pills).
  final Widget? header;
  final PreferredSizeWidget? bottom;
  final Widget body;

  /// Wrap the body in the 16dp screen gutter. Turn off for lists that bring
  /// their own padding or full-bleed content.
  final bool padBody;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canPop = Navigator.of(context).canPop();
    final back = showBack ?? canPop;
    return Scaffold(
      backgroundColor: palette.page,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (back) ...[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) Eyebrow(eyebrow!),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.display.copyWith(
                              color: palette.ink,
                              fontSize: back ? 24 : 30,
                              height: back ? 32 / 24 : 36 / 30,
                            ),
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: AppTypography.body.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final a in actions) ...[
                    const SizedBox(width: AppSpacing.sm),
                    a,
                  ],
                ],
              ),
            ),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  0,
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                ),
                child: header,
              ),
            Expanded(
              child: padBody
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                      ),
                      child: body,
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }
}

/// A 40dp round icon button on the card colour with a hairline: back, close,
/// search, the small controls in a title row.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.card,
        shape: CircleBorder(side: BorderSide(color: palette.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 20, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

/// "TODAY'S LOAD": 10-11sp semibold, wide tracking, muted.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTypography.micro.copyWith(
      color: color ?? context.palette.muted,
      fontSize: 11,
      letterSpacing: 1.4,
    ),
  );
}

/// Section title inside a scroll view: title, optional trailing text action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, AppSpacing.xl, 4, AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.section.copyWith(
                color: context.palette.ink,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// NineFlow's headline card: an [Eyebrow], a big figure, one coloured status
/// line, optional [child] content (a [SegmentedBar]) and an optional
/// [PillButton] action.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.eyebrow,
    required this.figure,
    this.figureSuffix,
    this.status,
    this.statusColor,
    this.child,
    this.action,
    this.onTap,
  });

  final String eyebrow;
  final String figure;

  /// Muted text after the figure ("of ₹80,000").
  final String? figureSuffix;
  final String? status;
  final Color? statusColor;
  final Widget? child;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(
                figure,
                style: AppTypography.display.copyWith(
                  color: palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (figureSuffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    figureSuffix!,
                    style: AppTypography.body.copyWith(color: palette.muted),
                  ),
                ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              status!,
              style: AppTypography.bodyStrong.copyWith(
                color: statusColor ?? palette.muted,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
          if (child != null) ...[
            const SizedBox(height: AppSpacing.lg),
            child!,
          ],
        ],
      ),
    );
  }
}

/// One figure in a [StatStrip].
class Stat {
  const Stat(this.value, this.label, {this.color});

  final String value;
  final String label;
  final Color? color;
}

/// A single card of 2-5 figures split by vertical hairlines (NineFlow's
/// "5 Tasks / 0 Done / 2 Working…" strip).
class StatStrip extends StatelessWidget {
  const StatStrip(this.stats, {super.key});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: palette.line),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        stats[i].value,
                        style: AppTypography.display.copyWith(
                          fontSize: 24,
                          height: 30 / 24,
                          color: stats[i].color ?? palette.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A slice of a [SegmentedBar].
class BarSegment {
  const BarSegment(this.label, this.value, this.color, {this.amountLabel});

  final String label;
  final double value;
  final Color color;

  /// Shown in the legend after the label ("12h 55m").
  final String? amountLabel;
}

/// A thin, fully round, multi-colour bar with a dot legend under it.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar(this.segments, {super.key, this.total, this.legend = true});

  final List<BarSegment> segments;

  /// Defaults to the sum; pass a larger value to leave an empty track.
  final double? total;
  final bool legend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sum = segments.fold<double>(0, (a, s) => a + s.value);
    final whole = (total ?? sum) <= 0 ? 1.0 : (total ?? sum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.chip,
          child: SizedBox(
            height: 10,
            child: ColoredBox(
              color: palette.line,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in segments)
                    if (s.value > 0)
                      Expanded(
                        flex: (s.value / whole * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: s.color),
                      ),
                  if (sum < whole)
                    Expanded(
                      flex: ((whole - sum) / whole * 1000).round().clamp(
                        0,
                        1000,
                      ),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (legend) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.amountLabel == null
                          ? s.label
                          : '${s.label} ${s.amountLabel}',
                      style: AppTypography.label.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The round banner: tinted icon tile, text, optional trailing close.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    this.onTap,
    this.onClose,
    this.tone,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  /// Tile tint; defaults to the accent tint.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      shape: StadiumBorder(side: BorderSide(color: palette.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconTile(icon: icon, size: 36, round: true, tint: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: text,
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                    children: [
                      if (detail != null)
                        TextSpan(
                          text: '  ·  $detail',
                          style: AppTypography.body.copyWith(
                            color: palette.muted,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClose != null)
                InkResponse(
                  onTap: onClose,
                  radius: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.close_rounded, size: 18, color: palette.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tinted rounded square (or circle) that holds an icon.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.tint,
    this.color,
    this.round = false,
  });

  final IconData icon;
  final double size;

  /// Background; defaults to the accent tint.
  final Color? tint;

  /// Icon colour; defaults to the accent text colour.
  final Color? color;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = color ?? palette.accentText;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint ?? palette.tint,
        borderRadius: round
            ? BorderRadius.circular(size)
            : BorderRadius.circular(size >= 44 ? 16 : 12),
      ),
      child: Icon(icon, size: size * 0.45, color: fg),
    );
  }
}

/// A card row: [IconTile], title + subtitle, trailing widget, optional chevron.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleMaxLines = 1,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) leading! else if (icon != null) IconTile(icon: icon!),
          if (leading != null || icon != null) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: palette.faint),
          ],
        ],
      ),
    );
  }
}

/// One option in [FilterPills].
class FilterPill<T> {
  const FilterPill(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A scrolling row of round chips; the selected one carries the brand
/// gradient with white text. Fades out at the right edge so a clipped chip
/// reads as "scrolls" rather than "cut off".
class FilterPills<T> extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterPill<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.92, 1],
      ).createShader(r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: AppSpacing.xxl),
        child: Row(
          children: [
            for (final o in options) ...[
              Builder(
                builder: (context) {
                  final on = o.value == selected;
                  return Semantics(
                    button: true,
                    selected: on,
                    label: o.label,
                    excludeSemantics: true,
                    child: Material(
                      color: on ? Colors.transparent : palette.card,
                      shape: StadiumBorder(
                        side: BorderSide(color: on ? Colors.transparent : palette.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: on
                            ? ShapeDecoration(
                                shape: const StadiumBorder(),
                                gradient: palette.gradient,
                              )
                            : null,
                        child: InkWell(
                          onTap: () => onSelected(o.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (o.icon != null) ...[
                                  Icon(
                                    o.icon,
                                    size: 16,
                                    color: on ? Colors.white : palette.muted,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  o.label,
                                  style: AppTypography.bodyStrong.copyWith(
                                    color: on ? Colors.white : palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// A status pill: tinted background, matching darker text, optional dot.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    required this.background,
    required this.foreground,
    this.dot = false,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: background, borderRadius: AppRadius.chip),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: foreground,
            height: 20 / 12,
          ),
        ),
      ],
    ),
  );
}

/// The gradient pill CTA. With [trailingArrow] it ends in a circled arrow, as
/// in NineFlow's "Move 1 lower-priority to tomorrow  ➜".
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingArrow = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool trailingArrow;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(color: Colors.white),
          ),
        ),
        if (trailingArrow) ...[
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
          ),
        ],
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: palette.gradient,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  trailingArrow ? AppSpacing.sm : AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An empty state inside a card: tinted icon tile, bold title, one muted
/// hint and an optional pill action. Replaces bare centred-icon empties.
class CardEmpty extends StatelessWidget {
  const CardEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PillButton(label: actionLabel!, onPressed: onAction, icon: Icons.add_rounded),
          ],
        ],
      ),
    );
  }
}

/// The page's own "+ Thing" action. Uses the shared gradient pill so every
/// screen's add button matches.
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.label, required this.onPressed, this.icon = Icons.add_rounded});

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GradientExtendedFab(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}
