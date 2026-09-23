import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/interaction/tool_handler.dart';
import 'package:path_editor/src/model/path_edits.dart';
import 'package:path_editor/src/model/path_node.dart';

/// Removes the selected nodes.
///
/// When [mode] is `null` the editor uses `PathEditorBehavior.nodeRemoval`.
/// Pass [NodeRemoval.cut] to break the path instead.
class DeleteNodesIntent extends Intent {
  /// How the nodes should be removed.
  final NodeRemoval? mode;

  /// Creates a delete intent.
  const DeleteNodesIntent({this.mode});
}

/// Closes the subpath the pen tool is currently extending.
class ClosePathIntent extends Intent {
  /// Creates a close intent.
  const ClosePathIntent();
}

/// Stops extending the current path without closing it.
class FinishPathIntent extends Intent {
  /// Creates a finish intent.
  const FinishPathIntent();
}

/// Converts the selected nodes to a different [PathNodeType].
class ConvertNodesIntent extends Intent {
  /// The type to convert the selection to.
  final PathNodeType type;

  /// Creates a convert intent.
  const ConvertNodesIntent(this.type);
}

/// Selects every node of the path.
class SelectAllNodesIntent extends Intent {
  /// Creates a select all intent.
  const SelectAllNodesIntent();
}

/// Moves the selected nodes by one step.
class NudgeNodesIntent extends Intent {
  /// The direction to move in; usually a unit vector.
  final Offset direction;

  /// Whether to use the large nudge distance.
  final bool large;

  /// Creates a nudge intent.
  const NudgeNodesIntent(this.direction, {this.large = false});
}

/// Undoes the last edit.
class PathUndoIntent extends Intent {
  /// Creates an undo intent.
  const PathUndoIntent();
}

/// Redoes the last undone edit.
class PathRedoIntent extends Intent {
  /// Creates a redo intent.
  const PathRedoIntent();
}

/// Switches the active tool.
class SelectToolIntent extends Intent {
  /// The tool to activate.
  final PathTool tool;

  /// Creates a tool intent.
  const SelectToolIntent(this.tool);
}

/// The keyboard shortcuts of the path editor.
///
/// Pass a different map to `PathEditor.shortcuts` to remap or extend them; the
/// intents keep working as long as they reach the editor's [Actions].
///
/// The editor applies [withFallbacks] to whichever map it is given, so a
/// combination of [fallbackKeys] with modifiers that are not mapped exactly
/// falls back to the closest mapped one.
abstract final class PathEditorShortcuts {
  /// The default shortcut map.
  ///
  /// | Shortcut | Action |
  /// |---|---|
  /// | `Delete` / `Backspace` | remove the selected nodes |
  /// | `Shift` + `Delete` / `Backspace` | cut the path at the selected nodes |
  /// | `Escape` | stop extending the current path |
  /// | `Enter` | close the current path |
  /// | `Ctrl`/`Cmd` + `A` | select every node |
  /// | `Ctrl`/`Cmd` + `Z` | undo |
  /// | `Ctrl`/`Cmd` + `Shift` + `Z` | redo |
  /// | arrow keys | nudge the selection |
  /// | `Shift` + arrow keys | nudge the selection further |
  /// | `V` / `P` | select and pen tool |
  static const Map<ShortcutActivator, Intent> defaults = {
    SingleActivator(LogicalKeyboardKey.delete): DeleteNodesIntent(),
    SingleActivator(LogicalKeyboardKey.backspace): DeleteNodesIntent(),
    SingleActivator(LogicalKeyboardKey.delete, shift: true):
        DeleteNodesIntent(mode: NodeRemoval.cut),
    SingleActivator(LogicalKeyboardKey.backspace, shift: true):
        DeleteNodesIntent(mode: NodeRemoval.cut),
    SingleActivator(LogicalKeyboardKey.escape): FinishPathIntent(),
    SingleActivator(LogicalKeyboardKey.enter): ClosePathIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ClosePathIntent(),
    SingleActivator(LogicalKeyboardKey.keyA, control: true):
        SelectAllNodesIntent(),
    SingleActivator(LogicalKeyboardKey.keyA, meta: true):
        SelectAllNodesIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): PathUndoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): PathUndoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        PathRedoIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        PathRedoIntent(),
    SingleActivator(LogicalKeyboardKey.keyV): SelectToolIntent(PathTool.select),
    SingleActivator(LogicalKeyboardKey.keyP): SelectToolIntent(PathTool.pen),
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        NudgeNodesIntent(Offset(-1, 0)),
    SingleActivator(LogicalKeyboardKey.arrowRight):
        NudgeNodesIntent(Offset(1, 0)),
    SingleActivator(LogicalKeyboardKey.arrowUp):
        NudgeNodesIntent(Offset(0, -1)),
    SingleActivator(LogicalKeyboardKey.arrowDown):
        NudgeNodesIntent(Offset(0, 1)),
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        NudgeNodesIntent(Offset(-1, 0), large: true),
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        NudgeNodesIntent(Offset(1, 0), large: true),
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        NudgeNodesIntent(Offset(0, -1), large: true),
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        NudgeNodesIntent(Offset(0, 1), large: true),
  };

  /// The keys whose shortcuts fall back to the best match when extra
  /// modifiers are held, see [withFallbacks].
  ///
  /// These are the keys whose meaning does not change with a modifier the
  /// editor does not know about. Letter shortcuts are deliberately left out,
  /// so `Ctrl` + `V` never turns into `V`.
  static final Set<LogicalKeyboardKey> fallbackKeys = Set.unmodifiable({
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  });

  /// Returns [shortcuts] extended so that unmapped combinations of [keys]
  /// fall back to the best matching [SingleActivator].
  ///
  /// Exact matches always win. Otherwise the entry for the same key whose
  /// modifiers are the largest subset of the held modifiers is used, so with
  /// the defaults `Alt` + `Delete` removes like `Delete` and `Alt` + `Shift` +
  /// `Delete` cuts like `Shift` + `Delete`. A fallback never drops a modifier
  /// the entry requires. When several entries match equally well, the one
  /// that comes first in [shortcuts] wins.
  ///
  /// Only [SingleActivator] entries whose trigger is in [keys], which
  /// defaults to [fallbackKeys], get a fallback; everything else must match
  /// exactly.
  static Map<ShortcutActivator, Intent> withFallbacks(
    Map<ShortcutActivator, Intent> shortcuts, {
    Set<LogicalKeyboardKey>? keys,
  }) {
    final fallbackTriggers = keys ?? fallbackKeys;
    final fallbacks = [
      for (final MapEntry(:key, :value) in shortcuts.entries)
        if (key is SingleActivator && fallbackTriggers.contains(key.trigger))
          (_FallbackActivator(key), value),
    ];

    // The shortcut manager uses the first activator that accepts an event, so
    // the exact entries go first and the fallbacks follow, most specific
    // first, keeping the map order among equally specific ones.
    return {
      ...shortcuts,
      for (var count = 4; count >= 0; --count)
        for (final (activator, intent) in fallbacks)
          if (activator.modifierCount == count) activator: intent,
    };
  }
}

/// Accepts the key of [exact] while at least its modifiers are held.
class _FallbackActivator extends ShortcutActivator {
  final SingleActivator exact;

  const _FallbackActivator(this.exact);

  int get modifierCount =>
      (exact.control ? 1 : 0) +
      (exact.shift ? 1 : 0) +
      (exact.alt ? 1 : 0) +
      (exact.meta ? 1 : 0);

  @override
  Iterable<LogicalKeyboardKey> get triggers => exact.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent &&
        !(exact.includeRepeats && event is KeyRepeatEvent)) {
      return false;
    }
    if (event.logicalKey != exact.trigger) return false;

    final lockAccepted = switch (exact.numLock) {
      LockState.ignored => true,
      LockState.locked =>
        state.lockModesEnabled.contains(KeyboardLockMode.numLock),
      LockState.unlocked =>
        !state.lockModesEnabled.contains(KeyboardLockMode.numLock),
    };
    return lockAccepted &&
        (!exact.control || state.isControlPressed) &&
        (!exact.shift || state.isShiftPressed) &&
        (!exact.alt || state.isAltPressed) &&
        (!exact.meta || state.isMetaPressed);
  }

  @override
  String debugDescribeKeys() => 'at least ${exact.debugDescribeKeys()}';
}

/// Builds the actions that back [PathEditorShortcuts].
///
/// Applications that want to expose the same operations from a toolbar can
/// simply invoke the corresponding intent through `Actions.invoke`.
Map<Type, Action<Intent>> buildPathEditorActions({
  required PathEditorController controller,
  required PathEditorToolHandler handler,
}) =>
    <Type, Action<Intent>>{
      DeleteNodesIntent: CallbackAction<DeleteNodesIntent>(
        onInvoke: (intent) => handler.removeSelection(mode: intent.mode),
      ),
      ClosePathIntent: CallbackAction<ClosePathIntent>(
        onInvoke: (_) => handler.closeCurrentSubpath(),
      ),
      FinishPathIntent: CallbackAction<FinishPathIntent>(
        onInvoke: (_) {
          handler.finishPath();
          return null;
        },
      ),
      ConvertNodesIntent: CallbackAction<ConvertNodesIntent>(
        onInvoke: (intent) {
          handler.convertSelection(intent.type);
          return null;
        },
      ),
      SelectAllNodesIntent: CallbackAction<SelectAllNodesIntent>(
        onInvoke: (_) {
          controller.selectAll();
          return null;
        },
      ),
      NudgeNodesIntent: CallbackAction<NudgeNodesIntent>(
        onInvoke: (intent) {
          final distance = intent.large
              ? handler.behavior.largeNudgeDistance
              : handler.behavior.nudgeDistance;
          handler.nudgeSelection(intent.direction * distance);
          return null;
        },
      ),
      PathUndoIntent: CallbackAction<PathUndoIntent>(
        onInvoke: (_) => controller.undo(),
      ),
      PathRedoIntent: CallbackAction<PathRedoIntent>(
        onInvoke: (_) => controller.redo(),
      ),
      SelectToolIntent: CallbackAction<SelectToolIntent>(
        onInvoke: (intent) {
          controller.tool = intent.tool;
          return null;
        },
      ),
    };
