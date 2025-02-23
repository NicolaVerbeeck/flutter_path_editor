import 'package:flutter/material.dart';

class PathPainter extends CustomPainter {
  final Path _path;
  final Color _strokeColor;
  final double _strokeWidth;
  final BlendMode _blendMode;

  PathPainter({
    required Path path,
    required Color strokeColor,
    required double strokeWidth,
    required BlendMode blendMode,
  })  : _path = path,
        _strokeColor = strokeColor,
        _strokeWidth = strokeWidth,
        _blendMode = blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _path,
      Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..blendMode = _blendMode
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) =>
      _path != oldDelegate._path;
}
