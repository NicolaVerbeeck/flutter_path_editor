import 'package:flutter/material.dart';

class PointsPainter extends CustomPainter {
  final List<Offset> _points;
  final int? _selectedIndex;
  final List<Offset> _controlPoints;

  const PointsPainter({
    required List<Offset> points,
    required int? selectedIndex,
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
    if (_selectedIndex != null) {
      final point = _points[_selectedIndex];
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
