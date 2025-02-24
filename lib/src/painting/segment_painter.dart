import 'package:flutter/material.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';

class SegmentPainter extends CustomPainter {
  final List<PathOperator> _operators;
  final PathSegmentIndex? _segmentIndex;
  final Offset? _indicatorPosition;
  final Color _highlightColor;
  final BlendMode _blendMode;
  final double _segmentStrokeWidth;
  final double _insertPointRadius;
  final double _insertPointStrokeWidth;
  final Color _insertPointColor;

  SegmentPainter(
    this._operators,
    this._segmentIndex,
    this._indicatorPosition, {
    required Color highlightColor,
    required BlendMode blendMode,
    required double segmentStrokeWidth,
    required double insertPointRadius,
    required double insertPointStrokeWidth,
    required Color insertPointColor,
  })  : _highlightColor = highlightColor,
        _blendMode = blendMode,
        _segmentStrokeWidth = segmentStrokeWidth,
        _insertPointRadius = insertPointRadius,
        _insertPointStrokeWidth = insertPointStrokeWidth,
        _insertPointColor = insertPointColor;

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
      cubicTo: (c) => path.cubicTo(c.x1, c.y1, c.x2, c.y2, c.x, c.y),
      close: (_) => path.close(),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = _highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _segmentStrokeWidth
        ..blendMode = _blendMode,
    );

    if (_indicatorPosition != null) {
      canvas.drawCircle(
        _indicatorPosition,
        _insertPointRadius,
        Paint()
          ..color = _insertPointColor
          ..strokeWidth = _insertPointStrokeWidth
          ..style = PaintingStyle.stroke
          ..blendMode = _blendMode,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentPainter oldDelegate) =>
      !_operators.deepEquals(oldDelegate._operators) ||
      _segmentIndex != oldDelegate._segmentIndex ||
      _indicatorPosition != oldDelegate._indicatorPosition ||
      _highlightColor != oldDelegate._highlightColor ||
      _blendMode != oldDelegate._blendMode ||
      _segmentStrokeWidth != oldDelegate._segmentStrokeWidth ||
      _insertPointRadius != oldDelegate._insertPointRadius ||
      _insertPointStrokeWidth != oldDelegate._insertPointStrokeWidth ||
      _insertPointColor != oldDelegate._insertPointColor;

  Offset _getCommandEndpoint(PathOperator command, Offset current) {
    return command.map(
      moveTo: (m) => Offset(m.x, m.y),
      lineTo: (l) => Offset(l.x, l.y),
      cubicTo: (c) => Offset(c.x, c.y),
      close: (_) => current,
    );
  }
}
