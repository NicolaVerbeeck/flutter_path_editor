import 'package:flutter/material.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';

class SegmentPainter extends CustomPainter {
  final List<PathOperator> _operators;
  final PathSegmentIndex? _segmentIndex;
  final Offset? _indicatorPosition;

  SegmentPainter(
    this._operators,
    this._segmentIndex,
    this._indicatorPosition,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final segmentIndex = _segmentIndex?.value;
    if (segmentIndex == null) {
      return;
    }
    if (segmentIndex + 1 >= _operators.length) {
      return;
    }
    final start = _getCommandEndpoint(_operators[segmentIndex], Offset.zero);
    final path = Path();
    path.moveTo(start.dx, start.dy);
    _operators[segmentIndex + 1].map(
      moveTo: (m) => path.moveTo(m.x, m.y),
      lineTo: (l) => path.lineTo(l.x, l.y),
      cubicTo: (c) => path.cubicTo(c.x1, c.y1, c.x2, c.y2, c.x3, c.y3),
      close: (_) => path.close(),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (_indicatorPosition != null) {
      canvas.drawCircle(
        _indicatorPosition,
        5,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentPainter oldDelegate) =>
      !_operators.deepEquals(oldDelegate._operators) ||
      _segmentIndex != oldDelegate._segmentIndex ||
      _indicatorPosition != oldDelegate._indicatorPosition;

  Offset _getCommandEndpoint(PathOperator command, Offset current) {
    return command.map(
      moveTo: (m) => Offset(m.x, m.y),
      lineTo: (l) => Offset(l.x, l.y),
      cubicTo: (c) => Offset(c.x3, c.y3),
      close: (_) => current,
    );
  }
}
