import 'package:flutter/material.dart';

import '../../core/error/failure.dart';
import '../tokens/app_palette.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'button_styles.dart';
import 'ledger_kit.dart' show SelectCheck;

/// Ticking several rows and deleting them together — the phone half of the
/// web's bulk delete. Every list uses the same three pieces:
///
///   * [BulkSelection]  which rows are ticked; long-press a row to start
///   * [SelectionBar]   "3 selected · Select all · Delete · ✕", shown in
///                      place of the list's header while selecting
///   * [deleteSelected] one confirm, then each delete in turn, then one
///                      message saying what happened
///
/// Deletes go through each screen's own editor controller, so they queue and
/// sync exactly like a single delete does.
class BulkSelection extends ChangeNotifier {
  final Set<String> _ids = {};
  bool _active = false;

  /// True from the first long-press until [clear].
  bool get active => _active;
  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(String id) => _ids.contains(id);

  /// Long-press: start selecting with this row ticked.
  void start(String id) {
    _active = true;
    _ids.add(id);
    notifyListeners();
  }

  /// Tap while selecting. Unticking the last row ends selecting.
  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    if (_ids.isEmpty) _active = false;
    notifyListeners();
  }

  /// "Select all" ticks exactly what is on screen; pressed again it unticks.
  void toggleAll(Iterable<String> shown) {
    final all = shown.toSet();
    if (all.isNotEmpty && all.every(_ids.contains)) {
      _ids.removeAll(all);
    } else {
      _ids.addAll(all);
    }
    _active = true;
    notifyListeners();
  }

  void clear() {
    if (!_active && _ids.isEmpty) return;
    _ids.clear();
    _active = false;
    notifyListeners();
  }
}

/// The bar that replaces a list's header while rows are ticked.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.selection,
    required this.shown,
    required this.onDelete,
  });

  final BulkSelection selection;

  /// The ids currently on screen (what "Select all" ticks).
  final Iterable<String> shown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final n = selection.count;
    final all = shown.isNotEmpty && shown.every(selection.contains);
    return Material(
      color: palette.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Stop selecting',
              icon: const Icon(Icons.close_rounded),
              onPressed: selection.clear,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '$n selected',
                  style: AppTypography.bodyStrong.copyWith(color: palette.ink),
                ),
              ),
            ),
            TextButton(
              onPressed: () => selection.toggleAll(shown),
              child: Text(all ? 'Clear' : 'Select all'),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton.icon(
              // The shared style is full width (dialogs, sheets); here it
              // sits in a row.
              style: AppButtonStyles.destructive.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
              ),
              onPressed: n == 0 ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

/// Confirms once, deletes every ticked row with [delete], then says what
/// happened. Rows that fail stay ticked so they can be tried again; the rest
/// are unticked. Returns how many were deleted.
Future<int> deleteSelected(
  BuildContext context, {
  required BulkSelection selection,
  required String one,
  required String many,
  required Future<void> Function(String id) delete,
  String? message,
}) async {
  final ids = selection.ids.toList();
  if (ids.isEmpty) return 0;
  final messenger = ScaffoldMessenger.of(context);
  final noun = ids.length == 1 ? one : many;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete ${ids.length} $noun?'),
      content: Text(message ?? "This can't be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AppButtonStyles.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return 0;

  var done = 0;
  String? problem;
  final failed = <String>{};
  for (final id in ids) {
    try {
      await delete(id);
      done++;
    } catch (e) {
      failed.add(id);
      problem ??= e is Failure ? e.message : 'Something went wrong';
    }
  }

  selection.clear();
  for (final id in failed) {
    selection.start(id);
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failed.isEmpty
            ? 'Deleted $done ${done == 1 ? one : many}'
            : 'Deleted $done of ${ids.length}. $problem',
      ),
    ),
  );
  return done;
}

/// Makes any card or row selectable: long-press starts selecting; while
/// selecting, a check circle leads it, a tap toggles it, and its own buttons
/// stand down so a stray tap cannot open or change it.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.child,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    this.onLongPress,
    this.label,
  });

  final Widget child;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  /// Null when the viewer cannot delete (a read-only member).
  final VoidCallback? onLongPress;

  /// What a screen reader says for the row while selecting.
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!selecting) {
      return GestureDetector(onLongPress: onLongPress, child: child);
    }
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: label != null,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Material(
          color: selected
              ? palette.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: SelectCheck(on: selected),
              ),
              Expanded(child: AbsorbPointer(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns a [BulkSelection] for a screen that is otherwise stateless, and
/// rebuilds [builder] as rows are ticked.
class BulkSelectScope extends StatefulWidget {
  const BulkSelectScope({super.key, required this.builder});

  final Widget Function(BuildContext context, BulkSelection selection) builder;

  @override
  State<BulkSelectScope> createState() => _BulkSelectScopeState();
}

class _BulkSelectScopeState extends State<BulkSelectScope> {
  final _selection = BulkSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _selection,
    builder: (context, _) => widget.builder(context, _selection),
  );
}
