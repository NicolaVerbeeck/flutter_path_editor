import 'dart:ui';

import 'package:flutter/foundation.dart';

/// What a snap candidate was aligned to.
enum SnapKind {
  /// The position was pulled onto another node.
  node,

  /// The position was pulled onto the midpoint of a segment.
  midpoint,

  /// The position was aligned horizontally with another node.
  horizontalAxis,

  /// The position was aligned vertically with another node.
  verticalAxis,

  /// The position was constrained to a fixed angle around its origin.
  angle,
}

/// A visual guide describing why a position was snapped.
@immutable
class SnapGuide {
  /// Where the guide starts, in scene coordinates.
  final Offset start;

  /// Where the guide ends, in scene coordinates.
  final Offset end;

  /// What kind of snap produced this guide.
  final SnapKind kind;

  /// Creates a guide.
  const SnapGuide({
    required this.start,
    required this.end,
    required this.kind,
  });

  /// Whether the guide marks a single point rather than a line.
  bool get isPoint => start == end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapGuide &&
          start == other.start &&
          end == other.end &&
          kind == other.kind);

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'SnapGuide(${kind.name}, $start -> $end)';
}

/// The outcome of snapping a position.
@immutable
class SnapResult {
  /// The snapped position, or the original one when nothing matched.
  final Offset position;

  /// The guides to draw for this snap. Empty when nothing matched.
  final List<SnapGuide> guides;

  /// Creates a snap result.
  const SnapResult({required this.position, this.guides = const []});

  /// A result that leaves [position] untouched.
  const SnapResult.none(this.position) : guides = const [];

  /// Whether anything was snapped.
  bool get didSnap => guides.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapResult &&
          position == other.position &&
          listEquals(guides, other.guides));

  @override
  int get hashCode => Object.hash(position, Object.hashAll(guides));
}

/// Configures the snapping behaviour of the editor.
@immutable
class PathEditorSnapping {
  /// Whether snapping is enabled at all.
  final bool enabled;

  /// Whether positions snap onto other nodes.
  final bool snapToNodes;

  /// Whether positions snap onto segment midpoints.
  final bool snapToMidpoints;

  /// Whether positions align horizontally and vertically with other nodes.
  final bool snapToAxes;

  /// How close, in screen pixels, a candidate has to be to snap.
  final double threshold;

  /// The angle increment, in degrees, used when the constrain-angle modifier
  /// is held.
  final double angleIncrement;

  /// Creates a snapping configuration.
  const PathEditorSnapping({
    this.enabled = true,
    this.snapToNodes = true,
    this.snapToMidpoints = true,
    this.snapToAxes = true,
    this.threshold = 6,
    this.angleIncrement = 15,
  });

  /// The default configuration.
  static const PathEditorSnapping defaults = PathEditorSnapping();

  /// A configuration with snapping switched off.
  static const PathEditorSnapping disabled = PathEditorSnapping(enabled: false);

  /// Returns a copy of this configuration with the given properties replaced.
  PathEditorSnapping copyWith({
    bool? enabled,
    bool? snapToNodes,
    bool? snapToMidpoints,
    bool? snapToAxes,
    double? threshold,
    double? angleIncrement,
  }) =>
      PathEditorSnapping(
        enabled: enabled ?? this.enabled,
        snapToNodes: snapToNodes ?? this.snapToNodes,
        snapToMidpoints: snapToMidpoints ?? this.snapToMidpoints,
        snapToAxes: snapToAxes ?? this.snapToAxes,
        threshold: threshold ?? this.threshold,
        angleIncrement: angleIncrement ?? this.angleIncrement,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorSnapping &&
          enabled == other.enabled &&
          snapToNodes == other.snapToNodes &&
          snapToMidpoints == other.snapToMidpoints &&
          snapToAxes == other.snapToAxes &&
          threshold == other.threshold &&
          angleIncrement == other.angleIncrement);

  @override
  int get hashCode => Object.hash(
        enabled,
        snapToNodes,
        snapToMidpoints,
        snapToAxes,
        threshold,
        angleIncrement,
      );
}
