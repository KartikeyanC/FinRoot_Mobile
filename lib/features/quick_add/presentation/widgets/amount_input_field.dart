import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/currency.dart';
import '../../../../design/design.dart';

/// The amount-first input at the top of every Quick Add form (brief §7): a
/// large, tabular figure with the currency symbol, number keypad, autofocus.
/// M8's edit sheet reuses it.
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
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      inputFormatters: [
        // digits and at most one dot, up to two decimals
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;
          if (text.isEmpty) return newValue;
          if ('.'.allMatches(text).length > 1) return oldValue;
          final dot = text.indexOf('.');
          if (dot != -1 && text.length - dot - 1 > 2) return oldValue;
          return newValue;
        }),
      ],
      style: AppTypography.moneyHero.copyWith(color: scheme.onSurface),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        prefixText: '${currencySymbol(currency)} ',
        prefixStyle: AppTypography.moneyHero.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintText: '0',
        hintStyle: AppTypography.moneyHero.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.error,
        ),
        errorMaxLines: 2,
      ),
      validator: validator,
    );
  }
}
