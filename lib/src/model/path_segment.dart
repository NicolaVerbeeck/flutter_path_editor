import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The result of projecting a point onto a [PathSegment].
@immutable
class SegmentProjection {
  /// The parametric position along the segment, in the range `[0, 1]`.
  final double t;

  /// The point on the segment closest to the projected point.
  final Offset point;

  /// The distance between the projected point and [point].
  final double distance;

  /// Creates a projection result.
  const SegmentProjection({
    required this.t,
    required this.point,
    required this.distance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentProjection &&
          t == other.t &&
          point == other.point &&
          distance == other.distance);

  @override
  int get hashCode => Object.hash(t, point, distance);

  @override
  String toString() =>
      'SegmentProjection(t: $t, point: $point, distance: $distance)';
}

/// A single segment of a path, running from [start] to [end].
///
/// A segment is a straight line when both control points are `null`, and a
/// cubic Bézier curve otherwise. [startControl] is the outgoing handle of the
/// node at [start] and [endControl] is the incoming handle of the node at
/// [end].
@immutable
class PathSegment {
  /// The position the segment starts at.
  final Offset start;

  /// The position the segment ends at.
  final Offset end;

  /// The outgoing handle of the node at [start], if any.
  final Offset? startControl;

  /// The incoming handle of the node at [end], if any.
  final Offset? endControl;

  /// Creates a segment.
  const PathSegment({
    required this.start,
    required this.end,
    this.startControl,
    this.endControl,
  });

  /// Creates a straight segment between [start] and [end].
  const PathSegment.line({required Offset start, required Offset end})
      : this(start: start, end: end);

  /// Whether this segment is curved.
  bool get isCurve => startControl != null || endControl != null;

  /// The first cubic control point, falling back to [start] for straight
  /// segments.
  Offset get control1 => startControl ?? start;

  /// The second cubic control point, falling back to [end] for straight
  /// segments.
  Offset get control2 => endControl ?? end;

  /// The point halfway along the segment.
  Offset get midpoint => pointAt(0.5);

  /// The point at parametric position [t], which is clamped to `[0, 1]`.
  Offset pointAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if (!isCurve) return Offset.lerp(start, end, clamped)!;

    final u = 1 - clamped;
    final uu = u * u;
    final tt = clamped * clamped;
    return start * (uu * u) +
        control1 * (3 * uu * clamped) +
        control2 * (3 * u * tt) +
        end * (tt * clamped);
  }

  /// The (unnormalised) tangent of the segment at parametric position [t].
  Offset tangentAt(double t) {
    if (!isCurve) return end - start;

    final clamped = t.clamp(0.0, 1.0);
    final u = 1 - clamped;
    final tangent = (control1 - start) * (3 * u * u) +
        (control2 - control1) * (6 * u * clamped) +
        (end - control2) * (3 * clamped * clamped);
    if (tangent.distanceSquared > 0) return tangent;

    // Degenerate control points; fall back to the chord.
    return end - start;
  }

  /// Projects [point] onto this segment.
  SegmentProjection project(Offset point) {
    if (!isCurve) {
      final chord = end - start;
      final lengthSquared = chord.distanceSquared;
      if (lengthSquared == 0) {
        return SegmentProjection(
          t: 0,
          point: start,
          distance: (point - start).distance,
        );
      }
      final delta = point - start;
      final t = ((delta.dx * chord.dx + delta.dy * chord.dy) / lengthSquared)
          .clamp(0.0, 1.0);
      final projected = start + chord * t;
      return SegmentProjection(
        t: t,
        point: projected,
        distance: (point - projected).distance,
      );
    }

    // Coarse sampling to find the neighbourhood of the closest point, followed
    // by a ternary search refinement inside that neighbourhood.
    const samples = 24;
    var bestT = 0.0;
    var bestDistanceSquared = double.infinity;
    for (var i = 0; i <= samples; ++i) {
      final t = i / samples;
      final distanceSquared = (pointAt(t) - point).distanceSquared;
      if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestT = t;
      }
    }

    var low = math.max(0.0, bestT - 1 / samples);
    var high = math.min(1.0, bestT + 1 / samples);
    for (var i = 0; i < 64 && high - low > 1e-9; ++i) {
      final third = (high - low) / 3;
      final leftT = low + third;
      final rightT = high - third;
      if ((pointAt(leftT) - point).distanceSquared <
          (pointAt(rightT) - point).distanceSquared) {
        high = rightT;
      } else {
        low = leftT;
      }
    }

    final t = (low + high) / 2;
    final projected = pointAt(t);
    return SegmentProjection(
      t: t,
      point: projected,
      distance: (point - projected).distance,
    );
  }

  /// The distance between [point] and the closest point on this segment.
  double distanceTo(Offset point) => project(point).distance;

  /// Splits this segment at parametric position [t] using de Casteljau's
  /// algorithm, so that the two returned segments together describe exactly
  /// the same geometry as this segment.
  (PathSegment, PathSegment) splitAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if (!isCurve) {
      final split = Offset.lerp(start, end, clamped)!;
      return (
        PathSegment.line(start: start, end: split),
        PathSegment.line(start: split, end: end),
      );
    }

    final p0 = start;
    final p1 = control1;
    final p2 = control2;
    final p3 = end;

    final p01 = Offset.lerp(p0, p1, clamped)!;
    final p12 = Offset.lerp(p1, p2, clamped)!;
    final p23 = Offset.lerp(p2, p3, clamped)!;
    final p012 = Offset.lerp(p01, p12, clamped)!;
    final p123 = Offset.lerp(p12, p23, clamped)!;
    final split = Offset.lerp(p012, p123, clamped)!;

    return (
      PathSegment(
        start: p0,
        startControl: p01,
        endControl: p012,
        end: split,
      ),
      PathSegment(
        start: split,
        startControl: p123,
        endControl: p23,
        end: p3,
      ),
    );
  }

  /// The exact bounding box of this segment.
  Rect get bounds {
    if (!isCurve) {
      return Rect.fromLTRB(
        math.min(start.dx, end.dx),
        math.min(start.dy, end.dy),
        math.max(start.dx, end.dx),
        math.max(start.dy, end.dy),
      );
    }

    var minX = math.min(start.dx, end.dx);
    var maxX = math.max(start.dx, end.dx);
    var minY = math.min(start.dy, end.dy);
    var maxY = math.max(start.dy, end.dy);

    for (final t in _extrema(start.dx, control1.dx, control2.dx, end.dx)) {
      final x = pointAt(t).dx;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
    }
    for (final t in _extrema(start.dy, control1.dy, control2.dy, end.dy)) {
      final y = pointAt(t).dy;
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Appends this segment to [path], assuming the current point of [path] is
  /// already at [start].
  void addTo(Path path) {
    if (isCurve) {
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    } else {
      path.lineTo(end.dx, end.dy);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathSegment &&
          start == other.start &&
          end == other.end &&
          startControl == other.startControl &&
          endControl == other.endControl);

  @override
  int get hashCode => Object.hash(start, end, startControl, endControl);

  @override
  String toString() => isCurve
      ? 'PathSegment.curve($start, $control1, $control2, $end)'
      : 'PathSegment.line($start, $end)';
}

/// The parametric positions where a cubic polynomial reaches a local extremum,
/// limited to the `(0, 1)` interval.
Iterable<double> _extrema(double p0, double p1, double p2, double p3) sync* {
  // Derivative of the cubic: at^2 + bt + c
  final a = 3 * (-p0 + 3 * p1 - 3 * p2 + p3);
  final b = 6 * (p0 - 2 * p1 + p2);
  final c = 3 * (p1 - p0);

  if (a.abs() < 1e-12) {
    if (b.abs() >= 1e-12) {
      final t = -c / b;
      if (t > 0 && t < 1) yield t;
    }
    return;
  }

  final discriminant = b * b - 4 * a * c;
  if (discriminant < 0) return;

  final root = math.sqrt(discriminant);
  for (final t in [(-b + root) / (2 * a), (-b - root) / (2 * a)]) {
    if (t > 0 && t < 1) yield t;
  }
}
