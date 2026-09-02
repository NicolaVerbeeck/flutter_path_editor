import 'dart:math' as math;
import 'dart:ui';

import 'package:path_editor/src/model/path_segment.dart';

/// Fits a single cubic Bézier through [points], anchored at the first and last
/// point and leaving/entering along [startTangent] and [endTangent].
///
/// This is Philip Schneider's curve fitting algorithm (Graphics Gems): a least
/// squares fit against a chord length parameterisation, refined by
/// Newton-Raphson reparameterisation. It is what allows a node to be removed
/// while keeping the surrounding shape almost identical, instead of naively
/// dropping the node and flattening the curve.
///
/// [startTangent] points away from the first sample and [endTangent] points
/// away from the last sample; both are normalised internally. [refinements]
/// controls how many reparameterisation passes are run. Returns the two
/// control points of the fitted curve.
(Offset control1, Offset control2) fitCubic(
  List<Offset> points,
  Offset startTangent,
  Offset endTangent, {
  int maxRefinements = 256,
}) {
  final first = points.first;
  final last = points.last;

  final tangent1 = _normalize(startTangent) ?? _normalize(last - first);
  final tangent2 = _normalize(endTangent) ?? _normalize(first - last);
  // Degenerate input: fall back to a straight line.
  if (tangent1 == null || tangent2 == null) {
    return (
      Offset.lerp(first, last, 1 / 3)!,
      Offset.lerp(first, last, 2 / 3)!,
    );
  }

  var parameters = _chordLengthParameters(points);
  var result = _generateBezier(points, parameters, tangent1, tangent2);

  // Chord length parameterisation only approximates the true parameterisation,
  // which leaves the handles noticeably too short. Alternating between
  // reprojecting the samples and refitting converges on the true solution.
  final tolerance = math.max((last - first).distance, 1) * 1e-7;
  for (var i = 0; i < maxRefinements; ++i) {
    parameters = _reparameterize(
      points,
      parameters,
      first,
      result.$1,
      result.$2,
      last,
    );
    final refined = _generateBezier(points, parameters, tangent1, tangent2);
    final movement =
        (refined.$1 - result.$1).distance + (refined.$2 - result.$2).distance;
    result = refined;
    if (movement < tolerance) break;
  }

  return result;
}

/// Samples [segments] into a point list suitable for [fitCubic].
///
/// Each segment contributes [samplesPerSegment] points; shared endpoints
/// between consecutive segments are emitted only once.
List<Offset> sampleSegments(
  List<PathSegment> segments, {
  int samplesPerSegment = 12,
}) {
  final points = <Offset>[];
  for (var s = 0; s < segments.length; ++s) {
    final segment = segments[s];
    final start = s == 0 ? 0 : 1;
    for (var i = start; i <= samplesPerSegment; ++i) {
      points.add(segment.pointAt(i / samplesPerSegment));
    }
  }
  return points;
}

/// Solves for the two handle lengths that best fit [points] at [parameters].
(Offset, Offset) _generateBezier(
  List<Offset> points,
  List<double> parameters,
  Offset tangent1,
  Offset tangent2,
) {
  final first = points.first;
  final last = points.last;

  var c00 = 0.0;
  var c01 = 0.0;
  var c11 = 0.0;
  var x0 = 0.0;
  var x1 = 0.0;

  for (var i = 0; i < points.length; ++i) {
    final u = parameters[i];
    final a0 = tangent1 * _bernstein1(u);
    final a1 = tangent2 * _bernstein2(u);

    c00 += _dot(a0, a0);
    c01 += _dot(a0, a1);
    c11 += _dot(a1, a1);

    final onChord = first * (_bernstein0(u) + _bernstein1(u)) +
        last * (_bernstein2(u) + _bernstein3(u));
    final delta = points[i] - onChord;

    x0 += _dot(a0, delta);
    x1 += _dot(a1, delta);
  }

  final determinant = c00 * c11 - c01 * c01;
  var alpha1 = 0.0;
  var alpha2 = 0.0;
  if (determinant.abs() > 1e-12) {
    alpha1 = (x0 * c11 - x1 * c01) / determinant;
    alpha2 = (c00 * x1 - c01 * x0) / determinant;
  }

  // Guard against degenerate solutions, using the Wu/Barsky heuristic as the
  // fallback the original algorithm prescribes.
  final chord = (last - first).distance;
  final epsilon = chord * 1e-6;
  if (alpha1 < epsilon || alpha2 < epsilon) {
    final fallback = chord / 3;
    alpha1 = fallback;
    alpha2 = fallback;
  }

  return (first + tangent1 * alpha1, last + tangent2 * alpha2);
}

/// Moves every parameter closer to the true projection of its sample onto the
/// current fit, using a single Newton-Raphson step per sample.
List<double> _reparameterize(
  List<Offset> points,
  List<double> parameters,
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  final result = List<double>.filled(points.length, 0);
  for (var i = 0; i < points.length; ++i) {
    result[i] = _newtonRaphson(p0, p1, p2, p3, points[i], parameters[i]);
  }
  return result;
}

double _newtonRaphson(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  Offset point,
  double start,
) {
  // Control points of the first and second derivative curves.
  final d0 = (p1 - p0) * 3;
  final d1 = (p2 - p1) * 3;
  final d2 = (p3 - p2) * 3;
  final dd0 = (d1 - d0) * 2;
  final dd1 = (d2 - d1) * 2;

  var u = start;
  // Newton converges quadratically once it is close, so a handful of steps
  // fully projects the sample onto the current fit.
  for (var i = 0; i < 8; ++i) {
    final onCurve = _cubic(p0, p1, p2, p3, u);
    final firstDerivative = _quadratic(d0, d1, d2, u);
    final secondDerivative = Offset.lerp(dd0, dd1, u)!;

    final difference = onCurve - point;
    final numerator = _dot(difference, firstDerivative);
    final denominator = _dot(firstDerivative, firstDerivative) +
        _dot(difference, secondDerivative);
    if (denominator.abs() < 1e-12) return u;

    final next = (u - numerator / denominator).clamp(0.0, 1.0);
    if ((next - u).abs() < 1e-12) return next;
    u = next;
  }
  return u;
}

Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
  final v = 1 - u;
  return p0 * (v * v * v) +
      p1 * (3 * v * v * u) +
      p2 * (3 * v * u * u) +
      p3 * (u * u * u);
}

Offset _quadratic(Offset p0, Offset p1, Offset p2, double u) {
  final v = 1 - u;
  return p0 * (v * v) + p1 * (2 * v * u) + p2 * (u * u);
}

List<double> _chordLengthParameters(List<Offset> points) {
  final parameters = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; ++i) {
    parameters[i] = parameters[i - 1] + (points[i] - points[i - 1]).distance;
  }

  final total = parameters.last;
  if (total == 0) {
    // All samples coincide; spread them evenly to keep the solver stable.
    for (var i = 0; i < points.length; ++i) {
      parameters[i] = i / math.max(1, points.length - 1);
    }
    return parameters;
  }

  for (var i = 1; i < points.length; ++i) {
    parameters[i] /= total;
  }
  return parameters;
}

double _bernstein0(double u) => (1 - u) * (1 - u) * (1 - u);

double _bernstein1(double u) => 3 * u * (1 - u) * (1 - u);

double _bernstein2(double u) => 3 * u * u * (1 - u);

double _bernstein3(double u) => u * u * u;

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

Offset? _normalize(Offset vector) {
  final length = vector.distance;
  if (length == 0 || !length.isFinite) return null;
  return vector / length;
}
