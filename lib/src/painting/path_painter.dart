import 'package:flutter/material.dart';
import 'package:path_editor/src/model/path_operators.dart';

class PathPainter extends CustomPainter {
  final List<PathOperator> _operations;
  final Color _strokeColor;
  final double _strokeWidth;
  final BlendMode _blendMode;

  PathPainter({
    required List<PathOperator> operators,
    required Color strokeColor,
    required double strokeWidth,
    required BlendMode blendMode,
  })  : _operations = operators,
        _strokeColor = strokeColor,
        _strokeWidth = strokeWidth,
        _blendMode = blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath();

    canvas.drawPath(
      path,
      Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..blendMode = _blendMode
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) =>
      !_operations.deepEquals(oldDelegate._operations);

  Path _buildPath() {
    final path = Path();

    for (final op in _operations) {
      op.map(
        moveTo: (op) => path.moveTo(op.x, op.y),
        lineTo: (op) => path.lineTo(op.x, op.y),
        cubicTo: (op) => path.cubicTo(
          op.x1,
          op.y1,
          op.x2,
          op.y2,
          op.x3,
          op.y3,
        ),
        close: (_) => path.close(),
      );
    }

    return path;
  }
}
