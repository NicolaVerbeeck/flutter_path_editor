import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';

class PathEditorController extends ValueNotifier<String> {
  final List<PathOperator> _operators;

  PathEditorController(super.path) : _operators = PathOperator.parse(path);

  String get path => _operators.map((e) => e.toSvg()).join('');

  List<PathOperator> get operators => _operators;

  void updatePath(String path) {
    _operators.clear();
    _operators.addAll(PathOperator.parse(path));
  }

  void insertPoint(PathSegmentIndex index, Offset point) {
    assert(index.value >= 0 && index.value <= _operators.length);
    _operators.insert(index.value + 1, LineTo(x: point.dx, y: point.dy));

    value = path;
  }

  void updatePointPosition(PathPointIndex index, Offset point) {
    final oldPoint = _operators[index.value];

    switch (oldPoint) {
      case MoveTo():
        operators[index.value] = MoveTo(x: point.dx, y: point.dy);
      case LineTo():
        operators[index.value] = LineTo(x: point.dx, y: point.dy);
      case CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2):
        operators[index.value] =
            CubicTo(x1: x1, y1: y1, x2: x2, y2: y2, x3: point.dx, y3: point.dy);
      case Close():
      // Do nothing for close operator
    }
    value = path;
  }

  void updateControlPointPosition(
    ControlPointIndex controlPointIndex,
    PathPointIndex selectedPoint,
    Offset point,
  ) {
    final updatingPoint = _operators[selectedPoint.value];
    assert(updatingPoint is CubicTo);

    updatingPoint as CubicTo;
    final index = controlPointIndex.value;

    _operators[selectedPoint.value] = CubicTo(
      x1: index == 0 ? point.dx : updatingPoint.x1,
      y1: index == 0 ? point.dy : updatingPoint.y1,
      x2: index == 1 ? point.dx : updatingPoint.x2,
      y2: index == 1 ? point.dy : updatingPoint.y2,
      x3: updatingPoint.x3,
      y3: updatingPoint.y3,
    );
    value = path;
  }

  List<Offset> controlPointsAt(PathPointIndex index) {
    final pt = _operators[index.value];
    return switch (pt) {
      CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2) => [
          Offset(x1, y1),
          Offset(x2, y2),
        ],
      _ => [],
    };
  }

  PathSegmentIndex? findClosestSegment(Offset point) {
    if (_operators.length < 2) return null;

    double minDistance = double.infinity;
    int? closestIndex;
    Offset current = Offset.zero;

    for (var i = 0; i < _operators.length - 1; ++i) {
      final start = _getCommandEndpoint(_operators[i], current);
      final end = _getCommandEndpoint(_operators[i + 1], start);

      final distance = switch (_operators[i + 1]) {
        CubicTo() => _distanceToCubicSegment(
            point,
            start,
            _operators[i + 1] as CubicTo,
          ),
        _ => _distanceToLineSegment(point, start, end),
      };

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }

      current = end;
    }

    return closestIndex == null ? null : PathSegmentIndex(closestIndex);
  }

  Offset? calculateIndicatorPosition(
    Offset cursorPosition,
    PathSegmentIndex? segmentIndex,
  ) {
    final index = segmentIndex?.value;
    if (index == null || index + 1 >= _operators.length) {
      return null;
    }

    final start = _getCommandEndpoint(_operators[index], Offset.zero);
    final nextOp = _operators[index + 1];

    return nextOp.map(
      moveTo: (_) =>
          cursorPosition, // Not applicable, just return cursor position
      lineTo: (l) {
        final end = Offset(l.x, l.y);
        final vecAB = end - start;
        final vecAP = cursorPosition - start;
        final t =
            (vecAP.dx * vecAB.dx + vecAP.dy * vecAB.dy) / vecAB.distanceSquared;

        if (t < 0) return start;
        if (t > 1) return end;

        return start + vecAB * t;
      },
      cubicTo: (c) {
        final p0 = start;
        final p1 = Offset(c.x1, c.y1);
        final p2 = Offset(c.x2, c.y2);
        final p3 = Offset(c.x3, c.y3);

        // Find the closest point on the cubic Bezier curve
        double minDistance = double.infinity;
        Offset closestPoint = p0;
        for (double t = 0; t <= 1; t += 0.01) {
          final point = _cubicBezier(p0, p1, p2, p3, t);
          final distance = (point - cursorPosition).distanceSquared;
          if (distance < minDistance) {
            minDistance = distance;
            closestPoint = point;
          }
        }
        return closestPoint;
      },
      close: (_) => null, // Not applicable
    );
  }

  static Offset _cubicBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    var p = p0 * uuu; // u^3 * p0
    p += p1 * 3 * uu * t; // 3 * u^2 * t * p1
    p += p2 * 3 * u * tt; // 3 * u * t^2 * p2
    p += p3 * ttt; // t^3 * p3

    return p;
  }

  static double _distanceToLineSegment(Offset p, Offset a, Offset b) {
    final vecAB = b - a;
    final vecAP = p - a;
    final t =
        (vecAP.dx * vecAB.dx + vecAP.dy * vecAB.dy) / vecAB.distanceSquared;

    if (t < 0) return (p - a).distance;
    if (t > 1) return (p - b).distance;

    final projection = a + vecAB * t;
    return (p - projection).distance;
  }

  static double _distanceToCubicSegment(
    Offset point,
    Offset start,
    CubicTo cubic,
  ) {
    final p0 = start;
    final p1 = Offset(cubic.x1, cubic.y1);
    final p2 = Offset(cubic.x2, cubic.y2);
    final p3 = Offset(cubic.x3, cubic.y3);

    // Use adaptive subdivision for better performance
    return _adaptiveDistanceToCubic(point, p0, p1, p2, p3, 0, 1);
  }

  static double _adaptiveDistanceToCubic(
    Offset point,
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double tStart,
    double tEnd, [
    int depth = 0,
  ]) {
    // Check if curve is flat enough using control points
    final flatness = _getCurveFlatness(p0, p1, p2, p3);
    if (flatness < 0.5 || depth > 8) {
      // Use line segment approximation for flat curves
      return _distanceToLineSegment(point, p0, p3);
    }

    // Split curve in half
    final mid = (tStart + tEnd) / 2;

    // Get control points for both halves
    final (left, right) = _splitCubicBezier(p0, p1, p2, p3);

    // Recursively find minimum distance in each half
    final d1 = _adaptiveDistanceToCubic(
      point,
      left.$1,
      left.$2,
      left.$3,
      left.$4,
      tStart,
      mid,
      depth + 1,
    );
    final d2 = _adaptiveDistanceToCubic(
      point,
      right.$1,
      right.$2,
      right.$3,
      right.$4,
      mid,
      tEnd,
      depth + 1,
    );

    return min(d1, d2);
  }

  static double _getCurveFlatness(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
  ) {
    final ux = 3 * p1.dx - 2 * p0.dx - p3.dx;
    final uy = 3 * p1.dy - 2 * p0.dy - p3.dy;
    final vx = 3 * p2.dx - 2 * p3.dx - p0.dx;
    final vy = 3 * p2.dy - 2 * p3.dy - p0.dy;

    return max(ux * ux + uy * uy, vx * vx + vy * vy);
  }

  static ((Offset, Offset, Offset, Offset), (Offset, Offset, Offset, Offset))
      _splitCubicBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
  ) {
    final p01 = (p0 + p1) / 2;
    final p12 = (p1 + p2) / 2;
    final p23 = (p2 + p3) / 2;
    final p012 = (p01 + p12) / 2;
    final p123 = (p12 + p23) / 2;
    final p0123 = (p012 + p123) / 2;

    return (
      (p0, p01, p012, p0123),
      (p0123, p123, p23, p3),
    );
  }

  static Offset _getCommandEndpoint(PathOperator command, Offset current) {
    return command.map(
      moveTo: (m) => Offset(m.x, m.y),
      lineTo: (l) => Offset(l.x, l.y),
      cubicTo: (c) => Offset(c.x3, c.y3),
      close: (_) => current,
    );
  }
}
