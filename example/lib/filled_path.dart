import 'package:flutter/material.dart';
import 'package:path_editor/path_editor.dart';

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
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, pathHolder, _) {
        return CustomPaint(
          painter: _FilledPathPainter(
            path: pathHolder.path,
            color: color,
            blendMode: blendMode,
          ),
        );
      },
    );
  }
}

class _FilledPathPainter extends CustomPainter {
  final Path path;
  final Color color;
  final BlendMode blendMode;

  _FilledPathPainter({
    required this.path,
    required this.color,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..blendMode = blendMode,
    );
  }

  @override
  bool shouldRepaint(_FilledPathPainter oldDelegate) {
    return path != oldDelegate.path ||
        color != oldDelegate.color ||
        blendMode != oldDelegate.blendMode;
  }
}
