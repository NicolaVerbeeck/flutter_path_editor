import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Identifies one of the two Bézier handles that surround a [PathNode].
enum NodeHandle {
  /// The handle that controls the segment arriving at the node.
  incoming,

  /// The handle that controls the segment leaving the node.
  outgoing;

  /// The handle on the other side of the node.
  NodeHandle get opposite =>
      this == NodeHandle.incoming ? NodeHandle.outgoing : NodeHandle.incoming;
}

/// Describes how the two handles of a [PathNode] relate to each other.
enum PathNodeType {
  /// The node has no active handles. Segments meet at a sharp angle and no
  /// tangent continuity is enforced.
  corner,

  /// The handles are collinear and have the same length. Moving one handle
  /// mirrors the other, guaranteeing a smooth, symmetric transition.
  mirrored,

  /// The handles are collinear but may have different lengths. Moving one
  /// handle rotates the other to keep the tangent continuous, but preserves
  /// its length.
  aligned,

  /// The handles are fully independent ("broken"). Moving one handle leaves
  /// the other untouched, allowing a sharp change of direction while keeping
  /// curved segments on either side.
  disconnected;

  /// Whether nodes of this type enforce tangent continuity across the node.
  bool get isSmooth =>
      this == PathNodeType.mirrored || this == PathNodeType.aligned;
}

/// A single anchor point of an [EditablePath].
///
/// A node owns the two Bézier handles that surround it: [incoming] controls the
/// curvature of the segment arriving at the node and [outgoing] controls the
/// curvature of the segment leaving it. Both handles are expressed in absolute
/// coordinates, in the same space as [position].
///
/// This is deliberately different from the SVG representation, where the two
/// control points of a cubic command belong to the command rather than to the
/// anchors. The node centric representation is what makes linked handles,
/// corner/smooth conversion and shape preserving deletion possible.
@immutable
class PathNode {
  /// The anchor position of this node.
  final Offset position;

  /// The absolute position of the handle controlling the incoming segment, or
  /// `null` when the incoming segment is a straight line.
  final Offset? incoming;

  /// The absolute position of the handle controlling the outgoing segment, or
  /// `null` when the outgoing segment is a straight line.
  final Offset? outgoing;

  /// Describes how [incoming] and [outgoing] are linked.
  final PathNodeType type;

  /// Creates a node at [position] with the given handles.
  ///
  /// No linkage rules are enforced by this constructor; use [normalized] to
  /// force the handles to satisfy the invariant implied by [type].
  const PathNode({
    required this.position,
    this.incoming,
    this.outgoing,
    this.type = PathNodeType.corner,
  });

  /// Creates a corner node, a node without any handles.
  const PathNode.corner(this.position)
      : incoming = null,
        outgoing = null,
        type = PathNodeType.corner;

  /// Creates a symmetric smooth node whose [outgoing] handle sits at
  /// `position + delta` and whose [incoming] handle is mirrored across
  /// [position].
  ///
  /// This is what the pen tool produces when a click is turned into a drag.
  factory PathNode.smooth({
    required Offset position,
    required Offset delta,
  }) =>
      PathNode(
        position: position,
        incoming: position - delta,
        outgoing: position + delta,
        type: PathNodeType.mirrored,
      );

  /// Whether this node has a handle controlling its incoming segment.
  bool get hasIncoming => incoming != null;

  /// Whether this node has a handle controlling its outgoing segment.
  bool get hasOutgoing => outgoing != null;

  /// Whether this node has at least one active handle.
  bool get hasHandles => hasIncoming || hasOutgoing;

  /// Whether this is a corner node without active handles.
  bool get isCorner => type == PathNodeType.corner;

  /// The absolute position of [handle], or `null` when it is not active.
  Offset? handle(NodeHandle handle) => switch (handle) {
        NodeHandle.incoming => incoming,
        NodeHandle.outgoing => outgoing,
      };

  /// The offset of [handle] relative to [position], or `null` when the handle
  /// is not active.
  Offset? handleVector(NodeHandle handle) {
    final value = this.handle(handle);
    return value == null ? null : value - position;
  }

  /// Returns a copy of this node with the non handle properties replaced.
  PathNode copyWith({Offset? position, PathNodeType? type}) => PathNode(
        position: position ?? this.position,
        incoming: incoming,
        outgoing: outgoing,
        type: type ?? this.type,
      );

  /// Returns a copy of this node with [handle] set to [value], without
  /// applying any linkage rules. Passing `null` removes the handle.
  PathNode withHandle(NodeHandle handle, Offset? value) => switch (handle) {
        NodeHandle.incoming => PathNode(
            position: position,
            incoming: value,
            outgoing: outgoing,
            type: type,
          ),
        NodeHandle.outgoing => PathNode(
            position: position,
            incoming: incoming,
            outgoing: value,
            type: type,
          ),
      };

  /// Returns a copy of this node without any handles, keeping [type].
  PathNode withoutHandles() => PathNode(position: position, type: type);

  /// Moves [handle] to [value] and updates the opposite handle according to
  /// [type].
  ///
  /// * [PathNodeType.mirrored] mirrors the opposite handle across [position].
  /// * [PathNodeType.aligned] rotates the opposite handle to stay collinear
  ///   while preserving its length.
  /// * [PathNodeType.corner] and [PathNodeType.disconnected] leave the
  ///   opposite handle untouched.
  ///
  /// When [breakLink] is `true` the node is converted to
  /// [PathNodeType.disconnected] first, so the opposite handle keeps its
  /// position. This implements the "break the handles" interaction.
  PathNode withLinkedHandle(
    NodeHandle handle,
    Offset value, {
    bool breakLink = false,
  }) {
    if (breakLink) {
      return withHandle(handle, value).copyWith(
        type: PathNodeType.disconnected,
      );
    }

    final moved = withHandle(handle, value);
    final opposite = handle.opposite;
    final oppositeValue = this.handle(opposite);
    if (oppositeValue == null) return moved;

    final vector = value - position;
    return switch (type) {
      PathNodeType.corner || PathNodeType.disconnected => moved,
      PathNodeType.mirrored => moved.withHandle(opposite, position - vector),
      PathNodeType.aligned => moved.withHandle(
          opposite,
          _align(position, vector, oppositeValue - position),
        ),
    };
  }

  /// Returns a copy of this node translated by [delta]. Active handles move
  /// along with the anchor.
  PathNode translated(Offset delta) => PathNode(
        position: position + delta,
        incoming: incoming == null ? null : incoming! + delta,
        outgoing: outgoing == null ? null : outgoing! + delta,
        type: type,
      );

  /// Returns a copy of this node moved to [target]. Active handles keep their
  /// position relative to the anchor.
  PathNode movedTo(Offset target) => translated(target - position);

  /// Converts this node to [target].
  ///
  /// Converting to [PathNodeType.corner] collapses both handles. Converting a
  /// corner node to a smooth type creates handles pointing along the tangent
  /// implied by the [previous] and [next] anchor positions, scaled by
  /// [smoothFactor]. Converting between smooth types adjusts the existing
  /// handles to satisfy the new invariant.
  PathNode convertedTo(
    PathNodeType target, {
    Offset? previous,
    Offset? next,
    double smoothFactor = _defaultSmoothFactor,
  }) {
    if (target == PathNodeType.corner) {
      return withoutHandles().copyWith(type: PathNodeType.corner);
    }
    if (!hasHandles) {
      return _grownHandles(
        target,
        previous: previous,
        next: next,
        smoothFactor: smoothFactor,
      );
    }
    return copyWith(type: target).normalized();
  }

  /// Forces the handles to satisfy the invariant implied by [type].
  ///
  /// A [PathNodeType.corner] node loses its handles, a [PathNodeType.mirrored]
  /// node gets two collinear handles of equal length and a
  /// [PathNodeType.aligned] node gets two collinear handles that keep their
  /// individual lengths. [PathNodeType.disconnected] nodes are returned as is.
  PathNode normalized() {
    switch (type) {
      case PathNodeType.corner:
        return hasHandles ? withoutHandles() : this;
      case PathNodeType.disconnected:
        return this;
      case PathNodeType.mirrored:
      case PathNodeType.aligned:
        final incomingVector = handleVector(NodeHandle.incoming);
        final outgoingVector = handleVector(NodeHandle.outgoing);
        if (incomingVector == null || outgoingVector == null) return this;

        final direction = _averageDirection(-incomingVector, outgoingVector);
        if (direction == null) return this;

        final outLength = type == PathNodeType.mirrored
            ? (incomingVector.distance + outgoingVector.distance) / 2
            : outgoingVector.distance;
        final inLength =
            type == PathNodeType.mirrored ? outLength : incomingVector.distance;

        return PathNode(
          position: position,
          incoming: position - direction * inLength,
          outgoing: position + direction * outLength,
          type: type,
        );
    }
  }

  PathNode _grownHandles(
    PathNodeType target, {
    required Offset? previous,
    required Offset? next,
    required double smoothFactor,
  }) {
    final direction = _tangentDirection(previous, next);
    if (direction == null) {
      // Not enough context to derive a tangent; keep the node a corner.
      return copyWith(type: PathNodeType.corner);
    }

    final inLength =
        previous == null ? 0.0 : (position - previous).distance * smoothFactor;
    final outLength =
        next == null ? 0.0 : (next - position).distance * smoothFactor;
    final mirroredLength = target == PathNodeType.mirrored
        ? _nonZeroAverage(inLength, outLength)
        : null;

    return PathNode(
      position: position,
      incoming: previous == null
          ? null
          : position - direction * (mirroredLength ?? inLength),
      outgoing: next == null
          ? null
          : position + direction * (mirroredLength ?? outLength),
      type: target,
    );
  }

  Offset? _tangentDirection(Offset? previous, Offset? next) {
    if (previous != null && next != null) {
      return _normalize(next - previous);
    }
    if (next != null) return _normalize(next - position);
    if (previous != null) return _normalize(position - previous);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathNode &&
          position == other.position &&
          incoming == other.incoming &&
          outgoing == other.outgoing &&
          type == other.type);

  @override
  int get hashCode => Object.hash(position, incoming, outgoing, type);

  @override
  String toString() => 'PathNode(${type.name}, $position, '
      'in: $incoming, out: $outgoing)';

  /// The fraction of the distance to a neighbouring anchor used as handle
  /// length when growing handles on a corner node.
  static const _defaultSmoothFactor = 1 / 3;
}

double _nonZeroAverage(double a, double b) {
  if (a == 0) return b;
  if (b == 0) return a;
  return (a + b) / 2;
}

Offset? _normalize(Offset vector) {
  final length = vector.distance;
  if (length == 0 || !length.isFinite) return null;
  return vector / length;
}

/// Places the opposite handle collinear with [vector] while preserving the
/// length of [oppositeVector].
Offset _align(Offset position, Offset vector, Offset oppositeVector) {
  final direction = _normalize(vector);
  if (direction == null) return position + oppositeVector;
  return position - direction * oppositeVector.distance;
}

/// Averages two directions, returning `null` when they cancel each other out.
Offset? _averageDirection(Offset a, Offset b) {
  final normalizedA = _normalize(a);
  final normalizedB = _normalize(b);
  if (normalizedA == null) return normalizedB;
  if (normalizedB == null) return normalizedA;

  final sum = normalizedA + normalizedB;
  final direction = _normalize(sum);
  if (direction != null) return direction;

  // The two handles point in exactly opposite directions; fall back to the
  // outgoing direction so the node keeps a stable tangent.
  return normalizedB;
}

/// Math helpers shared by the node and path models.
extension OffsetAngle on Offset {
  /// The angle of this offset in radians, measured from the positive x axis.
  double get angle => math.atan2(dy, dx);
}
