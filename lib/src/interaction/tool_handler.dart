import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_editor/src/config/path_editor_behavior.dart';
import 'package:path_editor/src/config/path_editor_callbacks.dart';
import 'package:path_editor/src/config/path_editor_cursors.dart';
import 'package:path_editor/src/config/path_editor_modifiers.dart';
import 'package:path_editor/src/config/path_editor_snapping.dart';
import 'package:path_editor/src/config/path_editor_viewport.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/interaction/hit_test.dart';
import 'package:path_editor/src/interaction/snap_engine.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_edits.dart';
import 'package:path_editor/src/model/path_node.dart';

/// The interaction currently in progress.
sealed class _Drag {
  /// The path as it was when the drag started. Every update is applied to this
  /// snapshot rather than to the previous frame, so drags never accumulate
  /// rounding drift and modifier keys can be toggled mid-drag.
  final EditablePath startPath;

  const _Drag(this.startPath);
}

class _MoveNodes extends _Drag {
  final Set<NodeRef> nodes;
  final NodeRef anchor;
  final Offset anchorStart;
  final Offset pointerStart;

  const _MoveNodes(
    super.startPath, {
    required this.nodes,
    required this.anchor,
    required this.anchorStart,
    required this.pointerStart,
  });
}

class _MoveHandle extends _Drag {
  final HandleRef handle;

  const _MoveHandle(super.startPath, this.handle);
}

class _PenHandle extends _Drag {
  final NodeRef node;
  final Offset origin;

  /// Whether this drag is bending an existing node rather than shaping a node
  /// the pen has just placed. Only the cursor differs.
  final bool bend;

  const _PenHandle(super.startPath, this.node, this.origin,
      {this.bend = false});
}

/// Translates pointer and keyboard input into edits, independently of any
/// widget.
///
/// The handler owns the transient interaction state (what is hovered, what is
/// being dragged, which snap guides are showing) and drives a
/// [PathEditorController] for anything that outlives a gesture. Keeping it
/// widget free makes every tool behaviour directly unit testable.
class PathEditorToolHandler extends ChangeNotifier {
  /// The controller this handler edits.
  final PathEditorController controller;

  PathEditorBehavior _behavior;
  PathEditorModifiers _modifiers;
  PathEditorSnapping _snapping;
  PathEditorCallbacks _callbacks;
  PathEditorViewport _viewport;
  HardwareKeyboard? _keyboard;

  PathHit _hover = const NoHit();
  Offset? _pointer;
  _Drag? _drag;
  List<SnapGuide> _guides = const [];
  SegmentRef? _activeSegment;

  Offset? _pressScene;
  NodeRef? _reduceSelectionTo;
  int? _activePointer;
  bool _movedBeyondThreshold = false;

  /// Creates a tool handler.
  PathEditorToolHandler({
    required this.controller,
    PathEditorBehavior behavior = PathEditorBehavior.defaults,
    PathEditorModifiers modifiers = PathEditorModifiers.defaults,
    PathEditorSnapping snapping = PathEditorSnapping.defaults,
    PathEditorCallbacks callbacks = PathEditorCallbacks.none,
    PathEditorViewport viewport = PathEditorViewport.identity,
    HardwareKeyboard? keyboard,
  })  : _behavior = behavior,
        _modifiers = modifiers,
        _snapping = snapping,
        _callbacks = callbacks,
        _viewport = viewport,
        _keyboard = keyboard;

  /// The behavior configuration in use.
  PathEditorBehavior get behavior => _behavior;

  /// The modifier mapping in use.
  PathEditorModifiers get modifiers => _modifiers;

  /// The snapping configuration in use.
  PathEditorSnapping get snapping => _snapping;

  /// The viewport in use.
  PathEditorViewport get viewport => _viewport;

  /// What the pointer is currently over.
  PathHit get hover => _hover;

  /// The pointer position in scene coordinates, or `null` when the pointer is
  /// outside the editor.
  Offset? get pointer => _pointer;

  /// The snap guides to draw, if any.
  List<SnapGuide> get snapGuides => _guides;

  /// The segment to highlight as active, if any.
  SegmentRef? get activeSegment => _activeSegment;

  /// Whether a drag is in progress.
  bool get isDragging => _drag != null;

  /// Updates the configuration, typically when the widget rebuilds.
  void updateConfiguration({
    PathEditorBehavior? behavior,
    PathEditorModifiers? modifiers,
    PathEditorSnapping? snapping,
    PathEditorCallbacks? callbacks,
    PathEditorViewport? viewport,
    HardwareKeyboard? keyboard,
  }) {
    _behavior = behavior ?? _behavior;
    _modifiers = modifiers ?? _modifiers;
    _snapping = snapping ?? _snapping;
    _callbacks = callbacks ?? _callbacks;
    _viewport = viewport ?? _viewport;
    _keyboard = keyboard ?? _keyboard;
  }

  /// The segment the pointer is hovering, if any.
  SegmentRef? get hoveredSegment => switch (_hover) {
        SegmentHit(segment: final segment) => segment,
        _ => null,
      };

  /// Where a node would be inserted if the user clicked now.
  Offset? get insertIndicator {
    if (controller.tool != PathTool.pen || !_behavior.insertOnSegmentClick) {
      return null;
    }
    return switch (_hover) {
      SegmentHit(position: final position) => position,
      _ => null,
    };
  }

  /// The node that would close the path if the user clicked now.
  Offset? get closeIndicator => switch (_hover) {
        CloseTargetHit(node: final node) =>
          controller.path.nodeOrNull(node)?.position,
        _ => null,
      };

  /// The handle the pointer is hovering, if any.
  HandleRef? get hoveredHandle => switch (_hover) {
        HandleHit(handle: final handle) => handle,
        _ => null,
      };

  /// The node the pointer is hovering, if any.
  NodeRef? get hoveredNode => switch (_hover) {
        NodeHit(node: final node) => node,
        CloseTargetHit(node: final node) => node,
        _ => null,
      };

  /// The point the pen tool would draw its next segment from, or `null` when
  /// no path is being extended.
  Offset? get penAnchor {
    if (controller.tool != PathTool.pen || isDragging) return null;
    final subpath = _pendingSubpath;
    if (subpath == null) return null;
    final nodes = controller.path.subpaths[subpath].nodes;
    return nodes.isEmpty ? null : nodes.last.position;
  }

  /// Whether the pen tool would start a new subpath if it were clicked on
  /// empty canvas right now.
  ///
  /// This is `false` while a path is being extended, and also when
  /// [PathEditorBehavior.allowMultipleSubpaths] is turned off and the path
  /// already contains a subpath.
  bool get canStartNewSubpath {
    if (controller.tool != PathTool.pen) return false;
    if (_pendingSubpath != null) return false;
    return _behavior.allowMultipleSubpaths || controller.path.isEmpty;
  }

  /// The interaction the editor is currently offering.
  PathEditorCursorState get cursorState {
    final drag = _drag;
    if (drag != null) {
      return switch (drag) {
        _PenHandle(bend: true) => PathEditorCursorState.adjustHandle,
        _PenHandle() => PathEditorCursorState.penDraw,
        _MoveHandle() => PathEditorCursorState.adjustHandle,
        _MoveNodes() => PathEditorCursorState.movePoint,
      };
    }

    final isPen = controller.tool == PathTool.pen;
    return switch (_hover) {
      HandleHit() => PathEditorCursorState.adjustHandle,
      // Bending grabs the curvature of the point rather than the point itself.
      NodeHit() ||
      CloseTargetHit() when _modifiers.bendPoint.isActive(_keyboard) =>
        PathEditorCursorState.adjustHandle,
      CloseTargetHit() => PathEditorCursorState.closePath,
      NodeHit(node: final node) =>
        isPen && _modifiers.removeNode.isActive(_keyboard)
            ? PathEditorCursorState.removePoint
            : controller.selection.contains(node)
                ? PathEditorCursorState.movePoint
                : PathEditorCursorState.selectPoint,
      SegmentHit() => isPen && _behavior.insertOnSegmentClick
          ? PathEditorCursorState.addPoint
          : isPen
              ? PathEditorCursorState.penReady
              : PathEditorCursorState.idle,
      NoHit() => isPen && (_pendingSubpath != null || canStartNewSubpath)
          ? PathEditorCursorState.penReady
          : PathEditorCursorState.idle,
    };
  }

  /// Handles the pointer moving over the editor without any button pressed.
  void handleHover(Offset localPosition) {
    final scene = _viewport.toScene(localPosition);
    _pointer = scene;
    _setHover(_hitTest(scene));
  }

  /// Handles the pointer leaving the editor.
  void handleExit() {
    if (_pointer == null && _hover is NoHit) return;
    _pointer = null;
    _hover = const NoHit();
    notifyListeners();
  }

  /// Handles a pointer being pressed down.
  ///
  /// Only one pointer drives the editor at a time; presses from additional
  /// pointers are ignored so the edit transaction opened here is always
  /// balanced by exactly one [handlePointerUp] or [handlePointerCancel].
  void handlePointerDown(Offset localPosition, {int pointer = 0}) {
    if (_activePointer != null) return;

    final scene = _viewport.toScene(localPosition);
    _pointer = scene;
    _pressScene = scene;
    _activePointer = pointer;
    _movedBeyondThreshold = false;
    _reduceSelectionTo = null;

    final hit = _hitTest(scene);
    _hover = hit;

    controller.beginTransaction();
    _handlePointerDown(scene, hit);
    notifyListeners();
  }

  /// Handles the pointer moving while pressed.
  void handlePointerMove(Offset localPosition, {int pointer = 0}) {
    if (_activePointer != null && _activePointer != pointer) return;

    final scene = _viewport.toScene(localPosition);
    _pointer = scene;

    if (_activePointer == null) {
      _setHover(_hitTest(scene));
      return;
    }

    final press = _pressScene;
    if (press != null &&
        (scene - press).distance >
            _viewport.toSceneDistance(_behavior.dragThreshold)) {
      _movedBeyondThreshold = true;
    }

    final drag = _drag;
    if (drag == null) {
      notifyListeners();
      return;
    }

    switch (drag) {
      case _PenHandle():
        _updatePenHandle(drag, scene);
      case _MoveHandle():
        _updateHandle(drag, scene);
      case _MoveNodes():
        _updateMove(drag, scene);
    }
    notifyListeners();
  }

  /// Handles the pointer being released.
  void handlePointerUp(Offset localPosition, {int pointer = 0}) {
    if (_activePointer != pointer) return;
    final scene = _viewport.toScene(localPosition);
    _pointer = scene;

    // Clicking a node that was already part of a multi selection reduces the
    // selection to that node, but only once it is clear it was a click and not
    // the start of a drag.
    final reduceTo = _reduceSelectionTo;
    if (reduceTo != null &&
        !_movedBeyondThreshold &&
        !_modifiers.multiSelect.isActive(_keyboard)) {
      controller.selection = controller.selection.selectOnly(reduceTo);
    }

    _resetPointerState();
    controller.commitTransaction();

    _hover = _hitTest(scene);
    notifyListeners();
  }

  /// Handles the pointer interaction being cancelled, rolling back the drag.
  void handlePointerCancel({int pointer = 0}) {
    if (_activePointer != pointer) return;
    _resetPointerState();
    controller.cancelTransaction();
    notifyListeners();
  }

  @override
  void dispose() {
    // The controller usually outlives the editor, so an interaction that is
    // still in flight has to be closed out rather than left open forever.
    if (_activePointer != null) {
      _activePointer = null;
      controller.commitTransaction();
    }
    super.dispose();
  }

  /// Stops extending the current path without closing it.
  void finishPath() {
    if (controller.selection.pendingSubpath == null) return;
    controller.selection =
        controller.selection.copyWith(clearPendingSubpath: true);
    _activeSegment = null;
    notifyListeners();
  }

  /// Closes the subpath the pen tool is extending, if it can be closed.
  bool closeCurrentSubpath() {
    final subpath = _pendingSubpath;
    if (subpath == null) return false;
    if (controller.path.subpaths[subpath].length < 2) return false;

    controller.closeSubpath(subpath);
    controller.selection =
        controller.selection.copyWith(clearPendingSubpath: true);
    _callbacks.onSubpathClosed?.call(subpath);
    notifyListeners();
    return true;
  }

  /// Removes the current selection.
  ///
  /// Returns `false` when the removal is not allowed, which happens when a cut
  /// would leave the path with more than one open subpath.
  bool removeSelection({NodeRemoval? mode}) {
    final nodes = controller.selection.nodes.toList();
    if (nodes.isEmpty) return false;

    final resolved = mode ??
        (_modifiers.cutPath.isActive(_keyboard)
            ? NodeRemoval.cut
            : NodeRemoval.preserveShape);

    final removed = controller.transaction(
      () => controller.removeNodes(nodes, mode: resolved),
    );
    if (removed) {
      _activeSegment = null;
      _callbacks.onNodesRemoved?.call(nodes);
      final scene = _pointer;
      _hover = scene == null ? const NoHit() : _hitTest(scene);
      notifyListeners();
    }
    return removed;
  }

  /// Moves the selected nodes by [delta] scene units.
  void nudgeSelection(Offset delta) {
    final nodes = controller.selection.nodes;
    if (nodes.isEmpty || delta == Offset.zero) return;
    controller.transaction(() => controller.moveNodes(nodes, delta));
    notifyListeners();
  }

  /// Converts the selected nodes to [type].
  void convertSelection(PathNodeType type) {
    final nodes = controller.selection.nodes;
    if (nodes.isEmpty) return;
    controller.transaction(() => controller.convertNodes(nodes, type));
    notifyListeners();
  }

  void _handlePointerDown(Offset scene, PathHit hit) {
    switch (hit) {
      case HandleHit(handle: final handle):
        _startHandleDrag(handle);
        return;
      case NodeHit(node: final node) || CloseTargetHit(node: final node)
          when _modifiers.bendPoint.isActive(_keyboard):
        _startBend(node);
        return;
      default:
        switch (controller.tool) {
          case PathTool.pen:
            _penPointerDown(scene, hit);
          case PathTool.select:
            _selectPointerDown(scene, hit);
        }
    }
  }

  void _penPointerDown(Offset scene, PathHit hit) {
    switch (hit) {
      case HandleHit(handle: final handle):
        _startHandleDrag(handle);
      case CloseTargetHit(node: final node):
        controller.closeSubpath(node.subpath);
        controller.selection = controller.selection
            .selectOnly(node)
            .copyWith(clearPendingSubpath: true);
        _activeSegment = SegmentRef(
          node.subpath,
          controller.path.subpaths[node.subpath].segmentCount - 1,
        );
        _callbacks.onSubpathClosed?.call(node.subpath);

      case NodeHit(node: final node)
          when _modifiers.removeNode.isActive(_keyboard):
        if (controller.removeNodes([node])) {
          _activeSegment = null;
          _callbacks.onNodesRemoved?.call([node]);
        }

      case NodeHit(node: final node):
        _startMovingNode(node, scene, extendSubpath: true);

      case SegmentHit(segment: final segment, t: final t)
          when _behavior.insertOnSegmentClick:
        final inserted = controller.insertNodeOn(segment, t);
        controller.selection = controller.selection.selectOnly(inserted);
        _activeSegment = SegmentRef(inserted.subpath, inserted.node - 1);
        _callbacks.onNodeAdded?.call(inserted);
        _startMovingNode(inserted, scene, extendSubpath: false);

      case SegmentHit():
      case NoHit():
        _createPenNode(scene);
    }
  }

  void _selectPointerDown(Offset scene, PathHit hit) {
    switch (hit) {
      case HandleHit(handle: final handle):
        _startHandleDrag(handle);
      case NodeHit(node: final node):
      case CloseTargetHit(node: final node):
        _startMovingNode(node, scene, extendSubpath: false);

      case SegmentHit(segment: final segment):
        final subpath = controller.path.subpaths[segment.subpath];
        final start = NodeRef(segment.subpath, segment.index);
        final end =
            NodeRef(segment.subpath, subpath.endNodeIndex(segment.index));
        controller.selection = PathEditorSelection(
          nodes: {start, end},
          active: end,
        );
        _activeSegment = segment;
        _startMovingNode(end, scene, extendSubpath: false, keepSelection: true);

      case NoHit():
        if (_behavior.clearSelectionOnBackgroundTap) {
          controller.clearSelection();
          _activeSegment = null;
        }
    }
  }

  void _startHandleDrag(HandleRef handle) {
    controller.selection = controller.selection.copyWith(activeHandle: handle);
    _drag = _MoveHandle(controller.path, handle);
  }

  void _resetPointerState() {
    _activePointer = null;
    _drag = null;
    _pressScene = null;
    _reduceSelectionTo = null;
    _guides = const [];
  }

  /// Starts pulling the curvature out of an existing node.
  ///
  /// The node itself stays where it is; only its handles move, which turns a
  /// corner point into a smooth one on the first drag and keeps reshaping a
  /// point that is already smooth.
  void _startBend(NodeRef node) {
    controller.selection = controller.selection.selectOnly(node);
    _drag = _PenHandle(
      controller.path,
      node,
      controller.path.nodeAt(node).position,
      bend: true,
    );
  }

  void _startMovingNode(
    NodeRef node,
    Offset scene, {
    required bool extendSubpath,
    bool keepSelection = false,
  }) {
    final selection = controller.selection;
    if (!keepSelection) {
      if (_modifiers.multiSelect.isActive(_keyboard)) {
        controller.selection = selection.toggle(node);
      } else if (selection.contains(node)) {
        // Keep the multi selection so it can be dragged as a whole, and only
        // reduce it on release if this turns out to be a plain click.
        controller.selection = selection.copyWith(active: node);
        _reduceSelectionTo = node;
      } else {
        controller.selection = selection.selectOnly(node);
      }
    }

    if (extendSubpath) {
      final subpath = controller.path.subpaths[node.subpath];
      final isLastNode = node.node == subpath.length - 1;
      controller.selection = controller.selection.copyWith(
        pendingSubpath: !subpath.closed && isLastNode ? node.subpath : null,
        clearPendingSubpath: subpath.closed || !isLastNode,
      );
    }

    if (!controller.selection.contains(node)) return;

    _drag = _MoveNodes(
      controller.path,
      nodes: controller.selection.nodes,
      anchor: node,
      anchorStart: controller.path.nodeAt(node).position,
      pointerStart: scene,
    );
  }

  void _createPenNode(Offset scene) {
    final pending = _pendingSubpath;
    if (pending == null && !canStartNewSubpath) {
      // The editor is restricted to a single subpath and already has one.
      return;
    }

    final snapped = _snap(scene, exclude: const {});
    _guides = snapped.guides;

    final ref = pending == null
        ? controller.startSubpath(PathNode.corner(snapped.position))
        : controller.appendNode(pending, PathNode.corner(snapped.position));

    controller.selection = PathEditorSelection.single(
      ref,
      pendingSubpath: ref.subpath,
    );
    _callbacks.onNodeAdded?.call(ref);

    if (ref.node > 0) {
      final segment = SegmentRef(ref.subpath, ref.node - 1);
      _activeSegment = segment;
      _callbacks.onSegmentCreated?.call(segment);
    } else {
      _activeSegment = null;
    }

    _drag = _PenHandle(controller.path, ref, snapped.position);
  }

  void _updatePenHandle(_PenHandle drag, Offset scene) {
    final threshold =
        _viewport.toSceneDistance(_behavior.smoothPointDragThreshold);
    if ((scene - drag.origin).distance <= threshold) {
      // Still a click: keep the node a corner.
      if (controller.path != drag.startPath) controller.path = drag.startPath;
      _guides = const [];
      return;
    }

    final snapped = _snap(
      scene,
      exclude: {drag.node},
      anchor: drag.origin,
      constrainAngle: _modifiers.constrainAngle.isActive(_keyboard),
    );
    _guides = snapped.guides;

    controller.path = drag.startPath.setHandle(
      HandleRef(drag.node, NodeHandle.outgoing),
      snapped.position,
      breakLink: _modifiers.breakHandle.isActive(_keyboard),
    );
  }

  void _updateHandle(_MoveHandle drag, Offset scene) {
    final node = drag.startPath.nodeOrNull(drag.handle.node);
    if (node == null) return;

    final snapped = _snap(
      scene,
      exclude: {drag.handle.node},
      anchor: node.position,
      constrainAngle: _modifiers.constrainAngle.isActive(_keyboard),
    );
    _guides = snapped.guides;

    controller.path = drag.startPath.setHandle(
      drag.handle,
      snapped.position,
      breakLink: _modifiers.breakHandle.isActive(_keyboard),
    );
  }

  void _updateMove(_MoveNodes drag, Offset scene) {
    final rawTarget = drag.anchorStart + (scene - drag.pointerStart);
    final snapped = _snap(rawTarget, exclude: drag.nodes);
    _guides = snapped.guides;

    controller.path = drag.startPath.translateNodes(
      drag.nodes,
      snapped.position - drag.anchorStart,
    );
  }

  SnapResult _snap(
    Offset scene, {
    required Set<NodeRef> exclude,
    Offset? anchor,
    bool constrainAngle = false,
  }) {
    final engine = SnapEngine(config: _snapping, scale: _viewport.scale);
    return engine.snap(
      scene,
      path: controller.path,
      exclude: exclude,
      anchor: anchor,
      constrainAngle: constrainAngle,
      enabled: !_modifiers.disableSnapping.isActive(_keyboard),
    );
  }

  PathHit _hitTest(Offset scene) {
    final selection = controller.selection;
    final pending = _pendingSubpath;

    NodeRef? closeTarget;
    if (controller.tool == PathTool.pen &&
        _behavior.closeOnFirstNodeClick &&
        pending != null &&
        controller.path.subpaths[pending].length >= 2) {
      closeTarget = NodeRef(pending, 0);
    }

    return PathHitTester(
      path: controller.path,
      behavior: _behavior,
      viewport: _viewport,
    ).hitTest(
      scene,
      handleNodes: selection.nodes,
      closeTarget: closeTarget,
    );
  }

  /// The subpath the pen tool is extending, or `null` when it is not extending
  /// anything.
  int? get _pendingSubpath {
    final pending = controller.selection.pendingSubpath;
    if (pending == null) return null;
    if (pending >= controller.path.subpaths.length) return null;
    if (controller.path.subpaths[pending].closed) return null;
    return pending;
  }

  void _setHover(PathHit hit) {
    if (hit == _hover) {
      notifyListeners();
      return;
    }
    _hover = hit;
    notifyListeners();
  }
}
