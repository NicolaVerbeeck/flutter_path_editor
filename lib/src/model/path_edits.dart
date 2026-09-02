import 'dart:math' as math;
import 'dart:ui';

import 'package:path_editor/src/model/curve_fit.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_node.dart';
import 'package:path_editor/src/model/path_segment.dart';

/// The two intentions behind removing a node, as described by the pen tool
/// specification.
enum NodeRemoval {
  /// "Clean up the curve": the node disappears but the path stays a single
  /// connected run. The surrounding segments are refitted so the shape is
  /// preserved as closely as possible.
  preserveShape,

  /// "Cut here": the path is broken at the node.
  ///
  /// A cut is only legal when it does not leave the path with more than one
  /// open subpath. Use [PathEdits.canRemoveNodes] to check up front.
  cut,
}

/// Pure editing operations on an [EditablePath].
///
/// Every operation returns a new path; the receiver is never modified. The
/// controller layers undo, redo and change notification on top of these.
extension PathEdits on EditablePath {
  /// Adds a new subpath containing only [node].
  (EditablePath, NodeRef) startSubpath(PathNode node) {
    final updated = List.of(subpaths)..add(PathSubpath.single(node));
    return (EditablePath(updated), NodeRef(updated.length - 1, 0));
  }

  /// Appends [node] to the end of the subpath at [subpathIndex].
  (EditablePath, NodeRef) appendNode(int subpathIndex, PathNode node) {
    final subpath = subpaths[subpathIndex];
    final nodes = List.of(subpath.nodes)..add(node);
    return (
      replaceSubpath(subpathIndex, subpath.copyWith(nodes: nodes)),
      NodeRef(subpathIndex, nodes.length - 1),
    );
  }

  /// Closes the subpath at [subpathIndex], connecting its last node back to
  /// its first one.
  EditablePath closeSubpath(int subpathIndex) {
    final subpath = subpaths[subpathIndex];
    if (subpath.closed) return this;
    return replaceSubpath(subpathIndex, subpath.copyWith(closed: true));
  }

  /// Reopens the subpath at [subpathIndex].
  EditablePath openSubpath(int subpathIndex) {
    final subpath = subpaths[subpathIndex];
    if (!subpath.closed) return this;
    return replaceSubpath(subpathIndex, subpath.copyWith(closed: false));
  }

  /// Inserts a node on [segment] at parametric position [t].
  ///
  /// The segment is split with de Casteljau's algorithm, so the geometry of
  /// the path is completely unchanged by the insertion. The handles of the
  /// surrounding nodes are updated accordingly.
  (EditablePath, NodeRef) insertNodeOn(SegmentRef segment, double t) {
    final subpath = subpaths[segment.subpath];
    final startIndex = segment.index;
    final endIndex = subpath.endNodeIndex(startIndex);
    final (left, right) = subpath.segmentAt(startIndex).splitAt(t);

    final nodes = List.of(subpath.nodes);
    nodes[startIndex] = _retyped(
        nodes[startIndex].withHandle(NodeHandle.outgoing, left.startControl));
    nodes[endIndex] = _retyped(
        nodes[endIndex].withHandle(NodeHandle.incoming, right.endControl));
    nodes.insert(
      startIndex + 1,
      _retyped(
        PathNode(
          position: left.end,
          incoming: left.endControl,
          outgoing: right.startControl,
        ),
      ),
    );

    return (
      replaceSubpath(segment.subpath, subpath.copyWith(nodes: nodes)),
      NodeRef(segment.subpath, startIndex + 1),
    );
  }

  /// Translates every node in [nodes] by [delta]. Handles move along with
  /// their anchor.
  EditablePath translateNodes(Iterable<NodeRef> nodes, Offset delta) {
    if (delta == Offset.zero) return this;

    final updated = List.of(subpaths);
    for (final ref in nodes) {
      if (!contains(ref)) continue;
      final subpath = updated[ref.subpath];
      updated[ref.subpath] = subpath.replaceNode(
        ref.node,
        subpath.nodes[ref.node].translated(delta),
      );
    }
    return EditablePath(updated);
  }

  /// Moves the node [ref] points at to [position].
  EditablePath moveNode(NodeRef ref, Offset position) =>
      replaceNode(ref, nodeAt(ref).movedTo(position));

  /// Moves the handle [ref] points at to [position].
  ///
  /// The opposite handle follows the linkage rules of the node type. Moving a
  /// handle of a [PathNodeType.corner] node grows a symmetric pair of handles
  /// and turns it into a [PathNodeType.mirrored] node, which is what the pen
  /// tool relies on when a click turns into a drag. Passing [breakLink]
  /// converts the node to [PathNodeType.disconnected] instead, leaving the
  /// opposite handle exactly where it is.
  EditablePath setHandle(
    HandleRef ref,
    Offset position, {
    bool breakLink = false,
  }) {
    final node = nodeAt(ref.node);

    if (node.type == PathNodeType.corner && !node.hasHandles) {
      if (breakLink) {
        return replaceNode(
          ref.node,
          node
              .withHandle(ref.handle, position)
              .copyWith(type: PathNodeType.disconnected),
        );
      }
      final mirrored = node.position - (position - node.position);
      return replaceNode(
        ref.node,
        PathNode(
          position: node.position,
          incoming: ref.handle == NodeHandle.incoming ? position : mirrored,
          outgoing: ref.handle == NodeHandle.outgoing ? position : mirrored,
          type: PathNodeType.mirrored,
        ),
      );
    }

    return replaceNode(
      ref.node,
      node.withLinkedHandle(ref.handle, position, breakLink: breakLink),
    );
  }

  /// Removes the handle [ref] points at, straightening the adjacent segment.
  EditablePath clearHandle(HandleRef ref) {
    final node = nodeAt(ref.node);
    return replaceNode(ref.node, _retyped(node.withHandle(ref.handle, null)));
  }

  /// Converts every node in [nodes] to [type].
  ///
  /// See [PathNode.convertedTo] for how handles are grown or collapsed.
  EditablePath convertNodes(
    Iterable<NodeRef> nodes,
    PathNodeType type, {
    double smoothFactor = 1 / 3,
  }) {
    var result = this;
    for (final ref in nodes) {
      if (!result.contains(ref)) continue;
      final (previous, next) = result.neighboursOf(ref);
      result = result.replaceNode(
        ref,
        result.nodeAt(ref).convertedTo(
              type,
              previous: previous,
              next: next,
              smoothFactor: smoothFactor,
            ),
      );
    }
    return result;
  }

  /// Whether removing [nodes] with [mode] is allowed.
  ///
  /// [NodeRemoval.preserveShape] is always allowed. [NodeRemoval.cut] is
  /// rejected when it would leave the path with more than one open subpath,
  /// implementing the "we do not have multiple open paths" rule.
  bool canRemoveNodes(
    Iterable<NodeRef> nodes, {
    NodeRemoval mode = NodeRemoval.preserveShape,
  }) {
    final refs = nodes.where(contains).toList();
    if (refs.isEmpty) return false;
    if (mode == NodeRemoval.preserveShape) return true;

    return removeNodes(refs, mode: mode).openSubpathIndices.length <= 1;
  }

  /// Removes every node in [nodes] using [mode].
  ///
  /// Nodes are grouped per subpath and every subpath is rewritten in a single
  /// pass, so references stay meaningful even when a cut reorders the nodes it
  /// leaves behind. Subpaths that lose all of their nodes are dropped.
  EditablePath removeNodes(
    Iterable<NodeRef> nodes, {
    NodeRemoval mode = NodeRemoval.preserveShape,
  }) {
    final grouped = <int, List<int>>{};
    for (final ref in nodes.toSet()) {
      if (!contains(ref)) continue;
      (grouped[ref.subpath] ??= []).add(ref.node);
    }
    if (grouped.isEmpty) return this;

    final result = List.of(subpaths);
    // Rewriting the subpaths back to front keeps the indices of the ones still
    // to be processed valid, because a cut can replace one subpath with two.
    final subpathIndices = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final subpath in subpathIndices) {
      final indices = grouped[subpath]!..sort((a, b) => b.compareTo(a));
      final replacement = switch (mode) {
        NodeRemoval.preserveShape =>
          _removePreservingShape(result[subpath], indices),
        NodeRemoval.cut => _cutAt(result[subpath], indices.toSet()),
      };
      result.replaceRange(subpath, subpath + 1, replacement);
    }

    return EditablePath(result);
  }
}

/// Removes every index in [descendingIndices] from [subpath], refitting the
/// surrounding geometry each time.
///
/// Removing a node never splits a subpath, so working from the highest index
/// down keeps the remaining indices valid.
List<PathSubpath> _removePreservingShape(
  PathSubpath subpath,
  List<int> descendingIndices,
) {
  var result = [subpath];
  for (final index in descendingIndices) {
    if (result.isEmpty) break;
    result = _removeOnePreservingShape(result.single, index);
  }
  return result;
}

/// Removes the node at [index] and refits the surrounding geometry.
List<PathSubpath> _removeOnePreservingShape(PathSubpath subpath, int index) {
  final count = subpath.length;
  if (count <= 1) return const [];

  if (count == 2) {
    // Nothing is left to join; the survivor becomes a lone open node.
    final survivor = subpath.nodes[index == 0 ? 1 : 0];
    return [PathSubpath.single(survivor.withoutHandles())];
  }

  final nodes = List.of(subpath.nodes);
  final hasPrevious = subpath.closed || index > 0;
  final hasNext = subpath.closed || index < count - 1;

  if (!hasPrevious || !hasNext) {
    // An endpoint of an open subpath simply disappears; the new endpoint loses
    // the handle that pointed at the removed node.
    nodes.removeAt(index);
    if (!hasPrevious) {
      nodes[0] = _retyped(nodes.first.withHandle(NodeHandle.incoming, null));
    } else {
      nodes[nodes.length - 1] =
          _retyped(nodes.last.withHandle(NodeHandle.outgoing, null));
    }
    return [subpath.copyWith(nodes: nodes)];
  }

  final previousIndex = (index - 1 + count) % count;
  final nextIndex = (index + 1) % count;
  final previous = nodes[previousIndex];
  final removed = nodes[index];
  final next = nodes[nextIndex];

  final incomingSegment = PathSegment(
    start: previous.position,
    startControl: previous.outgoing,
    endControl: removed.incoming,
    end: removed.position,
  );
  final outgoingSegment = PathSegment(
    start: removed.position,
    startControl: removed.outgoing,
    endControl: next.incoming,
    end: next.position,
  );

  if (incomingSegment.isCurve || outgoingSegment.isCurve) {
    final (control1, control2) = fitCubic(
      sampleSegments([incomingSegment, outgoingSegment]),
      (previous.outgoing ?? removed.position) - previous.position,
      (next.incoming ?? removed.position) - next.position,
    );
    nodes[previousIndex] =
        _retyped(previous.withHandle(NodeHandle.outgoing, control1));
    nodes[nextIndex] = _retyped(next.withHandle(NodeHandle.incoming, control2));
  }
  // Two straight segments simply become one straight segment.

  nodes.removeAt(index);
  return [subpath.copyWith(nodes: nodes)];
}

/// Breaks [subpath] at every index in [indices], removing those nodes.
///
/// All cuts are applied in a single pass. Doing them one at a time would be
/// wrong for a closed subpath, because opening the loop rotates the nodes and
/// invalidates the indices that have not been processed yet.
List<PathSubpath> _cutAt(PathSubpath subpath, Set<int> indices) {
  final count = subpath.length;
  if (count <= 1 || indices.isEmpty) {
    return indices.isEmpty ? [subpath] : const [];
  }

  var nodes = subpath.nodes;
  var cuts = indices;

  if (subpath.closed) {
    // The loop opens up at one of the cuts; the remaining nodes start right
    // after it. The other cuts are remapped onto their new positions.
    final pivot = indices.reduce(math.min);
    nodes = [
      for (var i = 1; i < count; ++i) subpath.nodes[(pivot + i) % count]
    ];
    cuts = {
      for (final index in indices)
        if (index != pivot) (index - pivot - 1 + count) % count,
    };
  }

  // Split the now open run of nodes on every remaining cut, remembering where
  // each piece started so that only the ends produced by a cut lose a handle.
  final pieces = <List<PathNode>>[];
  final starts = <int>[];
  var current = <PathNode>[];
  var currentStart = 0;
  for (var i = 0; i < nodes.length; ++i) {
    if (cuts.contains(i)) {
      if (current.isNotEmpty) {
        pieces.add(current);
        starts.add(currentStart);
      }
      current = [];
      continue;
    }
    if (current.isEmpty) currentStart = i;
    current.add(nodes[i]);
  }
  if (current.isNotEmpty) {
    pieces.add(current);
    starts.add(currentStart);
  }

  return [
    for (var piece = 0; piece < pieces.length; ++piece)
      PathSubpath(
        nodes: _openEnds(
          pieces[piece],
          // A closed subpath was opened at the pivot, so both ends of the
          // rotated run are cut ends. In an open subpath the outer ends of the
          // original run were already endpoints and keep their handles.
          clearHead: subpath.closed || starts[piece] > 0,
          clearTail: subpath.closed ||
              starts[piece] + pieces[piece].length < nodes.length,
        ),
      ),
  ];
}

/// Drops the handles that pointed at a node which is no longer connected.
///
/// Only the sides that were actually cut are cleared; an endpoint that was
/// already an endpoint keeps its dangling handle, which matters because the
/// pen tool leaves one on the node it is currently extending from.
List<PathNode> _openEnds(
  List<PathNode> piece, {
  required bool clearHead,
  required bool clearTail,
}) {
  final nodes = List.of(piece);
  if (clearHead) {
    nodes[0] = _retyped(nodes.first.withHandle(NodeHandle.incoming, null));
  }
  if (clearTail) {
    nodes[nodes.length - 1] =
        _retyped(nodes.last.withHandle(NodeHandle.outgoing, null));
  }
  return nodes;
}

/// Re-derives the type of a node after its handles were changed structurally.
PathNode _retyped(PathNode node) => node.copyWith(
      type: inferNodeType(node.position, node.incoming, node.outgoing),
    );
