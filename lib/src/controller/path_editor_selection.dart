import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_node.dart';

/// The tool that decides how pointer input is interpreted by the editor.
enum PathTool {
  /// Selects, moves and reshapes existing nodes and handles.
  select,

  /// Creates new nodes, closes paths and inserts points on segments.
  pen,
}

/// The immutable selection state of a path editor.
///
/// The selection tracks which nodes are selected, which node is the "active"
/// one (the last one the user touched, whose handles are shown), which handle
/// is currently being manipulated, and which subpath the pen tool is currently
/// extending.
@immutable
class PathEditorSelection {
  /// Every selected node.
  final Set<NodeRef> nodes;

  /// The node the user interacted with last, or `null` when nothing is active.
  ///
  /// The active node is always part of [nodes] when it is not `null`.
  final NodeRef? active;

  /// The handle currently being dragged, if any.
  final HandleRef? activeHandle;

  /// The subpath the pen tool is currently appending to, if any.
  final int? pendingSubpath;

  /// Creates a selection.
  const PathEditorSelection({
    this.nodes = const {},
    this.active,
    this.activeHandle,
    this.pendingSubpath,
  });

  /// An empty selection.
  static const PathEditorSelection empty = PathEditorSelection();

  /// Creates a selection containing exactly [node].
  PathEditorSelection.single(NodeRef node, {this.pendingSubpath})
      : nodes = {node},
        active = node,
        activeHandle = null;

  /// Whether nothing is selected.
  bool get isEmpty => nodes.isEmpty;

  /// Whether at least one node is selected.
  bool get isNotEmpty => nodes.isNotEmpty;

  /// Whether more than one node is selected.
  bool get isMultiple => nodes.length > 1;

  /// Whether [ref] is part of this selection.
  bool contains(NodeRef ref) => nodes.contains(ref);

  /// Returns a copy of this selection with the given properties replaced.
  ///
  /// Pass [clearActive], [clearActiveHandle] or [clearPendingSubpath] to reset
  /// the corresponding property to `null`.
  PathEditorSelection copyWith({
    Set<NodeRef>? nodes,
    NodeRef? active,
    HandleRef? activeHandle,
    int? pendingSubpath,
    bool clearActive = false,
    bool clearActiveHandle = false,
    bool clearPendingSubpath = false,
  }) =>
      PathEditorSelection(
        nodes: nodes ?? this.nodes,
        active: clearActive ? null : (active ?? this.active),
        activeHandle:
            clearActiveHandle ? null : (activeHandle ?? this.activeHandle),
        pendingSubpath: clearPendingSubpath
            ? null
            : (pendingSubpath ?? this.pendingSubpath),
      );

  /// Returns a selection containing only [ref].
  PathEditorSelection selectOnly(NodeRef ref) => PathEditorSelection(
        nodes: {ref},
        active: ref,
        pendingSubpath: pendingSubpath,
      );

  /// Returns a selection with [ref] added, keeping the existing nodes.
  PathEditorSelection add(NodeRef ref) => PathEditorSelection(
        nodes: {...nodes, ref},
        active: ref,
        pendingSubpath: pendingSubpath,
      );

  /// Returns a selection with [ref] removed.
  PathEditorSelection remove(NodeRef ref) {
    final updated = {...nodes}..remove(ref);
    return PathEditorSelection(
      nodes: updated,
      active: active == ref ? (updated.isEmpty ? null : updated.last) : active,
      pendingSubpath: pendingSubpath,
    );
  }

  /// Returns a selection with [ref] added when it was absent and removed when
  /// it was present. This is what a shift-click does.
  PathEditorSelection toggle(NodeRef ref) =>
      contains(ref) ? remove(ref) : add(ref);

  /// Returns a selection without any nodes, keeping [pendingSubpath].
  PathEditorSelection clear() =>
      PathEditorSelection(pendingSubpath: pendingSubpath);

  /// Returns a copy of this selection with every reference that no longer
  /// exists in [path] dropped.
  ///
  /// The editor calls this after structural edits so a stale selection can
  /// never point at a removed node.
  PathEditorSelection sanitized(EditablePath path) {
    final valid = nodes.where(path.contains).toSet();
    final validActive =
        active != null && path.contains(active!) ? active : null;
    final validHandle =
        activeHandle != null && path.contains(activeHandle!.node)
            ? activeHandle
            : null;
    final validPending = pendingSubpath != null &&
            pendingSubpath! < path.subpaths.length &&
            !path.subpaths[pendingSubpath!].closed
        ? pendingSubpath
        : null;

    if (valid.length == nodes.length &&
        validActive == active &&
        validHandle == activeHandle &&
        validPending == pendingSubpath) {
      return this;
    }

    return PathEditorSelection(
      nodes: valid,
      active: validActive,
      activeHandle: validHandle,
      pendingSubpath: validPending,
    );
  }

  /// The node types of every selected node in [path].
  Set<PathNodeType> typesIn(EditablePath path) => {
        for (final ref in nodes)
          if (path.contains(ref)) path.nodeAt(ref).type,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorSelection &&
          setEquals(nodes, other.nodes) &&
          active == other.active &&
          activeHandle == other.activeHandle &&
          pendingSubpath == other.pendingSubpath);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(nodes),
        active,
        activeHandle,
        pendingSubpath,
      );

  @override
  String toString() => 'PathEditorSelection(${nodes.length} nodes, '
      'active: $active, handle: $activeHandle, pending: $pendingSubpath)';
}
