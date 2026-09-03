import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_edits.dart';
import 'package:path_editor/src/model/path_node.dart';
import 'package:path_editor/src/model/path_operators.dart';

/// A single reversible step on the undo stack.
@immutable
class _UndoEntry {
  final EditablePath before;
  final EditablePath after;
  final PathEditorSelection selectionBefore;
  final PathEditorSelection selectionAfter;

  const _UndoEntry({
    required this.before,
    required this.after,
    required this.selectionBefore,
    required this.selectionAfter,
  });
}

/// Owns the path being edited together with the editor's selection and active
/// tool, and provides undo and redo on top of them.
///
/// The controller exposes three separate listenables so widgets rebuild on
/// exactly the changes they care about, and also notifies its own listeners on
/// any change:
///
/// ```dart
/// final controller = PathEditorController.fromSvg('M0 0L10 10');
///
/// ValueListenableBuilder(
///   valueListenable: controller.pathListenable,
///   builder: (context, path, _) => Text(path.toSvg()),
/// );
/// ```
class PathEditorController extends ChangeNotifier {
  /// How many undo steps are kept before the oldest one is discarded.
  final int maxUndoSteps;

  final ValueNotifier<EditablePath> _path;
  final ValueNotifier<PathEditorSelection> _selection;
  final ValueNotifier<PathTool> _tool;

  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  int _transactionDepth = 0;
  EditablePath? _transactionStart;
  PathEditorSelection? _transactionSelectionStart;

  String? _cachedSvg;
  ui.Path? _cachedUiPath;

  /// Creates a controller for [path].
  PathEditorController.fromPath(
    EditablePath path, {
    this.maxUndoSteps = 100,
    PathTool tool = PathTool.select,
  })  : _path = ValueNotifier(path),
        _selection = ValueNotifier(PathEditorSelection.empty),
        _tool = ValueNotifier(tool);

  /// Creates a controller for the path described by [svg].
  factory PathEditorController.fromSvg(
    String svg, {
    int maxUndoSteps = 100,
    PathTool tool = PathTool.select,
  }) =>
      PathEditorController.fromPath(
        EditablePath.fromSvg(svg),
        maxUndoSteps: maxUndoSteps,
        tool: tool,
      );

  /// Creates a controller with an empty path, ready for the pen tool.
  factory PathEditorController.empty({
    int maxUndoSteps = 100,
    PathTool tool = PathTool.pen,
  }) =>
      PathEditorController.fromPath(
        EditablePath.empty,
        maxUndoSteps: maxUndoSteps,
        tool: tool,
      );

  /// Notifies when the path changes.
  ValueListenable<EditablePath> get pathListenable => _path;

  /// Notifies when the selection changes.
  ValueListenable<PathEditorSelection> get selectionListenable => _selection;

  /// Notifies when the active tool changes.
  ValueListenable<PathTool> get toolListenable => _tool;

  /// The path currently being edited.
  EditablePath get path => _path.value;

  /// Replaces the path, recording an undo step.
  set path(EditablePath value) => _apply(value);

  /// The path as an SVG path string.
  ///
  /// The result is cached until the path changes.
  String get svg => _cachedSvg ??= path.toSvg();

  /// The path as a paintable [ui.Path].
  ///
  /// The result is cached until the path changes; do not mutate it.
  ui.Path get uiPath => _cachedUiPath ??= path.toUiPath();

  /// The path as a list of SVG operators.
  List<PathOperator> get operators => path.toOperators();

  /// The current selection.
  PathEditorSelection get selection => _selection.value;

  /// Replaces the selection.
  ///
  /// References that no longer exist are dropped. Selection changes are not
  /// recorded on the undo stack on their own; they are restored as part of the
  /// edit they belong to.
  set selection(PathEditorSelection value) {
    final sanitized = value.sanitized(path);
    if (sanitized == _selection.value) return;
    _selection.value = sanitized;
    notifyListeners();
  }

  /// The active tool.
  PathTool get tool => _tool.value;

  /// Switches the active tool.
  set tool(PathTool value) {
    if (_tool.value == value) return;
    _tool.value = value;
    if (value != PathTool.pen) {
      // Leaving the pen tool finishes whatever path it was drawing.
      _selection.value = _selection.value.copyWith(clearPendingSubpath: true);
    }
    notifyListeners();
  }

  /// Whether there is anything to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is anything to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Whether an edit transaction is currently open.
  bool get isInTransaction => _transactionDepth > 0;

  /// Replaces the path with the one described by [svg].
  void loadSvg(String svg) => _apply(EditablePath.fromSvg(svg));

  /// Undoes the most recent edit, restoring the selection it was made with.
  bool undo() {
    if (!canUndo) return false;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    _restore(entry.before, entry.selectionBefore);
    return true;
  }

  /// Redoes the most recently undone edit.
  bool redo() {
    if (!canRedo) return false;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    _restore(entry.after, entry.selectionAfter);
    return true;
  }

  /// Clears the undo and redo history.
  void clearHistory() {
    if (_undoStack.isEmpty && _redoStack.isEmpty) return;
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// Starts an edit transaction.
  ///
  /// Every change made until the matching [commitTransaction] collapses into a
  /// single undo step. Transactions may be nested; only the outermost one
  /// produces an undo entry. This is what turns a whole drag gesture into one
  /// undoable edit.
  void beginTransaction() {
    if (_transactionDepth == 0) {
      _transactionStart = path;
      _transactionSelectionStart = selection;
    }
    _transactionDepth++;
  }

  /// Ends the transaction started by [beginTransaction], recording a single
  /// undo step for everything that happened in between.
  void commitTransaction() {
    assert(_transactionDepth > 0, 'commitTransaction without beginTransaction');
    if (_transactionDepth == 0) return;

    _transactionDepth--;
    if (_transactionDepth > 0) return;

    final start = _transactionStart;
    final selectionStart = _transactionSelectionStart;
    _transactionStart = null;
    _transactionSelectionStart = null;

    if (start == null || start == path) return;
    _pushUndo(start, selectionStart ?? selection);
    notifyListeners();
  }

  /// Ends the current transaction and rolls the path back to where it started.
  void cancelTransaction() {
    assert(_transactionDepth > 0, 'cancelTransaction without beginTransaction');
    if (_transactionDepth == 0) return;

    _transactionDepth--;
    if (_transactionDepth > 0) return;

    final start = _transactionStart;
    final selectionStart = _transactionSelectionStart;
    _transactionStart = null;
    _transactionSelectionStart = null;

    if (start != null) _restore(start, selectionStart ?? selection);
  }

  /// Runs [body] inside a transaction, so all of its edits collapse into a
  /// single undo step.
  T transaction<T>(T Function() body) {
    beginTransaction();
    var committed = false;
    try {
      final result = body();
      commitTransaction();
      committed = true;
      return result;
    } finally {
      if (!committed) cancelTransaction();
    }
  }

  /// Starts a new subpath containing [node] and returns its reference.
  NodeRef startSubpath(PathNode node) {
    final (updated, ref) = path.startSubpath(node);
    _apply(updated);
    return ref;
  }

  /// Appends [node] to the end of the subpath at [subpath].
  NodeRef appendNode(int subpath, PathNode node) {
    final (updated, ref) = path.appendNode(subpath, node);
    _apply(updated);
    return ref;
  }

  /// Inserts a node on [segment] at parametric position [t], preserving the
  /// exact geometry of the path.
  NodeRef insertNodeOn(SegmentRef segment, double t) {
    final (updated, ref) = path.insertNodeOn(segment, t);
    _apply(updated);
    return ref;
  }

  /// Closes the subpath at [subpath].
  void closeSubpath(int subpath) => _apply(path.closeSubpath(subpath));

  /// Reopens the subpath at [subpath].
  void openSubpath(int subpath) => _apply(path.openSubpath(subpath));

  /// Moves [nodes] by [delta].
  void moveNodes(Iterable<NodeRef> nodes, Offset delta) =>
      _apply(path.translateNodes(nodes, delta));

  /// Moves the node [ref] points at to [position].
  void moveNode(NodeRef ref, Offset position) =>
      _apply(path.moveNode(ref, position));

  /// Moves the handle [ref] points at to [position].
  ///
  /// Set [breakLink] to move the handle independently of its partner.
  void setHandle(HandleRef ref, Offset position, {bool breakLink = false}) =>
      _apply(path.setHandle(ref, position, breakLink: breakLink));

  /// Removes the handle [ref] points at.
  void clearHandle(HandleRef ref) => _apply(path.clearHandle(ref));

  /// Converts [nodes] to [type].
  void convertNodes(Iterable<NodeRef> nodes, PathNodeType type) =>
      _apply(path.convertNodes(nodes, type));

  /// Whether [nodes] can be removed with [mode].
  bool canRemoveNodes(
    Iterable<NodeRef> nodes, {
    NodeRemoval mode = NodeRemoval.preserveShape,
  }) =>
      path.canRemoveNodes(nodes, mode: mode);

  /// Removes [nodes] using [mode].
  ///
  /// Returns `false` without changing anything when the removal is not allowed,
  /// which happens when a cut would leave the path with more than one open
  /// subpath.
  bool removeNodes(
    Iterable<NodeRef> nodes, {
    NodeRemoval mode = NodeRemoval.preserveShape,
  }) {
    final refs = nodes.where(path.contains).toList();
    if (refs.isEmpty) return false;
    if (!path.canRemoveNodes(refs, mode: mode)) return false;

    _apply(
      path.removeNodes(refs, mode: mode),
      selection: selection.clear(),
    );
    return true;
  }

  /// Selects exactly [nodes].
  void select(Iterable<NodeRef> nodes) {
    final refs = nodes.where(path.contains).toSet();
    selection = PathEditorSelection(
      nodes: refs,
      active: refs.isEmpty ? null : refs.last,
      pendingSubpath: selection.pendingSubpath,
    );
  }

  /// Selects every node of the path.
  void selectAll() => select(path.nodeRefs);

  /// Clears the selection.
  void clearSelection() => selection = selection.clear();

  /// The bounding box of the path, optionally inflated for a stroke.
  Rect bounds({double strokeWidth = 0}) =>
      path.bounds(strokeWidth: strokeWidth);

  void _apply(EditablePath next, {PathEditorSelection? selection}) {
    final nextSelection = (selection ?? _selection.value).sanitized(next);
    if (next == _path.value && nextSelection == _selection.value) return;

    final previous = _path.value;
    final previousSelection = _selection.value;

    _setState(next, nextSelection);

    if (!isInTransaction && next != previous) {
      _pushUndo(previous, previousSelection);
    }
    notifyListeners();
  }

  void _pushUndo(EditablePath before, PathEditorSelection selectionBefore) {
    _undoStack.add(
      _UndoEntry(
        before: before,
        after: path,
        selectionBefore: selectionBefore,
        selectionAfter: selection,
      ),
    );
    if (_undoStack.length > maxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restore(EditablePath target, PathEditorSelection targetSelection) {
    _setState(target, targetSelection.sanitized(target));
    notifyListeners();
  }

  void _setState(EditablePath next, PathEditorSelection nextSelection) {
    _path.value = next;
    _cachedSvg = null;
    _cachedUiPath = null;
    _selection.value = nextSelection;
  }

  @override
  void dispose() {
    _path.dispose();
    _selection.dispose();
    _tool.dispose();
    super.dispose();
  }
}
