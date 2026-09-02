import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/config/path_editor_behavior.dart';
import 'package:path_editor/src/config/path_editor_viewport.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_node.dart';

/// What the pointer is currently over.
@immutable
sealed class PathHit {
  const PathHit();
}

/// The pointer is not over anything interactive.
@immutable
class NoHit extends PathHit {
  /// Creates a miss.
  const NoHit();

  @override
  bool operator ==(Object other) => other is NoHit;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NoHit()';
}

/// The pointer is over a node.
@immutable
class NodeHit extends PathHit {
  /// The node under the pointer.
  final NodeRef node;

  /// The distance from the pointer to the node, in scene units.
  final double distance;

  /// Creates a node hit.
  const NodeHit(this.node, this.distance);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodeHit && node == other.node && distance == other.distance);

  @override
  int get hashCode => Object.hash(node, distance);

  @override
  String toString() => 'NodeHit($node)';
}

/// The pointer is over the first node of the open subpath being drawn, so
/// clicking would close the path.
@immutable
class CloseTargetHit extends PathHit {
  /// The node that would close the path.
  final NodeRef node;

  /// The distance from the pointer to the node, in scene units.
  final double distance;

  /// Creates a close target hit.
  const CloseTargetHit(this.node, this.distance);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CloseTargetHit &&
          node == other.node &&
          distance == other.distance);

  @override
  int get hashCode => Object.hash(node, distance);

  @override
  String toString() => 'CloseTargetHit($node)';
}

/// The pointer is over a Bézier handle.
@immutable
class HandleHit extends PathHit {
  /// The handle under the pointer.
  final HandleRef handle;

  /// The distance from the pointer to the handle, in scene units.
  final double distance;

  /// Creates a handle hit.
  const HandleHit(this.handle, this.distance);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HandleHit &&
          handle == other.handle &&
          distance == other.distance);

  @override
  int get hashCode => Object.hash(handle, distance);

  @override
  String toString() => 'HandleHit($handle)';
}

/// The pointer is over a segment.
@immutable
class SegmentHit extends PathHit {
  /// The segment under the pointer.
  final SegmentRef segment;

  /// Where along the segment the pointer projects, in the range `[0, 1]`.
  final double t;

  /// The projected position on the segment, in scene coordinates.
  final Offset position;

  /// The distance from the pointer to the segment, in scene units.
  final double distance;

  /// Creates a segment hit.
  const SegmentHit({
    required this.segment,
    required this.t,
    required this.position,
    required this.distance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentHit &&
          segment == other.segment &&
          t == other.t &&
          position == other.position &&
          distance == other.distance);

  @override
  int get hashCode => Object.hash(segment, t, position, distance);

  @override
  String toString() => 'SegmentHit($segment, t: $t)';
}

/// Resolves what the pointer is over, in priority order.
///
/// Handles win over nodes, which win over segments, so that the smaller and
/// more precise targets stay reachable even when they overlap.
class PathHitTester {
  /// The path to test against.
  final EditablePath path;

  /// The hit radii to apply.
  final PathEditorBehavior behavior;

  /// The viewport, used to convert screen space radii into scene units.
  final PathEditorViewport viewport;

  /// Creates a hit tester.
  const PathHitTester({
    required this.path,
    this.behavior = PathEditorBehavior.defaults,
    this.viewport = PathEditorViewport.identity,
  });

  /// Resolves what is under [scenePoint].
  ///
  /// Handles are only considered for nodes in [handleNodes], because handles
  /// are only drawn for those. When [closeTarget] is given, hitting that node
  /// produces a [CloseTargetHit] instead of a [NodeHit].
  PathHit hitTest(
    Offset scenePoint, {
    Set<NodeRef> handleNodes = const {},
    NodeRef? closeTarget,
    bool includeSegments = true,
  }) {
    final handleHit = _hitHandles(scenePoint, handleNodes);
    if (handleHit != null) return handleHit;

    final nodeHit = _hitNodes(scenePoint);
    if (nodeHit != null) {
      if (closeTarget != null && nodeHit.node == closeTarget) {
        return CloseTargetHit(nodeHit.node, nodeHit.distance);
      }
      return nodeHit;
    }

    if (!includeSegments) return const NoHit();
    return _hitSegments(scenePoint) ?? const NoHit();
  }

  HandleHit? _hitHandles(Offset scenePoint, Set<NodeRef> handleNodes) {
    if (handleNodes.isEmpty) return null;
    final radius = viewport.toSceneDistance(behavior.handleHitRadius);

    HandleHit? best;
    for (final ref in handleNodes) {
      if (!path.contains(ref)) continue;
      final node = path.nodeAt(ref);
      for (final which in NodeHandle.values) {
        final position = node.handle(which);
        if (position == null) continue;

        final distance = (position - scenePoint).distance;
        if (distance <= radius && (best == null || distance < best.distance)) {
          best = HandleHit(HandleRef(ref, which), distance);
        }
      }
    }
    return best;
  }

  NodeHit? _hitNodes(Offset scenePoint) {
    final radius = viewport.toSceneDistance(behavior.nodeHitRadius);

    NodeHit? best;
    for (final ref in path.nodeRefs) {
      final distance = (path.nodeAt(ref).position - scenePoint).distance;
      if (distance <= radius && (best == null || distance < best.distance)) {
        best = NodeHit(ref, distance);
      }
    }
    return best;
  }

  SegmentHit? _hitSegments(Offset scenePoint) {
    final maxDistance = viewport.toSceneDistance(behavior.segmentHitDistance);

    SegmentHit? best;
    for (final ref in path.segmentRefs) {
      final projection = path.segmentAt(ref).project(scenePoint);
      if (projection.distance > maxDistance) continue;
      if (best != null && projection.distance >= best.distance) continue;

      best = SegmentHit(
        segment: ref,
        t: projection.t,
        position: projection.point,
        distance: projection.distance,
      );
    }
    return best;
  }
}
