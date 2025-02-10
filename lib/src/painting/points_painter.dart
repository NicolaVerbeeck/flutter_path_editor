import 'package:flutter/material.dart';
import 'package:path_editor/src/model/editing.dart';

class PointsPainter extends CustomPainter {
  final List<Offset> _points;
  final PathPointIndex? _selectedIndex;
  final List<Offset> _controlPoints;

  const PointsPainter({
    required List<Offset> points,
    required PathPointIndex? selectedIndex,
    required List<Offset> controlPoints,
  })  : _points = points,
        _selectedIndex = selectedIndex,
        _controlPoints = controlPoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _points.length; ++index) {
      final isSelected = index == _selectedIndex;
      if (!isSelected) {
        final point = _points[index];
        canvas.drawCircle(
          point,
          5,
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.fill,
        );
      }
    }
    final selectedIndex = _selectedIndex?.value;
    if (selectedIndex != null) {
      final point = _points[selectedIndex];
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.fill,
      );
    }
    for (final control in _controlPoints) {
      canvas.drawCircle(
        control,
        3,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // TODO
}
