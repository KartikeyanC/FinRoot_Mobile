import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/currency.dart';
import '../../../../design/design.dart';

/// The amount-first input at the top of every Quick Add form (brief §7): a
/// large, tabular figure with the currency symbol, number keypad, autofocus.
/// M8's edit sheet reuses it.
///
/// The symbol and the figure are laid out as one centred group that grows
/// with the digits typed — a decoration prefix would pin the symbol to the
/// field's left edge, far from a centred number.
class AmountInputField extends StatelessWidget {
  const AmountInputField({
    super.key,
    required this.controller,
    this.currency = workspaceCurrency,
    this.autofocus = true,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String currency;
  final bool autofocus;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final figure = AppTypography.moneyHero.copyWith(color: scheme.onSurface);

    return FormField<String>(
      initialValue: controller.text,
      validator: validator == null ? null : (_) => validator!(controller.text),
      builder: (field) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ExcludeSemantics(
                child: Text(
                  currencySymbol(currency),
                  style: figure.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: IntrinsicWidth(
                  // The field carries no visible label by design
                  // (amount-first). Give a screen reader one anyway
                  // (WCAG 3.3.2 / 4.1.2).
                  child: Semantics(
                    label: 'Amount in $currency',
                    child: TextField(
                      controller: controller,
                      autofocus: autofocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: field.didChange,
                      onSubmitted: onSubmitted,
                      inputFormatters: [
                        // digits and at most one dot, up to two decimals
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text;
                          if (text.isEmpty) return newValue;
                          if ('.'.allMatches(text).length > 1) return oldValue;
                          final dot = text.indexOf('.');
                          if (dot != -1 && text.length - dot - 1 > 2) {
                            return oldValue;
                          }
                          return newValue;
                        }),
                      ],
                      style: figure,
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: figure.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (field.hasError) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              field.errorText!,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
