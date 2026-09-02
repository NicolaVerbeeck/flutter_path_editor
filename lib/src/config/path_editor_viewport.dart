import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The viewport the editor renders and hit tests through.
///
/// The path lives in "scene" coordinates. The viewport maps those onto the
/// widget's local "screen" coordinates, which lets the editor sit inside a
/// pannable, zoomable canvas while keeping nodes, handles and hit areas a
/// constant size on screen.
@immutable
class PathEditorViewport {
  /// The translation applied to the path, in screen pixels.
  final Offset offset;

  /// The zoom factor applied to the path.
  final double scale;

  /// Creates a viewport.
  const PathEditorViewport({
    this.offset = Offset.zero,
    this.scale = 1.0,
  }) : assert(scale > 0, 'scale must be greater than zero');

  /// A viewport that neither pans nor zooms.
  static const PathEditorViewport identity = PathEditorViewport();

  /// Converts a point in screen space to scene space.
  Offset toScene(Offset screenPoint) => (screenPoint - offset) / scale;

  /// Converts a point in scene space to screen space.
  Offset toScreen(Offset scenePoint) => scenePoint * scale + offset;

  /// Converts a distance in screen pixels to scene units.
  ///
  /// Use this for hit radii so that grabbing a node stays equally easy at any
  /// zoom level.
  double toSceneDistance(double screenDistance) => screenDistance / scale;

  /// Converts a distance in scene units to screen pixels.
  double toScreenDistance(double sceneDistance) => sceneDistance * scale;

  /// Applies this viewport to [canvas].
  ///
  /// Callers are responsible for saving and restoring the canvas state.
  void applyTo(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    if (scale != 1.0) canvas.scale(scale);
  }

  /// Returns a copy of this viewport with the given properties replaced.
  PathEditorViewport copyWith({Offset? offset, double? scale}) =>
      PathEditorViewport(
        offset: offset ?? this.offset,
        scale: scale ?? this.scale,
      );

  /// Returns a copy of this viewport panned by [delta] screen pixels.
  PathEditorViewport panned(Offset delta) => copyWith(offset: offset + delta);

  /// Returns a copy of this viewport zoomed to [scale] while keeping
  /// [focalPoint], expressed in screen coordinates, visually in place.
  PathEditorViewport zoomedAround(Offset focalPoint, double scale) {
    final scenePoint = toScene(focalPoint);
    return PathEditorViewport(
      offset: focalPoint - scenePoint * scale,
      scale: scale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorViewport &&
          offset == other.offset &&
          scale == other.scale);

  @override
  int get hashCode => Object.hash(offset, scale);

  @override
  String toString() => 'PathEditorViewport(offset: $offset, scale: $scale)';
}
