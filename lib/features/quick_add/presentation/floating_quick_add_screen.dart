import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/quick_add_controller.dart';
import '../domain/quick_add_draft.dart';

/// Route of the floating Quick Add. Opened only by Android's
/// QuickAddDialogActivity (quick-settings tile / app-icon shortcut), which
/// shows it in a transparent window over whatever app the person is in.
const floatingQuickAddPath = '/quick-add-float';

/// One of the six quick categories, and what it saves as. FinRoot has no
/// "Groceries" or "Bills" category, so those map onto the nearest existing
/// one, with a note where the mapping loses information.
class QuickCategory {
  const QuickCategory(this.label, this.icon, this.category, [this.note]);
  final String label;
  final IconData icon;
  final String category;
  final String? note;
}

const quickCategories = [
  QuickCategory('Food', Icons.restaurant, 'Food & Dining'),
  QuickCategory('Travel', Icons.directions_car, 'Travel'),
  QuickCategory('Groceries', Icons.local_grocery_store, 'Food & Dining', 'Groceries'),
  QuickCategory('Shopping', Icons.shopping_bag, 'Shopping'),
  QuickCategory('Bills', Icons.receipt_long, 'Utilities'),
  QuickCategory('Others', Icons.more_horiz, 'Other'),
];

/// Null when [raw] is a usable amount, else why not.
String? amountProblem(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null || !v.isFinite) return 'Enter the amount you paid.';
  if (v <= 0) return 'The amount must be more than zero.';
  if (v > 100000000) return 'That amount looks too large.';
  return null;
}

/// A compact card over a dimmed background: amount (focused, decimal
/// keyboard), six category pills, one Save. Saves through the normal Quick
/// Add path — an offline-first local write that syncs — then closes the
/// window at once, returning the person to the app they paid in.
class FloatingQuickAddScreen extends ConsumerStatefulWidget {
  const FloatingQuickAddScreen({super.key, this.close});

  /// Closes the floating window. Defaults to finishing the Android activity.
  final VoidCallback? close;

  @override
  ConsumerState<FloatingQuickAddScreen> createState() => _FloatingQuickAddScreenState();
}

class _FloatingQuickAddScreenState extends ConsumerState<FloatingQuickAddScreen> {
  final _amount = TextEditingController();
  var _category = quickCategories.last;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _close() => (widget.close ?? SystemNavigator.pop)();

  Future<void> _save() async {
    final problem = amountProblem(_amount.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(quickAddControllerProvider).submit(
        kind: QuickAddKind.expense,
        amount: Money.parse(_amount.text),
        occurredAt: DateTime.now(),
        category: _category.category,
        note: _category.note,
      );
      // The write is local (it syncs on its own), so this returns at once.
      _close();
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = f.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim the app underneath; tapping outside the card cancels.
          Positioned.fill(
            child: GestureDetector(
              onTap: _saving ? null : _close,
              child: const ColoredBox(color: Color(0x99000000)),
            ),
          ),
          SafeArea(
            child: Align(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.screenGutter,
                  right: AppSpacing.screenGutter,
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Quick expense', style: tt.titleLarge)),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                                onPressed: _saving ? null : _close,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _amount,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            style: tt.headlineMedium,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final c in quickCategories)
                                ChoiceChip(
                                  avatar: Icon(c.icon, size: 18),
                                  label: Text(c.label),
                                  selected: identical(c, _category),
                                  onSelected: (_) => setState(() => _category = c),
                                ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(_error!, style: tt.bodyMedium?.copyWith(color: scheme.error)),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.check),
                            label: Text(_saving ? 'Saving…' : 'Save expense'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
