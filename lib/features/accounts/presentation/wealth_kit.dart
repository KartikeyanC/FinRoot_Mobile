import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/design.dart';

/// Small private helpers shared by the wealth screens (accounts, budget,
/// goals, investments, net worth, debts, insurance, subscriptions, calendar,
/// price alerts). Built from the NineFlow kit; nothing here changes behaviour.

/// A pastel pair: tinted background + its matching darker foreground.
@immutable
class Tone {
  const Tone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

/// The category pastel pairs, resolved for the current brightness.
abstract final class Tones {
  static Tone mint(BuildContext c) => _pick(
    c,
    AppColors.mintLight,
    AppColors.mintFgLight,
    AppColors.mintDark,
    AppColors.mintFgDark,
  );
  static Tone coral(BuildContext c) => _pick(
    c,
    AppColors.coralLight,
    AppColors.coralFgLight,
    AppColors.coralDark,
    AppColors.coralFgDark,
  );
  static Tone sky(BuildContext c) => _pick(
    c,
    AppColors.skyLight,
    AppColors.skyFgLight,
    AppColors.skyDark,
    AppColors.skyFgDark,
  );
  static Tone butter(BuildContext c) => _pick(
    c,
    AppColors.butterLight,
    AppColors.butterFgLight,
    AppColors.butterDark,
    AppColors.butterFgDark,
  );
  static Tone violet(BuildContext c) => _pick(
    c,
    AppColors.violetLight,
    AppColors.violetFgLight,
    AppColors.violetDark,
    AppColors.violetFgDark,
  );
  static Tone rose(BuildContext c) => _pick(
    c,
    AppColors.roseLight,
    AppColors.roseFgLight,
    AppColors.roseDark,
    AppColors.roseFgDark,
  );
  static Tone teal(BuildContext c) => _pick(
    c,
    AppColors.tealLight,
    AppColors.tealFgLight,
    AppColors.tealDark,
    AppColors.tealFgDark,
  );

  /// Accent (theme) pair.
  static Tone accent(BuildContext c) =>
      Tone(c.palette.tint, c.palette.accentText);

  /// Cycles the pairs by index, for lists that want variety.
  static Tone byIndex(BuildContext c, int i) => switch (i % 6) {
    0 => sky(c),
    1 => mint(c),
    2 => butter(c),
    3 => violet(c),
    4 => rose(c),
    _ => teal(c),
  };

  static Tone _pick(BuildContext c, Color bl, Color fl, Color bd, Color fd) =>
      c.palette.isDark ? Tone(bd, fd) : Tone(bl, fl);
}

/// An [IconTile] in a pastel [Tone].
class ToneTile extends StatelessWidget {
  const ToneTile({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 44,
    this.round = false,
  });
  final IconData icon;
  final Tone tone;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) => IconTile(
    icon: icon,
    size: size,
    tint: tone.bg,
    color: tone.fg,
    round: round,
  );
}

/// A [StatusPill] in a [Tone].
class TonePill extends StatelessWidget {
  const TonePill(
    this.label,
    this.tone, {
    super.key,
    this.dot = true,
    this.icon,
  });
  final String label;
  final Tone tone;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => StatusPill(
    label,
    background: tone.bg,
    foreground: tone.fg,
    dot: dot,
    icon: icon,
  );
}

/// A thin, fully round progress bar (value 0..1).
class SlimBar extends StatelessWidget {
  const SlimBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      backgroundColor: context.palette.line,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}

/// The round "..." overflow menu used on cards (edit / delete …).
class RowMenu extends StatelessWidget {
  const RowMenu({
    super.key,
    required this.onSelected,
    required this.items,
    this.tooltip = 'More',
  });
  final ValueChanged<String> onSelected;
  final List<PopupMenuItem<String>> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    onSelected: onSelected,
    itemBuilder: (_) => items,
    child: SizedBox.square(
      dimension: 48,
      child: Icon(Icons.more_vert_rounded, color: context.palette.muted),
    ),
  );
}

/// A muted 12px semibold label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.label.copyWith(color: context.palette.muted),
    ),
  );
}

/// Label above a field, with the standard gap under it.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [FieldLabel(label), child],
    ),
  );
}

/// The frame every add / edit sheet shares: bold 18px title, optional muted
/// subtitle, labelled fields, an error box, a full-width gradient pill and a
/// Cancel outline pill. The sheet theme supplies the 24px top radius and the
/// 40px grab handle.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.busy = false,
    this.error,
    this.extraActions = const [],
    this.formKey,
    this.pinActions = false,
  });

  /// Keep the primary / Cancel buttons fixed under the scrolling fields, so
  /// they stay on screen on a small phone with a long form.
  final bool pinActions;

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool busy;
  final String? error;
  final List<Widget> extraActions;
  final Key? formKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final header = <Widget>[
      Text(title, style: AppTypography.title.copyWith(color: palette.ink)),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle!,
            style: AppTypography.body.copyWith(color: palette.muted),
          ),
        ),
      const SizedBox(height: AppSpacing.xl),
    ];
    final errorBox = error == null
        ? null
        : Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: AppRadius.field,
            ),
            child: Text(
              error!,
              style: AppTypography.body.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          );
    final actions = <Widget>[
      FilledButton(
        onPressed: busy ? null : onPrimary,
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(primaryLabel),
      ),
      for (final a in extraActions) ...[
        const SizedBox(height: AppSpacing.sm),
        a,
      ],
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: busy ? null : () => Navigator.of(context).maybePop(),
        child: const Text('Cancel'),
      ),
    ];
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    Widget body;
    if (pinActions) {
      body = Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...header, ...children, ?errorBox],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          inset + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...header, ...children, ?errorBox, ...actions],
        ),
      );
    }
    if (formKey != null) body = Form(key: formKey, child: body);
    return body;
  }
}

/// A destructive-confirm dialog with round buttons. Returns true on confirm.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AppButtonStyles.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Standard scroll padding for wealth lists (page gutters come from AppPage).
const EdgeInsets kWealthListPadding = EdgeInsets.only(
  top: AppSpacing.xs,
  bottom: 96,
);

/// The kit's [SegmentedBar] with the segment fill actually painted: its
/// `ColoredBox` children have no child, so inside the Row they collapse to zero
/// height and only the empty track shows. This one fills the bar's height.
class SplitBar extends StatelessWidget {
  const SplitBar(this.segments, {super.key, this.total});

  final List<BarSegment> segments;
  final double? total;

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
    );
  }
}

/// A tap-to-pick date box that takes part in form validation — used by the
/// debt, subscription and insurance forms.
class DatePickField extends FormField<DateTime> {
  DatePickField({
    super.key,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helper,
    bool enabled = true,
    super.validator,
  }) : super(
         initialValue: value,
         builder: (state) {
           final context = state.context;
           Future<void> pick() async {
             FocusScope.of(context).unfocus();
             var initial = value ?? DateTime.now();
             if (initial.isBefore(firstDate)) initial = firstDate;
             if (initial.isAfter(lastDate)) initial = lastDate;
             final d = await showDatePicker(
               context: context,
               initialDate: initial,
               firstDate: firstDate,
               lastDate: lastDate,
               helpText: label,
             );
             if (d != null) {
               state.didChange(d);
               onChanged(d);
             }
           }

           return LabeledField(
             label: label,
             child: InkWell(
               onTap: enabled ? pick : null,
               borderRadius: AppRadius.field,
               child: InputDecorator(
                 isEmpty: value == null,
                 decoration: InputDecoration(
                   enabled: enabled,
                   prefixIcon: const Icon(Icons.event_outlined),
                   hintText: 'Pick a date',
                   helperText: helper,
                   helperMaxLines: 3,
                   errorText: state.errorText,
                 ),
                 child: Text(
                   value == null ? '' : DateFormat('d MMM yyyy').format(value),
                 ),
               ),
             ),
           );
         },
       );
}
