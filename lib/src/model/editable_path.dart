import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/path_node.dart';
import 'package:path_editor/src/model/path_operators.dart';
import 'package:path_editor/src/model/path_segment.dart';

/// A reference to a single node inside an [EditablePath].
@immutable
class NodeRef implements Comparable<NodeRef> {
  /// The index of the subpath the node belongs to.
  final int subpath;

  /// The index of the node inside its subpath.
  final int node;

  /// Creates a reference to the node at [node] inside [subpath].
  const NodeRef(this.subpath, this.node);

  /// A reference to the handle [handle] of this node.
  HandleRef handleRef(NodeHandle handle) => HandleRef(this, handle);

  /// Returns a reference to another node in the same subpath.
  NodeRef sibling(int node) => NodeRef(subpath, node);

  @override
  int compareTo(NodeRef other) => subpath == other.subpath
      ? node.compareTo(other.node)
      : subpath.compareTo(other.subpath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodeRef && subpath == other.subpath && node == other.node);

  @override
  int get hashCode => Object.hash(subpath, node);

  @override
  String toString() => 'NodeRef($subpath:$node)';
}

/// A reference to a single segment inside an [EditablePath].
///
/// The segment runs from the node at [index] to the next node in the subpath.
/// For a closed subpath the last segment wraps back to the first node.
@immutable
class SegmentRef {
  /// The index of the subpath the segment belongs to.
  final int subpath;

  /// The index of the segment inside its subpath.
  final int index;

  /// Creates a reference to the segment at [index] inside [subpath].
  const SegmentRef(this.subpath, this.index);

  /// A reference to the node the segment starts at.
  NodeRef get startNode => NodeRef(subpath, index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentRef && subpath == other.subpath && index == other.index);

  @override
  int get hashCode => Object.hash(subpath, index);

  @override
  String toString() => 'SegmentRef($subpath:$index)';
}

/// A reference to one of the two Bézier handles of a node.
@immutable
class HandleRef {
  /// The node owning the handle.
  final NodeRef node;

  /// Which of the two handles is referenced.
  final NodeHandle handle;

  /// Creates a reference to [handle] of [node].
  const HandleRef(this.node, this.handle);

  /// A reference to the handle on the other side of the same node.
  HandleRef get opposite => HandleRef(node, handle.opposite);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HandleRef && node == other.node && handle == other.handle);

  @override
  int get hashCode => Object.hash(node, handle);

  @override
  String toString() => 'HandleRef($node, ${handle.name})';
}

/// A single continuous run of nodes, optionally closed.
@immutable
class PathSubpath {
  /// The nodes making up this subpath, in drawing order.
  final List<PathNode> nodes;

  /// Whether the last node connects back to the first one.
  final bool closed;

  /// Creates a subpath from [nodes].
  PathSubpath({required List<PathNode> nodes, this.closed = false})
      : nodes = List.unmodifiable(nodes);

  /// Creates a subpath containing a single node.
  PathSubpath.single(PathNode node)
      : nodes = List.unmodifiable([node]),
        closed = false;

  /// The number of nodes in this subpath.
  int get length => nodes.length;

  /// Whether this subpath has no nodes at all.
  bool get isEmpty => nodes.isEmpty;

  /// Whether this subpath has at least one node.
  bool get isNotEmpty => nodes.isNotEmpty;

  /// The first node of this subpath.
  PathNode get first => nodes.first;

  /// The last node of this subpath.
  PathNode get last => nodes.last;

  /// The number of drawable segments in this subpath.
  int get segmentCount {
    if (nodes.length < 2) return 0;
    return closed ? nodes.length : nodes.length - 1;
  }

  /// The index of the node the segment at [index] ends at.
  int endNodeIndex(int index) => (index + 1) % nodes.length;

  /// The geometry of the segment at [index].
  PathSegment segmentAt(int index) {
    final from = nodes[index];
    final to = nodes[endNodeIndex(index)];
    return PathSegment(
      start: from.position,
      startControl: from.outgoing,
      endControl: to.incoming,
      end: to.position,
    );
  }

  /// All segments of this subpath, in drawing order.
  Iterable<PathSegment> get segments sync* {
    for (var i = 0; i < segmentCount; ++i) {
      yield segmentAt(i);
    }
  }

  /// The position of the node preceding [index], or `null` when [index] is the
  /// first node of an open subpath.
  Offset? previousPosition(int index) {
    if (nodes.length < 2) return null;
    if (index > 0) return nodes[index - 1].position;
    return closed ? nodes.last.position : null;
  }

  /// The position of the node following [index], or `null` when [index] is the
  /// last node of an open subpath.
  Offset? nextPosition(int index) {
    if (nodes.length < 2) return null;
    if (index < nodes.length - 1) return nodes[index + 1].position;
    return closed ? nodes.first.position : null;
  }

  /// Returns a copy of this subpath with the given properties replaced.
  PathSubpath copyWith({List<PathNode>? nodes, bool? closed}) => PathSubpath(
        nodes: nodes ?? this.nodes,
        closed: closed ?? this.closed,
      );

  /// Returns a copy of this subpath with the node at [index] replaced.
  PathSubpath replaceNode(int index, PathNode node) {
    final updated = List.of(nodes);
    updated[index] = node;
    return copyWith(nodes: updated);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathSubpath &&
          closed == other.closed &&
          listEquals(nodes, other.nodes));

  @override
  int get hashCode => Object.hash(closed, Object.hashAll(nodes));

  @override
  String toString() => 'PathSubpath(${nodes.length} nodes, closed: $closed)';
}

/// An immutable, node centric representation of an editable path.
///
/// This is the model the editor works on. It can be converted to and from the
/// SVG oriented [PathOperator] representation without loss, so paths keep
/// round tripping through SVG, PDF and any other consumer of the operator
/// list.
@immutable
class EditablePath {
  /// The subpaths making up this path.
  final List<PathSubpath> subpaths;

  /// Creates a path from [subpaths].
  EditablePath(List<PathSubpath> subpaths)
      : subpaths = List.unmodifiable(subpaths);

  /// A path without any nodes.
  static final EditablePath empty = EditablePath(const []);

  /// Parses [svg] into an editable path.
  ///
  /// All relative commands, arcs and quadratic curves are normalised into
  /// absolute move, line and cubic operations first.
  factory EditablePath.fromSvg(String svg) =>
      EditablePath.fromOperators(PathOperator.parse(svg));

  /// Converts an operator list into an editable path.
  factory EditablePath.fromOperators(List<PathOperator> operators) {
    final subpaths = <PathSubpath>[];
    var nodes = <PathNode>[];
    var closed = false;
    Offset? subpathStart;

    void flush() {
      if (nodes.isEmpty) return;
      subpaths.add(_finishSubpath(nodes, closed));
      nodes = [];
      closed = false;
    }

    void ensureStarted(Offset position) {
      if (nodes.isNotEmpty) return;
      // A subpath continuing after a close command restarts at the position of
      // the previous subpath start, as mandated by the SVG specification.
      nodes.add(PathNode.corner(subpathStart ?? position));
    }

    for (final operator in operators) {
      switch (operator) {
        case MoveTo(x: final x, y: final y):
          flush();
          subpathStart = Offset(x, y);
          nodes.add(PathNode.corner(subpathStart));
        case LineTo(x: final x, y: final y):
          final position = Offset(x, y);
          ensureStarted(position);
          nodes.add(PathNode.corner(position));
        case CubicTo(
            x1: final x1,
            y1: final y1,
            x2: final x2,
            y2: final y2,
            x: final x,
            y: final y
          ):
          final position = Offset(x, y);
          ensureStarted(position);
          final last = nodes.removeLast();
          nodes.add(last.withHandle(NodeHandle.outgoing, Offset(x1, y1)));
          nodes.add(
            PathNode(position: position, incoming: Offset(x2, y2)),
          );
        case Close():
          if (nodes.isNotEmpty) {
            closed = true;
            flush();
          }
      }
    }
    flush();

    return EditablePath(subpaths);
  }

  /// Whether this path contains no nodes.
  bool get isEmpty => subpaths.every((subpath) => subpath.isEmpty);

  /// Whether this path contains at least one node.
  bool get isNotEmpty => !isEmpty;

  /// The total number of nodes across all subpaths.
  int get nodeCount =>
      subpaths.fold(0, (total, subpath) => total + subpath.length);

  /// References to every node of this path, in drawing order.
  Iterable<NodeRef> get nodeRefs sync* {
    for (var s = 0; s < subpaths.length; ++s) {
      for (var n = 0; n < subpaths[s].length; ++n) {
        yield NodeRef(s, n);
      }
    }
  }

  /// References to every segment of this path, in drawing order.
  Iterable<SegmentRef> get segmentRefs sync* {
    for (var s = 0; s < subpaths.length; ++s) {
      for (var i = 0; i < subpaths[s].segmentCount; ++i) {
        yield SegmentRef(s, i);
      }
    }
  }

  /// The indices of the subpaths that are not closed and contain a node.
  Iterable<int> get openSubpathIndices sync* {
    for (var s = 0; s < subpaths.length; ++s) {
      if (!subpaths[s].closed && subpaths[s].isNotEmpty) yield s;
    }
  }

  /// Whether [ref] points at an existing node.
  bool contains(NodeRef ref) =>
      ref.subpath >= 0 &&
      ref.subpath < subpaths.length &&
      ref.node >= 0 &&
      ref.node < subpaths[ref.subpath].length;

  /// Whether [ref] points at an existing segment.
  bool containsSegment(SegmentRef ref) =>
      ref.subpath >= 0 &&
      ref.subpath < subpaths.length &&
      ref.index >= 0 &&
      ref.index < subpaths[ref.subpath].segmentCount;

  /// The node [ref] points at.
  ///
  /// Throws a [RangeError] when [ref] is out of range; use [nodeOrNull] when
  /// the reference may be stale.
  PathNode nodeAt(NodeRef ref) => subpaths[ref.subpath].nodes[ref.node];

  /// The node [ref] points at, or `null` when [ref] is out of range.
  PathNode? nodeOrNull(NodeRef ref) => contains(ref) ? nodeAt(ref) : null;

  /// The subpath [ref] belongs to.
  PathSubpath subpathOf(NodeRef ref) => subpaths[ref.subpath];

  /// The geometry of the segment [ref] points at.
  PathSegment segmentAt(SegmentRef ref) =>
      subpaths[ref.subpath].segmentAt(ref.index);

  /// The absolute position of the handle [ref] points at, or `null` when the
  /// handle is not active.
  Offset? handleAt(HandleRef ref) => nodeOrNull(ref.node)?.handle(ref.handle);

  /// The positions of the nodes surrounding [ref], used when deriving tangents.
  (Offset? previous, Offset? next) neighboursOf(NodeRef ref) {
    final subpath = subpaths[ref.subpath];
    return (subpath.previousPosition(ref.node), subpath.nextPosition(ref.node));
  }

  /// Returns a copy of this path with the subpath at [index] replaced.
  EditablePath replaceSubpath(int index, PathSubpath subpath) {
    final updated = List.of(subpaths);
    updated[index] = subpath;
    return EditablePath(updated);
  }

  /// Returns a copy of this path with the node [ref] points at replaced.
  EditablePath replaceNode(NodeRef ref, PathNode node) => replaceSubpath(
      ref.subpath, subpaths[ref.subpath].replaceNode(ref.node, node));

  /// Converts this path into its operator representation.
  List<PathOperator> toOperators() {
    final operators = <PathOperator>[];
    _walk(
      onMove: (position) =>
          operators.add(MoveTo(x: position.dx, y: position.dy)),
      onSegment: (segment) => operators.add(
        segment.isCurve
            ? CubicTo(
                x1: segment.control1.dx,
                y1: segment.control1.dy,
                x2: segment.control2.dx,
                y2: segment.control2.dy,
                x: segment.end.dx,
                y: segment.end.dy,
              )
            : LineTo(x: segment.end.dx, y: segment.end.dy),
      ),
      onClose: () => operators.add(const Close()),
    );
    return operators;
  }

  /// Converts this path into an SVG path string.
  String toSvg() => toOperators().toSvg();

  /// Converts this path into a [Path] that can be painted.
  Path toUiPath() {
    final path = Path();
    _walk(
      onMove: (position) => path.moveTo(position.dx, position.dy),
      onSegment: (segment) => segment.addTo(path),
      onClose: path.close,
    );
    return path;
  }

  /// The exact bounding box of this path.
  ///
  /// When [strokeWidth] is provided the box is inflated by half the stroke
  /// width, matching how the path is painted.
  Rect bounds({double strokeWidth = 0}) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    void include(Rect rect) {
      minX = math.min(minX, rect.left);
      minY = math.min(minY, rect.top);
      maxX = math.max(maxX, rect.right);
      maxY = math.max(maxY, rect.bottom);
    }

    for (final subpath in subpaths) {
      if (subpath.isEmpty) continue;
      if (subpath.segmentCount == 0) {
        final position = subpath.first.position;
        include(Rect.fromPoints(position, position));
        continue;
      }
      for (final segment in subpath.segments) {
        include(segment.bounds);
      }
    }

    if (minX == double.infinity) return Rect.zero;

    final padding = strokeWidth / 2;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  void _walk({
    required void Function(Offset position) onMove,
    required void Function(PathSegment segment) onSegment,
    required void Function() onClose,
  }) {
    for (final subpath in subpaths) {
      if (subpath.isEmpty) continue;

      onMove(subpath.first.position);
      final count = subpath.segmentCount;
      for (var i = 0; i < count; ++i) {
        final segment = subpath.segmentAt(i);
        final isClosingSegment = subpath.closed && i == count - 1;
        // A straight closing segment is implied by the close command itself.
        if (isClosingSegment && !segment.isCurve) continue;
        onSegment(segment);
      }
      if (subpath.closed) onClose();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditablePath && listEquals(subpaths, other.subpaths));

  @override
  int get hashCode => Object.hashAll(subpaths);

  @override
  String toString() => 'EditablePath(${subpaths.length} subpaths, '
      '$nodeCount nodes)';
}

/// Finalises a freshly parsed subpath by merging the duplicated closing node
/// and inferring the type of every node.
PathSubpath _finishSubpath(List<PathNode> nodes, bool closed) {
  var result = nodes;

  if (closed && result.length > 2) {
    final first = result.first;
    final last = result.last;
    if (_nearlyEqual(first.position, last.position)) {
      // The path was explicitly drawn back to its start before closing. The
      // duplicated node is folded into the first one so the editor shows a
      // single anchor. A subpath with only two anchors is left alone: folding
      // it would leave a single anchor with no segment at all, which would
      // silently drop the geometry of a one curve loop.
      result = [
        first.withHandle(NodeHandle.incoming, last.incoming),
        ...result.sublist(1, result.length - 1),
      ];
    }
  }

  return PathSubpath(
    nodes: [
      for (final node in result)
        node.copyWith(
          type: inferNodeType(node.position, node.incoming, node.outgoing),
        ),
    ],
    closed: closed,
  );
}

/// Derives the [PathNodeType] that matches the geometric relation between the
/// handles of a node.
PathNodeType inferNodeType(
    Offset position, Offset? incoming, Offset? outgoing) {
  if (incoming == null && outgoing == null) return PathNodeType.corner;
  if (incoming == null || outgoing == null) return PathNodeType.disconnected;

  final incomingVector = incoming - position;
  final outgoingVector = outgoing - position;
  final incomingLength = incomingVector.distance;
  final outgoingLength = outgoingVector.distance;
  if (incomingLength == 0 || outgoingLength == 0) {
    return PathNodeType.disconnected;
  }

  final cross = incomingVector.dx * outgoingVector.dy -
      incomingVector.dy * outgoingVector.dx;
  final dot = incomingVector.dx * outgoingVector.dx +
      incomingVector.dy * outgoingVector.dy;
  if (dot >= 0 || cross.abs() > 1e-6 * incomingLength * outgoingLength) {
    return PathNodeType.disconnected;
  }

  final lengthTolerance = 1e-6 * math.max(incomingLength, outgoingLength);
  return (incomingLength - outgoingLength).abs() <= lengthTolerance
      ? PathNodeType.mirrored
      : PathNodeType.aligned;
}

bool _nearlyEqual(Offset a, Offset b) {
  const tolerance = 1e-9;
  final scale = math.max(
    1.0,
    math.max(a.distance, b.distance),
  );
  return (a - b).distance <= tolerance * scale;
}
