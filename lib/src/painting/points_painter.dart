import 'package:flutter/material.dart';
import 'package:path_editor/src/model/editing.dart';

class PointsPainter extends CustomPainter {
  final List<Offset> _points;
  final PathPointIndex? _selectedIndex;
  final List<Offset> _controlPoints;
  final Color _controlPointColor;
  final Color _selectedPointColor;
  final Color _unselectedPointColor;
  final BlendMode _blendMode;
  final double _controlPointStrokeWidth;
  final double _controlPointRadius;
  final double _selectedPointRadius;
  final double _unselectedPointRadius;

  const PointsPainter({
    required List<Offset> points,
    required PathPointIndex? selectedIndex,
    required List<Offset> controlPoints,
    required Color controlPointColor,
    required Color selectedPointColor,
    required Color unselectedPointColor,
    required BlendMode blendMode,
    required double controlPointStrokeWidth,
    required double controlPointRadius,
    required double selectedPointRadius,
    required double unselectedPointRadius,
  })  : _points = points,
        _selectedIndex = selectedIndex,
        _controlPoints = controlPoints,
        _controlPointColor = controlPointColor,
        _selectedPointColor = selectedPointColor,
        _unselectedPointColor = unselectedPointColor,
        _blendMode = blendMode,
        _controlPointStrokeWidth = controlPointStrokeWidth,
        _controlPointRadius = controlPointRadius,
        _selectedPointRadius = selectedPointRadius,
        _unselectedPointRadius = unselectedPointRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final selectedIndex = _selectedIndex?.value ?? -1;

    // Draw lines to control points first (so they appear behind the points)
    if (selectedIndex >= 0 && _controlPoints.isNotEmpty) {
      // Draw lines from previous point if it exists
      if (selectedIndex > 0 && _controlPoints.isNotEmpty) {
        final prevPoint = _points[selectedIndex - 1];
        final controlPoint = _controlPoints[0];
        final direction = (controlPoint - prevPoint) / (controlPoint - prevPoint).distance;
        final adjustedEnd = controlPoint - direction * _controlPointRadius;

        canvas.drawLine(
          prevPoint,
          adjustedEnd,
          Paint()
            ..color = _controlPointColor.withAlpha(127)
            ..strokeWidth = _controlPointStrokeWidth / 2
            ..blendMode = _blendMode,
        );
      }

      // Draw lines from selected point
      if (_controlPoints.length > 1) {
        final selectedPoint = _points[selectedIndex];
        final controlPoint = _controlPoints[1];
        final direction = (controlPoint - selectedPoint) / (controlPoint - selectedPoint).distance;
        final adjustedEnd = controlPoint - direction * _controlPointRadius;

        canvas.drawLine(
          selectedPoint,
          adjustedEnd,
          Paint()
            ..color = _controlPointColor.withAlpha(127)
            ..strokeWidth = _controlPointStrokeWidth / 2
            ..blendMode = _blendMode,
        );
      }
    }

    for (var index = 0; index < _points.length; ++index) {
      final isSelected = index == selectedIndex;
      if (!isSelected) {
        final point = _points[index];
        canvas.drawCircle(
          point,
          _unselectedPointRadius,
          Paint()
            ..color = _unselectedPointColor
            ..style = PaintingStyle.fill
            ..blendMode = _blendMode,
        );
      }
    }
    if (selectedIndex >= 0) {
      final point = _points[selectedIndex];
      canvas.drawCircle(
        point,
        _selectedPointRadius,
        Paint()
          ..color = _selectedPointColor
          ..style = PaintingStyle.fill
          ..blendMode = _blendMode,
      );
    }
    for (final control in _controlPoints) {
      canvas.drawCircle(
        control,
        _controlPointRadius,
        Paint()
          ..color = _controlPointColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _controlPointStrokeWidth
          ..blendMode = _blendMode,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PointsPainter oldDelegate) =>
      !_deepEquals(_points, oldDelegate._points) ||
      _selectedIndex != oldDelegate._selectedIndex ||
      !_deepEquals(_controlPoints, oldDelegate._controlPoints);
}

bool _deepEquals(List<Offset> a, List<Offset> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
