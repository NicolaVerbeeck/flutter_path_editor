import 'package:flutter/material.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/model/path_operators.dart';

class FilledPath extends StatelessWidget {
  final PathEditorController controller;
  final Color color;
  final BlendMode blendMode;

  const FilledPath({
    super.key,
    required this.controller,
    this.color = Colors.black,
    this.blendMode = BlendMode.srcOver,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller,
      builder: (context, path, _) {
        return CustomPaint(
          painter: _FilledPathPainter(
            operators: controller.operators,
            color: color,
            blendMode: blendMode,
          ),
        );
      },
    );
  }
}

class _FilledPathPainter extends CustomPainter {
  final List<PathOperator> operators;
  final Color color;
  final BlendMode blendMode;

  _FilledPathPainter({
    required this.operators,
    required this.color,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (operators.isEmpty) return;

    final path = Path();
    Offset current = Offset.zero;

    for (final op in operators) {
      op.map(
        moveTo: (m) {
          current = Offset(m.x, m.y);
          path.moveTo(current.dx, current.dy);
        },
        lineTo: (l) {
          current = Offset(l.x, l.y);
          path.lineTo(current.dx, current.dy);
        },
        cubicTo: (c) {
          current = Offset(c.x3, c.y3);
          path.cubicTo(
            c.x1,
            c.y1,
            c.x2,
            c.y2,
            c.x3,
            c.y3,
          );
        },
        close: (_) {
          path.close();
        },
      );
    }

    canvas.save();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..blendMode = blendMode,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FilledPathPainter oldDelegate) {
    return operators != oldDelegate.operators ||
        color != oldDelegate.color ||
        blendMode != oldDelegate.blendMode;
  }
}
