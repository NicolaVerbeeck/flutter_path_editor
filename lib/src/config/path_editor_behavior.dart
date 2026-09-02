import 'package:flutter/foundation.dart';

/// Tunable interaction parameters of the editor.
///
/// Every distance is expressed in screen pixels and is therefore independent
/// of the zoom level of the viewport.
@immutable
class PathEditorBehavior {
  /// How close the pointer has to be to a node to grab it.
  final double nodeHitRadius;

  /// How close the pointer has to be to a Bézier handle to grab it.
  ///
  /// Handles are usually checked before nodes, so keeping this slightly
  /// smaller than [nodeHitRadius] makes overlapping handles easier to avoid.
  final double handleHitRadius;

  /// How close the pointer has to be to a segment for it to become the hover
  /// target.
  final double segmentHitDistance;

  /// How far the pointer has to travel before a pen click becomes a drag that
  /// pulls out Bézier handles.
  final double smoothPointDragThreshold;

  /// How far the pointer has to travel before a press on a node becomes a
  /// move rather than a click.
  final double dragThreshold;

  /// Whether a node created by the pen tool becomes the active selection.
  final bool selectOnCreate;

  /// Whether clicking empty canvas with the select tool clears the selection.
  final bool clearSelectionOnBackgroundTap;

  /// Whether the pen tool inserts a node when clicking an existing segment.
  final bool insertOnSegmentClick;

  /// Whether the pen tool closes the path when clicking the first node of the
  /// subpath it is extending.
  final bool closeOnFirstNodeClick;

  /// Whether the pen tool may start a second subpath.
  ///
  /// When this is `false`, clicking empty canvas with the pen tool does
  /// nothing once the path already contains a subpath, so the editor can only
  /// ever produce one continuous run of nodes. Editors that must produce a
  /// single path, rather than a shape built out of several subpaths, want this
  /// turned off.
  ///
  /// This does not affect paths that already contain several subpaths; those
  /// keep loading, rendering and editing normally.
  final bool allowMultipleSubpaths;

  /// How far a single nudge moves the selection, in scene units.
  final double nudgeDistance;

  /// How far a nudge moves the selection while the shift key is held.
  final double largeNudgeDistance;

  /// Creates a behavior configuration.
  const PathEditorBehavior({
    this.nodeHitRadius = 9,
    this.handleHitRadius = 8,
    this.segmentHitDistance = 8,
    this.smoothPointDragThreshold = 3,
    this.dragThreshold = 2,
    this.selectOnCreate = true,
    this.clearSelectionOnBackgroundTap = true,
    this.insertOnSegmentClick = true,
    this.closeOnFirstNodeClick = true,
    this.allowMultipleSubpaths = true,
    this.nudgeDistance = 1,
    this.largeNudgeDistance = 10,
  });

  /// The default behavior.
  static const PathEditorBehavior defaults = PathEditorBehavior();

  /// Returns a copy of this configuration with the given properties replaced.
  PathEditorBehavior copyWith({
    double? nodeHitRadius,
    double? handleHitRadius,
    double? segmentHitDistance,
    double? smoothPointDragThreshold,
    double? dragThreshold,
    bool? selectOnCreate,
    bool? clearSelectionOnBackgroundTap,
    bool? insertOnSegmentClick,
    bool? closeOnFirstNodeClick,
    bool? allowMultipleSubpaths,
    double? nudgeDistance,
    double? largeNudgeDistance,
  }) =>
      PathEditorBehavior(
        nodeHitRadius: nodeHitRadius ?? this.nodeHitRadius,
        handleHitRadius: handleHitRadius ?? this.handleHitRadius,
        segmentHitDistance: segmentHitDistance ?? this.segmentHitDistance,
        smoothPointDragThreshold:
            smoothPointDragThreshold ?? this.smoothPointDragThreshold,
        dragThreshold: dragThreshold ?? this.dragThreshold,
        selectOnCreate: selectOnCreate ?? this.selectOnCreate,
        clearSelectionOnBackgroundTap:
            clearSelectionOnBackgroundTap ?? this.clearSelectionOnBackgroundTap,
        insertOnSegmentClick: insertOnSegmentClick ?? this.insertOnSegmentClick,
        closeOnFirstNodeClick:
            closeOnFirstNodeClick ?? this.closeOnFirstNodeClick,
        allowMultipleSubpaths:
            allowMultipleSubpaths ?? this.allowMultipleSubpaths,
        nudgeDistance: nudgeDistance ?? this.nudgeDistance,
        largeNudgeDistance: largeNudgeDistance ?? this.largeNudgeDistance,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorBehavior &&
          nodeHitRadius == other.nodeHitRadius &&
          handleHitRadius == other.handleHitRadius &&
          segmentHitDistance == other.segmentHitDistance &&
          smoothPointDragThreshold == other.smoothPointDragThreshold &&
          dragThreshold == other.dragThreshold &&
          selectOnCreate == other.selectOnCreate &&
          clearSelectionOnBackgroundTap ==
              other.clearSelectionOnBackgroundTap &&
          insertOnSegmentClick == other.insertOnSegmentClick &&
          closeOnFirstNodeClick == other.closeOnFirstNodeClick &&
          allowMultipleSubpaths == other.allowMultipleSubpaths &&
          nudgeDistance == other.nudgeDistance &&
          largeNudgeDistance == other.largeNudgeDistance);

  @override
  int get hashCode => Object.hash(
        nodeHitRadius,
        handleHitRadius,
        segmentHitDistance,
        smoothPointDragThreshold,
        dragThreshold,
        selectOnCreate,
        clearSelectionOnBackgroundTap,
        insertOnSegmentClick,
        closeOnFirstNodeClick,
        allowMultipleSubpaths,
        nudgeDistance,
        largeNudgeDistance,
      );
}
