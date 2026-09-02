import 'dart:math' as math;
import 'dart:ui';

import 'package:path_editor/src/config/path_editor_snapping.dart';
import 'package:path_editor/src/model/editable_path.dart';

/// Applies [PathEditorSnapping] to a position being dragged or created.
///
/// The engine works entirely in scene coordinates; the screen space threshold
/// is converted using the viewport [scale] so that snapping feels the same at
/// every zoom level.
class SnapEngine {
  /// The configuration to apply.
  final PathEditorSnapping config;

  /// The zoom factor of the viewport the interaction happens in.
  final double scale;

  /// Creates a snap engine.
  const SnapEngine({required this.config, this.scale = 1.0});

  /// The snapping threshold expressed in scene units.
  double get sceneThreshold => config.threshold / scale;

  /// Snaps [position] against [path].
  ///
  /// Nodes in [exclude] are ignored as snap targets, which is how a node being
  /// dragged avoids snapping to itself. When [constrainAngle] is set and
  /// [anchor] is provided, the position is instead constrained to a fixed
  /// angle around the anchor, which is what the constrain modifier does while
  /// dragging a handle.
  SnapResult snap(
    Offset position, {
    required EditablePath path,
    Set<NodeRef> exclude = const {},
    Offset? anchor,
    bool constrainAngle = false,
    bool enabled = true,
  }) {
    if (constrainAngle && anchor != null) {
      return _constrainAngle(position, anchor);
    }
    if (!enabled || !config.enabled) return SnapResult.none(position);

    final threshold = sceneThreshold;
    final guides = <SnapGuide>[];

    // Snapping straight onto a target wins over axis alignment, so it is
    // checked first and returns immediately.
    Offset? bestTarget;
    var bestDistance = double.infinity;
    SnapKind bestKind = SnapKind.node;

    void considerTarget(Offset target, SnapKind kind) {
      final distance = (target - position).distance;
      if (distance < bestDistance && distance <= threshold) {
        bestDistance = distance;
        bestTarget = target;
        bestKind = kind;
      }
    }

    if (config.snapToNodes) {
      for (final ref in path.nodeRefs) {
        if (exclude.contains(ref)) continue;
        considerTarget(path.nodeAt(ref).position, SnapKind.node);
      }
    }
    if (config.snapToMidpoints) {
      for (final ref in path.segmentRefs) {
        if (_segmentTouches(ref, path, exclude)) continue;
        considerTarget(path.segmentAt(ref).midpoint, SnapKind.midpoint);
      }
    }

    final target = bestTarget;
    if (target != null) {
      return SnapResult(
        position: target,
        guides: [SnapGuide(start: target, end: target, kind: bestKind)],
      );
    }

    if (!config.snapToAxes) return SnapResult.none(position);

    var snapped = position;
    Offset? verticalReference;
    Offset? horizontalReference;
    var bestVertical = threshold;
    var bestHorizontal = threshold;

    for (final ref in path.nodeRefs) {
      if (exclude.contains(ref)) continue;
      final candidate = path.nodeAt(ref).position;

      final dx = (candidate.dx - position.dx).abs();
      if (dx <= bestVertical) {
        bestVertical = dx;
        verticalReference = candidate;
      }
      final dy = (candidate.dy - position.dy).abs();
      if (dy <= bestHorizontal) {
        bestHorizontal = dy;
        horizontalReference = candidate;
      }
    }

    if (verticalReference != null) {
      snapped = Offset(verticalReference.dx, snapped.dy);
    }
    if (horizontalReference != null) {
      snapped = Offset(snapped.dx, horizontalReference.dy);
    }

    // The guides are built after both axes are resolved so they end exactly on
    // the final snapped position.
    if (verticalReference != null) {
      guides.add(
        SnapGuide(
          start: verticalReference,
          end: snapped,
          kind: SnapKind.verticalAxis,
        ),
      );
    }
    if (horizontalReference != null) {
      guides.add(
        SnapGuide(
          start: horizontalReference,
          end: snapped,
          kind: SnapKind.horizontalAxis,
        ),
      );
    }

    return guides.isEmpty
        ? SnapResult.none(position)
        : SnapResult(position: snapped, guides: guides);
  }

  SnapResult _constrainAngle(Offset position, Offset anchor) {
    final vector = position - anchor;
    final distance = vector.distance;
    if (distance == 0) return SnapResult.none(position);

    final increment = config.angleIncrement * math.pi / 180;
    if (increment <= 0) return SnapResult.none(position);

    final angle = math.atan2(vector.dy, vector.dx);
    final snappedAngle = (angle / increment).roundToDouble() * increment;
    final snapped = anchor +
        Offset(math.cos(snappedAngle), math.sin(snappedAngle)) * distance;

    return SnapResult(
      position: snapped,
      guides: [
        SnapGuide(start: anchor, end: snapped, kind: SnapKind.angle),
      ],
    );
  }

  /// Whether either endpoint of [ref] is being dragged, in which case its
  /// midpoint moves along and is not a useful snap target.
  bool _segmentTouches(
    SegmentRef ref,
    EditablePath path,
    Set<NodeRef> exclude,
  ) {
    if (exclude.isEmpty) return false;
    final subpath = path.subpaths[ref.subpath];
    return exclude.contains(NodeRef(ref.subpath, ref.index)) ||
        exclude.contains(
          NodeRef(ref.subpath, subpath.endNodeIndex(ref.index)),
        );
  }
}
