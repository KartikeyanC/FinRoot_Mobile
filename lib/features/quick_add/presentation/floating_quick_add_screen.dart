import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../data/local/database_providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../sync/application/background_sync.dart';
import '../../sync/application/sync_engine.dart';
import '../../transactions/presentation/widgets/category_style.dart';
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
///
/// [icon] matches the icon the ledger shows for [category] (see
/// [CategoryStyle]), except Grocery, which gets a basket so it does not read
/// as a second Food tile.
class QuickCategory {
  const QuickCategory(this.icon, this.label, this.category, [this.note]);
  final IconData icon;
  final String label;
  final String category;
  final String? note;
}

const quickCategories = [
  QuickCategory(Icons.restaurant_rounded, 'Food', 'Food & Dining'),
  QuickCategory(Icons.flight_takeoff_rounded, 'Travel', 'Travel'),
  QuickCategory(
    Icons.local_grocery_store_rounded,
    'Grocery',
    'Food & Dining',
    'Groceries',
  ),
  QuickCategory(Icons.shopping_bag_rounded, 'Shopping', 'Shopping'),
  QuickCategory(Icons.bolt_rounded, 'Bills', 'Utilities'),
  QuickCategory(Icons.movie_rounded, 'Entertainment', 'Entertainment'),
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

  Future<void> _addSub(String group) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddSubDialog(group: group),
    );
    if (name != null && mounted) setState(() => _sub = name);
  }

  void _pickQuick(QuickCategory c) => setState(() {
    // Tapping the picked tile again un-picks it.
    _category = identical(c, _category) ? null : c;
    _custom = null;
    _sub = null;
  });

  void _pickCustom(String name) => setState(() {
    _custom = name == _custom ? null : name;
    _category = null;
    _sub = null;
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final pickedCategory = _custom ?? _category?.category;
    final pickedLabel = _custom ?? _category?.label;
    final group = pickedCategory == null
        ? null
        : groupNameForCategory(pickedCategory);
    final subs = pickedCategory == null
        ? const <String>[]
        : subOptionsFor(
            pickedCategory,
            ref.watch(customSubcategoriesProvider).value ??
                const <String, List<String>>{},
          );
    final customs =
        ref.watch(customExpenseCategoriesProvider).value ?? const <String>[];

    // What the save will file under, said before the tap rather than after:
    // "no pick" used to save as Other without a word.
    final summary = pickedLabel == null
        ? 'No category · saves as Other'
        : _sub == null
        ? pickedLabel
        : '$pickedLabel › $_sub';

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim the app underneath; tapping outside the card cancels.
          Positioned.fill(
            child: GestureDetector(
              onTap: _saving ? null : _close,
              child: ColoredBox(
                color: palette.shadow.withValues(
                  alpha: palette.isDark ? 0.7 : 0.55,
                ),
              ),
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
                  child: _Panel(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      // Every block shares the card's one left edge; nothing is
                      // centred except the amount, so rows of different length
                      // no longer zig-zag.
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Quick log',
                                  style: AppTypography.title.copyWith(
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              RoundIconButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Close',
                                onPressed: _saving ? null : _close,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const _SectionLabel('Category'),
                          const SizedBox(height: AppSpacing.sm),
                          _CategoryGrid(
                            children: [
                              for (final c in quickCategories)
                                _CategoryTile(
                                  icon: c.icon,
                                  style: CategoryStyle.of(
                                    context,
                                    c.category,
                                    TxnType.expense,
                                  ),
                                  label: c.label,
                                  selected: identical(c, _category),
                                  onTap: () => _pickQuick(c),
                                ),
                              for (final name in customs)
                                _CategoryTile(
                                  style: CategoryStyle.of(
                                    context,
                                    name,
                                    TxnType.expense,
                                  ),
                                  label: name,
                                  selected: name == _custom,
                                  onTap: () => _pickCustom(name),
                                ),
                              _CategoryTile(
                                icon: Icons.add_rounded,
                                label: 'Add category',
                                isAdd: true,
                                selected: false,
                                onTap: _saving ? null : _addCategory,
                              ),
                            ],
                          ),
                          if (group != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const _SectionLabel('Subcategory · optional'),
                            const SizedBox(height: AppSpacing.sm),
                            // One left-aligned row that scrolls: a part-hidden last
                            // chip at the edge says "there is more", and the row
                            // never pushes Save off a small screen.
                            SizedBox(
                              height: MediaQuery.textScalerOf(context)
                                  .scale(40)
                                  .clamp(40, 56),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final sub in subs)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xs,
                                      ),
                                      child: ChoiceChip(
                                        label: Text(sub),
                                        selected: sub == _sub,
                                        showCheckmark: false,
                                        selectedColor: palette.tint,
                                        backgroundColor: palette.card,
                                        side: BorderSide(
                                          color: sub == _sub
                                              ? palette.accent
                                              : palette.line,
                                        ),
                                        labelStyle: AppTypography.label
                                            .copyWith(
                                              fontSize: 13,
                                              color: sub == _sub
                                                  ? palette.accentText
                                                  : palette.ink,
                                            ),
                                        onSelected: (on) => setState(
                                          () => _sub = on ? sub : null,
                                        ),
                                      ),
                                    ),
                                  ActionChip(
                                    avatar: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: palette.accentText,
                                    ),
                                    label: const Text('New'),
                                    labelStyle: AppTypography.label.copyWith(
                                      fontSize: 13,
                                      color: palette.accentText,
                                    ),
                                    backgroundColor: palette.card,
                                    side: BorderSide(color: palette.line),
                                    tooltip:
                                        'Add a subcategory to $pickedLabel',
                                    onPressed: _saving
                                        ? null
                                        : () => _addSub(group),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          // The amount sits on top of the keys that type it, so eye
                          // and thumb work in one place at the bottom of the card.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: palette.subtle,
                              borderRadius: AppRadius.tile,
                            ),
                            child: Column(
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  label: 'Amount',
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      amountPreview(_amount),
                                      key: const Key('quick-add-amount'),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: AppTypography.moneyHero.copyWith(
                                        color: _amount.isEmpty
                                            ? palette.faint
                                            : palette.ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  summary,
                                  key: const Key('quick-log-summary'),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: pickedLabel == null
                                        ? palette.muted
                                        : palette.accentText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyStrong.copyWith(
                                color: finance.danger,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          _Numpad(
                            onKey: _press,
                            onClear: () => setState(() => _amount = ''),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // The theme paints FilledButton as the gradient pill.
                          FilledButton(
                            key: const Key('quick-log-save'),
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              _saving
                                  ? 'Saving…'
                                  : _amount.isEmpty
                                  ? 'Save'
                                  : 'Save ${amountPreview(_amount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

/// The floating card itself: the kit's card colour, hairline and 20px radius,
/// with the modal shadow since it sits over another app.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.modal(palette.shadow),
      ),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.label.copyWith(color: context.palette.muted),
    );
  }
}

/// Four equal columns: every tile is the same size and starts on the same
/// edge, however long its name. More than three rows scroll inside the grid
/// so a workspace with many categories cannot push the keypad off screen.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.children});
  final List<Widget> children;

  static const _columns = 4;
  static const _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    // Icon tile + label + padding; the label line grows with the text size.
    final tileHeight =
        AppSpacing.sm * 2 +
        _CategoryTile.iconSize +
        AppSpacing.xs +
        MediaQuery.textScalerOf(context).scale(16);
    final rows = (children.length / _columns).ceil().clamp(1, _maxRows);
    return SizedBox(
      height: rows * tileHeight + (rows - 1) * AppSpacing.sm,
      child: GridView(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisExtent: tileHeight,
        ),
        children: children,
      ),
    );
  }
}

/// One category choice: the category's pastel [IconTile] over its name. The
/// picked tile takes the accent tint and a 2px accent ring; the add tile is an
/// outlined accent "New".
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.style,
    this.isAdd = false,
  });

  static const iconSize = 36.0;

  final String label;

  /// Overrides [style]'s icon (the quick categories pick their own).
  final IconData? icon;
  final CategoryStyle? style;
  final bool isAdd;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = style;
    return Semantics(
      button: true,
      selected: isAdd ? null : selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? palette.tint
            : isAdd
            ? palette.card
            : palette.subtle,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.tile,
          side: BorderSide(
            color: selected
                ? palette.accent
                : isAdd
                ? palette.line
                : Colors.transparent,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTile(
                  icon: icon ?? s?.icon ?? Icons.label_rounded,
                  size: iconSize,
                  round: true,
                  tint: isAdd ? palette.tint : s?.tint,
                  color: isAdd ? palette.accentText : s?.color,
                ),
                const SizedBox(height: AppSpacing.xs),
                // A long name shrinks a little rather than losing its end.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isAdd ? 'New' : label,
                      maxLines: 1,
                      style: AppTypography.label.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected || isAdd
                            ? palette.accentText
                            : palette.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3×4 keys: 1–9, then '.', 0 and backspace. Long-press backspace to clear.
/// Each key is a round pill on the quiet fill, so it reads as a keypad rather
/// than loose text.
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
    final palette = context.palette;
    return Column(
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: TextButton(
                      onPressed: () => onKey(key),
                      onLongPress: key == backspaceKey ? onClear : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: palette.subtle,
                        foregroundColor: palette.ink,
                        shape: const StadiumBorder(),
                      ),
                      child: key == backspaceKey
                          ? Icon(
                              Icons.backspace_rounded,
                              size: 22,
                              color: palette.muted,
                              semanticLabel: 'Delete',
                            )
                          : Text(
                              key,
                              style: AppTypography.title.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Name a new subcategory under [group] for the whole workspace (the web lists
/// it too); pops with the saved name.
class _AddSubDialog extends ConsumerStatefulWidget {
  const _AddSubDialog({required this.group});
  final String group;

  @override
  ConsumerState<_AddSubDialog> createState() => _AddSubDialogState();
}

class _AddSubDialogState extends ConsumerState<_AddSubDialog> {
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
          .read(customSubcategoriesProvider.notifier)
          .add(widget.group, _name.text);
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
      title: Text('New subcategory in ${widget.group}'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        onSubmitted: (_) => _busy ? null : _add(),
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Tea, Bus ticket',
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
