import 'package:flutter/material.dart';
import 'package:path_editor/src/model/path_operators.dart';

class PathPainter extends CustomPainter {
  final List<PathOperator> _operations;

  const PathPainter({
    required List<PathOperator> operators,
  }) : _operations = operators;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(1, 1);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // TODO

  Path _buildPath(double scaleX, double scaleY) {
    final path = Path();

    for (final operator in _operations) {
      operator.map(
        moveTo: (op) => path.moveTo(op.x * scaleX, op.y * scaleY),
        lineTo: (op) => path.lineTo(op.x * scaleX, op.y * scaleY),
        cubicTo: (op) => path.cubicTo(
          op.x1 * scaleX,
          op.y1 * scaleY,
          op.x2 * scaleX,
          op.y2 * scaleY,
          op.x3 * scaleX,
          op.y3 * scaleY,
        ),
        close: (_) => path.close(),
      );
    }

    return path;
  }
}
