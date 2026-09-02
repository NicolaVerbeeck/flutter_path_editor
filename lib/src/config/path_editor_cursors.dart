import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The interaction the editor is offering at the current pointer position.
///
/// The editor resolves one of these on every hover and drag and asks
/// [PathEditorCursors] which cursor to show for it.
enum PathEditorCursorState {
  /// The pointer is over empty canvas with the select tool active.
  idle,

  /// The pointer is over a node that can be selected.
  selectPoint,

  /// The pointer is over a selected node, or is dragging one.
  movePoint,

  /// The pointer is over a segment and clicking would insert a node.
  addPoint,

  /// The pointer is over a node and clicking would remove it.
  removePoint,

  /// The pointer is over the first node of an open path and clicking would
  /// close it.
  closePath,

  /// The pointer is over a Bézier handle, or is dragging one.
  adjustHandle,

  /// The pen tool is active and clicking would start or extend a path.
  penReady,

  /// The pen tool is dragging out the handles of a freshly placed node.
  penDraw,
}

/// The cursor shown for every [PathEditorCursorState].
///
/// Flutter has no portable way to load custom bitmap cursors, so every entry
/// is a [MouseCursor]: pass one of the [SystemMouseCursors] constants or your
/// own [MouseCursor] implementation.
@immutable
class PathEditorCursors {
  /// Shown over empty canvas.
  final MouseCursor idle;

  /// Shown over a node that can be selected.
  final MouseCursor selectPoint;

  /// Shown over a selected node, or while dragging one.
  final MouseCursor movePoint;

  /// Shown over a segment when clicking would insert a node.
  final MouseCursor addPoint;

  /// Shown over a node when clicking would remove it.
  final MouseCursor removePoint;

  /// Shown over the first node of an open path when clicking would close it.
  final MouseCursor closePath;

  /// Shown over a Bézier handle, or while dragging one.
  final MouseCursor adjustHandle;

  /// Shown when the pen tool would start or extend a path.
  final MouseCursor penReady;

  /// Shown while the pen tool drags out handles.
  final MouseCursor penDraw;

  /// Creates a cursor set.
  const PathEditorCursors({
    this.idle = SystemMouseCursors.basic,
    this.selectPoint = SystemMouseCursors.click,
    this.movePoint = SystemMouseCursors.grab,
    this.addPoint = SystemMouseCursors.precise,
    this.removePoint = SystemMouseCursors.disappearing,
    this.closePath = SystemMouseCursors.precise,
    this.adjustHandle = SystemMouseCursors.grab,
    this.penReady = SystemMouseCursors.precise,
    this.penDraw = SystemMouseCursors.grabbing,
  });

  /// The default cursor set.
  static const PathEditorCursors defaults = PathEditorCursors();

  /// The cursor to show for [state].
  MouseCursor resolve(PathEditorCursorState state) => switch (state) {
        PathEditorCursorState.idle => idle,
        PathEditorCursorState.selectPoint => selectPoint,
        PathEditorCursorState.movePoint => movePoint,
        PathEditorCursorState.addPoint => addPoint,
        PathEditorCursorState.removePoint => removePoint,
        PathEditorCursorState.closePath => closePath,
        PathEditorCursorState.adjustHandle => adjustHandle,
        PathEditorCursorState.penReady => penReady,
        PathEditorCursorState.penDraw => penDraw,
      };

  /// Returns a copy of this cursor set with the given cursors replaced.
  PathEditorCursors copyWith({
    MouseCursor? idle,
    MouseCursor? selectPoint,
    MouseCursor? movePoint,
    MouseCursor? addPoint,
    MouseCursor? removePoint,
    MouseCursor? closePath,
    MouseCursor? adjustHandle,
    MouseCursor? penReady,
    MouseCursor? penDraw,
  }) =>
      PathEditorCursors(
        idle: idle ?? this.idle,
        selectPoint: selectPoint ?? this.selectPoint,
        movePoint: movePoint ?? this.movePoint,
        addPoint: addPoint ?? this.addPoint,
        removePoint: removePoint ?? this.removePoint,
        closePath: closePath ?? this.closePath,
        adjustHandle: adjustHandle ?? this.adjustHandle,
        penReady: penReady ?? this.penReady,
        penDraw: penDraw ?? this.penDraw,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorCursors &&
          idle == other.idle &&
          selectPoint == other.selectPoint &&
          movePoint == other.movePoint &&
          addPoint == other.addPoint &&
          removePoint == other.removePoint &&
          closePath == other.closePath &&
          adjustHandle == other.adjustHandle &&
          penReady == other.penReady &&
          penDraw == other.penDraw);

  @override
  int get hashCode => Object.hash(
        idle,
        selectPoint,
        movePoint,
        addPoint,
        removePoint,
        closePath,
        adjustHandle,
        penReady,
        penDraw,
      );
}
