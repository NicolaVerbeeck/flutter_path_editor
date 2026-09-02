import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/interaction/tool_handler.dart';
import 'package:path_editor/src/model/path_edits.dart';
import 'package:path_editor/src/model/path_node.dart';

/// Removes the selected nodes.
///
/// When [mode] is `null` the editor picks the mode from the configured
/// modifier keys, so holding the cut modifier breaks the path instead of
/// preserving its shape.
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
abstract final class PathEditorShortcuts {
  /// The default shortcut map.
  ///
  /// | Shortcut | Action |
  /// |---|---|
  /// | `Delete` / `Backspace` | remove the selected nodes |
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
