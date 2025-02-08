import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_editor/src/model/path_operators.dart';
import 'package:path_editor/src/painting/path_painter.dart';
import 'package:path_editor/src/painting/points_painter.dart';
import 'package:path_editor/src/painting/segment_painter.dart';

class PathEditor extends StatefulWidget {
  final String path;

  const PathEditor({super.key, required this.path});

  @override
  State<PathEditor> createState() => _PathEditorState();
}

class _OffsetPointHolder {
  final Offset offset;
  final PathOperator source;

  _OffsetPointHolder(this.offset, this.source);
}

class _PathEditorState extends State<PathEditor> {
  var _operators = <PathOperator>[];
  var _points = <_OffsetPointHolder>[];
  int? _selectedIndex;
  int? _highlightedSegment;
  Offset? _indicatorPosition;
  var _controlPoints = <Offset>[];

  @override
  void initState() {
    super.initState();
    _operators = PathOperator.parse(widget.path);
    _updatePathPoints();
  }

  @override
  void didUpdateWidget(covariant PathEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    _operators = PathOperator.parse(widget.path);
    _updatePathPoints();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (details) {
        final index = _findClosestSegmentIndex(details.localPosition);
        final indicatorPosition =
            _calculateIndicatorPosition(details.localPosition, index);
        setState(() {
          _highlightedSegment = index;
          _indicatorPosition = indicatorPosition;
        });
      },
      child: GestureDetector(
        onTapDown: (details) => _handleCanvasTap(details.localPosition),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PathPainter(
                  operators: _operators,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SegmentPainter(
                  _operators,
                  _highlightedSegment,
                  _indicatorPosition,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: PointsPainter(
                  points: _points.map((e) => e.offset).toList(),
                  selectedIndex: _selectedIndex,
                  controlPoints: _controlPoints,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updatePathPoints() {
    _points = _operators
        .map(
          (e) => e.map(
              moveTo: (m) => _OffsetPointHolder(Offset(m.x, m.y), m),
              lineTo: (l) => _OffsetPointHolder(Offset(l.x, l.y), l),
              cubicTo: (c) => _OffsetPointHolder(Offset(c.x3, c.y3), c),
              close: (_) => null),
        )
        .nonNulls
        .toList();
    // TODO update _controlPoints
  }

  static const _pointHitRadius = 20.0;

  int? _findNearestIndex(Offset position) {
    final scaledPosition = position;
    for (int i = 0; i < _points.length; i++) {
      if ((scaledPosition - _points[i].offset).distanceSquared <
          _pointHitRadius * _pointHitRadius) {
        return i;
      }
    }
    return null;
  }

  void _handleCanvasTap(Offset localPosition) {
    final point = _findNearestIndex(localPosition);
    List<Offset> controlPoints;
    if (point == null) {
      controlPoints = [];
    } else {
      final pt = _points[point];
      controlPoints = switch (pt.source) {
        CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2) => [
            Offset(x1, y1),
            Offset(x2, y2),
          ],
        _ => [],
      };
    }

    if (point == null) {
      if (_indicatorPosition != null) {
        final segment = _highlightedSegment!;
        final newOperators = [..._operators]..insert(segment + 1,
            LineTo(x: _indicatorPosition!.dx, y: _indicatorPosition!.dy));
        setState(() {
          _operators = newOperators;
          _highlightedSegment = null;
          _indicatorPosition = null;
          _updatePathPoints();
          _selectedIndex = null;
          _controlPoints = [];
        });
        return;
      }
    }

    setState(() {
      _selectedIndex = point;
      _controlPoints = controlPoints;
    });
  }

  int? _findClosestSegmentIndex(Offset toPosition) {
    if (_operators.length < 2) return null;

    double minDistance = double.infinity;
    int? closestIndex;
    Offset current = Offset.zero;

    for (var i = 0; i < _operators.length - 1; ++i) {
      final start = _getCommandEndpoint(_operators[i], current);
      final end = _getCommandEndpoint(_operators[i + 1], start);

      final distance = _distanceToSegment(toPosition, start, end);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  Offset _getCommandEndpoint(PathOperator command, Offset current) {
    return command.map(
      moveTo: (m) => Offset(m.x, m.y),
      lineTo: (l) => Offset(l.x, l.y),
      cubicTo: (c) => Offset(c.x3, c.y3),
      close: (_) => current,
    );
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final vecAB = b - a;
    final vecAP = p - a;
    final t =
        (vecAP.dx * vecAB.dx + vecAP.dy * vecAB.dy) / vecAB.distanceSquared;

    if (t < 0) return sqrt(pow(p.dx - a.dx, 2) + pow(p.dy - a.dy, 2));
    if (t > 1) return sqrt(pow(p.dx - b.dx, 2) + pow(p.dy - b.dy, 2));

    final projection = a + vecAB * t;
    return sqrt(pow(p.dx - projection.dx, 2) + pow(p.dy - projection.dy, 2));
  }

  Offset? _calculateIndicatorPosition(
      Offset cursorPosition, int? segmentIndex) {
    if (segmentIndex == null || segmentIndex + 1 >= _operators.length) {
      return null;
    }

    final start = _getCommandEndpoint(_operators[segmentIndex], Offset.zero);
    final nextOp = _operators[segmentIndex + 1];

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

  Offset _cubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
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
}
