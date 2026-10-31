import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../data/local/database_providers.dart';
import '../../../design/design.dart';
import '../../sync/application/background_sync.dart';
import '../../sync/application/sync_engine.dart';
import '../application/quick_add_controller.dart';
import '../data/custom_categories.dart';
import '../data/custom_subcategories.dart';
import '../domain/expense_subcategories.dart';
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

const _window = MethodChannel('finroot/quick_log');

/// Runs after Quick Log has saved, before its window closes. The window hides
/// at once (Android sends it to the back), then waits for the push to reach
/// the server: closing straight away killed the push, leaving the entry
/// "Pending" until the main app was opened. Anything still unsent is handed
/// to Android's background sync. Overridden in tests.
final quickLogAfterSaveProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      await _window.invokeMethod<void>('hide');
    } on Object {
      // Not on Android / no channel: the window just stays until it closes.
    }
    await ref
        .read(syncEngineProvider.notifier)
        .syncNow(force: true)
        .timeout(const Duration(seconds: 20), onTimeout: () {});
    if (await ref.read(appDatabaseProvider).syncOutboxDao.countPending() > 0) {
      await requestSyncSoon();
    }
  };
}, name: 'quickLogAfterSave');

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
  ConsumerState<FloatingQuickAddScreen> createState() =>
      _FloatingQuickAddScreenState();
}

class _FloatingQuickAddScreenState
    extends ConsumerState<FloatingQuickAddScreen> {
  var _amount = '';
  QuickCategory? _category;
  // A workspace category picked instead of one of the six (they exclude each other).
  String? _custom;
  // Optional subcategory under the picked category; saved as `Sub · note`.
  String? _sub;
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
      final note = composeDescription(
        _sub,
        (_custom == null ? _category?.note : null) ?? '',
      );
      await ref
          .read(quickAddControllerProvider)
          .submit(
            kind: QuickAddKind.expense,
            amount: Money.parse(_amount),
            occurredAt: DateTime.now(),
            category: _custom ?? _category?.category ?? uncategorised,
            note: note.isEmpty ? null : note,
          );
      // The write is local, so this returns at once; the window hides, then
      // closes once the entry has been pushed.
      await ref.read(quickLogAfterSaveProvider)();
      _close();
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = f.message;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (name != null && mounted) {
      setState(() {
        _custom = name;
        _category = null;
        _sub = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final pickedCategory = _custom ?? _category?.category;
    final subs = pickedCategory == null
        ? const <String>[]
        : subOptionsFor(
            pickedCategory,
            ref.watch(customSubcategoriesProvider).value ??
                const <String, List<String>>{},
          );

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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
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
                              Expanded(
                                child: Text(
                                  '⚡ Quick Log',
                                  style: tt.titleLarge,
                                ),
                              ),
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
                                color: _amount.isEmpty
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
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
                                  onSelected: (on) => setState(() {
                                    _category = on ? c : null;
                                    _custom = null;
                                    _sub = null;
                                  }),
                                ),
                              for (final name
                                  in ref
                                          .watch(
                                            customExpenseCategoriesProvider,
                                          )
                                          .value ??
                                      const <String>[])
                                ChoiceChip(
                                  label: Text('🏷️ $name'),
                                  selected: name == _custom,
                                  onSelected: (on) => setState(() {
                                    _custom = on ? name : null;
                                    _category = null;
                                    _sub = null;
                                  }),
                                ),
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 18),
                                label: const Text('Add category'),
                                onPressed: _saving ? null : _addCategory,
                              ),
                            ],
                          ),
                          if (subs.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Subcategory (optional)',
                              textAlign: TextAlign.center,
                              style: tt.labelMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            // One scrollable row, not a wrapping block: a block of
                            // chips would push Save off a small screen.
                            LayoutBuilder(
                              builder: (context, box) => SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: box.maxWidth,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final sub in subs)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs / 2,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(sub),
                                            selected: sub == _sub,
                                            onSelected: (on) => setState(
                                              () => _sub = on ? sub : null,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          _Numpad(
                            onKey: _press,
                            onClear: () => setState(() => _amount = ''),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              _saving ? 'SAVING…' : 'SAVE TO FINROOT',
                            ),
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
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: key == backspaceKey
                          ? const Icon(
                              Icons.backspace_outlined,
                              semanticLabel: 'Delete',
                            )
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

/// Name a new expense category. It is saved for the whole workspace (the web
/// dashboard lists it too); pops with the saved name.
class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(customExpenseCategoriesProvider.notifier)
          .add(_name.text);
      if (mounted) Navigator.of(context).pop(saved);
    } on Failure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = f.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        onSubmitted: (_) => _busy ? null : _add(),
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Petrol, Pets, Gifts',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _add,
          child: Text(_busy ? 'Adding…' : 'Add'),
        ),
      ],
    );
  }
}
