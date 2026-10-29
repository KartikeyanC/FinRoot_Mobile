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
/// "Grocery" or "Bills" category, so those map onto the nearest existing
/// one, with a note where the mapping loses information.
class QuickCategory {
  const QuickCategory(this.emoji, this.label, this.category, [this.note]);
  final String emoji;
  final String label;
  final String category;
  final String? note;
}

const quickCategories = [
  QuickCategory('🍔', 'Food', 'Food & Dining'),
  QuickCategory('🚕', 'Travel', 'Travel'),
  QuickCategory('🛒', 'Grocery', 'Food & Dining', 'Groceries'),
  QuickCategory('🛍️', 'Shopping', 'Shopping'),
  QuickCategory('⚡', 'Bills', 'Utilities'),
  QuickCategory('🍿', 'Entertainment', 'Entertainment'),
];

/// What a save with no pill picked is filed under.
const uncategorised = 'Other';

/// Null when [raw] is a usable amount, else why not.
String? amountProblem(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null || !v.isFinite) return 'Enter the amount you paid.';
  if (v <= 0) return 'The amount must be more than zero.';
  if (v > 100000000) return 'That amount looks too large.';
  return null;
}

/// The numpad's backspace key.
const backspaceKey = '⌫';

/// [amount] after pressing [key] on the numpad: a digit, '.' or
/// [backspaceKey]. Keeps at most one '.', two decimals and nine whole digits;
/// a key that would break that is ignored.
String pressKey(String amount, String key) {
  if (key == backspaceKey) {
    return amount.isEmpty ? amount : amount.substring(0, amount.length - 1);
  }
  final dot = amount.indexOf('.');
  if (key == '.') {
    if (dot >= 0) return amount;
    return amount.isEmpty ? '0.' : '$amount.';
  }
  if (dot >= 0) return amount.length - dot > 2 ? amount : '$amount$key';
  if (amount == '0') return key; // no leading zeros
  return amount.length >= 9 ? amount : '$amount$key';
}

/// The amount as the big preview shows it: "₹ 0.00" until something is typed.
String amountPreview(String amount) => amount.isEmpty ? '₹ 0.00' : '₹ $amount';

/// A compact card over a dimmed background: a large amount preview, six
/// category pills, its own numpad (so Android's full keyboard never opens)
/// and one Save. Saves through the normal Quick Add path — an offline-first
/// local write that syncs in the background — then closes the window at
/// once, returning the person to the app they paid in.
class FloatingQuickAddScreen extends ConsumerStatefulWidget {
  const FloatingQuickAddScreen({super.key, this.close});

  /// Closes the floating window. Defaults to finishing the Android activity.
  final VoidCallback? close;

  @override
  ConsumerState<FloatingQuickAddScreen> createState() => _FloatingQuickAddScreenState();
}

class _FloatingQuickAddScreenState extends ConsumerState<FloatingQuickAddScreen> {
  var _amount = '';
  QuickCategory? _category;
  String? _error;
  bool _saving = false;

  void _close() => (widget.close ?? SystemNavigator.pop)();

  void _press(String key) {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      _amount = pressKey(_amount, key);
      _error = null;
    });
  }

  Future<void> _save() async {
    final problem = amountProblem(_amount);
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
        amount: Money.parse(_amount),
        occurredAt: DateTime.now(),
        category: _category?.category ?? uncategorised,
        note: _category?.note,
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 8,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('⚡ Quick Log', style: tt.titleLarge)),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                                onPressed: _saving ? null : _close,
                              ),
                            ],
                          ),
                          Semantics(
                            liveRegion: true,
                            label: 'Amount',
                            child: Text(
                              amountPreview(_amount),
                              key: const Key('quick-add-amount'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: tt.displaySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _amount.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final c in quickCategories)
                                ChoiceChip(
                                  label: Text('${c.emoji} ${c.label}'),
                                  selected: identical(c, _category),
                                  // Tapping the picked pill again un-picks it.
                                  onSelected: (on) => setState(() => _category = on ? c : null),
                                ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(color: scheme.error),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          _Numpad(onKey: _press, onClear: () => setState(() => _amount = '')),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            child: Text(_saving ? 'SAVING…' : 'SAVE TO FINROOT'),
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

/// 3×4 keys: 1–9, then '.', 0 and backspace. Long-press backspace to clear.
class _Numpad extends StatelessWidget {
  const _Numpad({required this.onKey, required this.onClear});

  final ValueChanged<String> onKey;
  final VoidCallback onClear;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', backspaceKey],
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs / 2),
                    child: TextButton(
                      onPressed: () => onKey(key),
                      onLongPress: key == backspaceKey ? onClear : null,
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: key == backspaceKey
                          ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete')
                          : Text(key, style: tt.headlineSmall),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
