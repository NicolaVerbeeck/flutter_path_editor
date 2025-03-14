import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_editor/path_editor.dart';

bool get isMacOS {
  if (kIsWeb) {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.macOS;
  }
  return Platform.isMacOS;
}

void main() {
  const path =
      'M 4 8 L 10 1 L 13 0 L 12 3 L 5 9 C 6 10 6 11 7 10 C 7 11 8 12 7 12 a 1.42 1.42 0 0 1 -1 1 A 5 5 0 0 0 4 10 Q 3.5 9.9 3.5 10.5 T 2 11.8 T 1.2 11 T 2.5 9.5 T 3 9 A 5 5 90 0 0 0 7 A 1.42 1.42 0 0 1 1 6 C 1 5 1.894 5.878 3 6 C 2 7 3 7 4 8 M 10 1 L 10 3 L 12 3 L 10.2 2.8 L 10 1 Z';
  var operators = PathOperator.parse(path);
  operators = operators.scale(30, 30);
  final scaledPath = operators.toSvg();

  final initialSize =
      PathEditorController.calculateBoundingBoxOfPath(operators, 2.0);

  runApp(
    MaterialApp(
      home: Scaffold(
        body: App(initialPath: scaledPath, initialSize: initialSize),
      ),
    ),
  );
}

class App extends StatefulWidget {
  final String initialPath;
  final Rect initialSize;

  const App({
    super.key,
    required this.initialPath,
    required this.initialSize,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final PathEditorController controller;

  bool showBounds = true;

  @override
  void initState() {
    super.initState();
    controller = PathEditorController(widget.initialPath);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add toolbar with bounds toggle and undo/redo
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Show Bounds'),
                value: showBounds,
                onChanged: (value) =>
                    setState(() => showBounds = value ?? false),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, _, __) => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: controller.canUndo ? controller.undo : null,
                    tooltip: 'Undo (Ctrl+Z)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: controller.canRedo ? controller.redo : null,
                    tooltip: 'Redo (Ctrl+Shift+Z)',
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: isMacOS,
                control: !isMacOS,
              ): controller.undo,
              SingleActivator(
                LogicalKeyboardKey.keyZ,
                shift: true,
                meta: isMacOS,
                control: !isMacOS,
              ): controller.redo,
            },
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(builder: (contex, constraints) {
                // Calculate offset to the center of the screen
                final renderOffset = Offset(
                  constraints.maxWidth / 2 - widget.initialSize.width / 2,
                  constraints.maxHeight / 2 - widget.initialSize.height / 2,
                );
                return Stack(
                  children: [
                    // Background content
                    Positioned.fill(
                      child: FilledPath(
                        controller: controller,
                        color: Colors.blue.withAlpha(127),
                        blendMode: BlendMode.srcOver,
                        renderOffset: renderOffset,
                      ),
                    ),

                    // Bounds visualization
                    if (showBounds)
                      Positioned.fill(
                        child: ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, _, __) {
                            return CustomPaint(
                              painter: _BoundsPainter(
                                bounds: controller.calculateBoundingBox(2.0),
                                offset: renderOffset,
                              ),
                            );
                          },
                        ),
                      ),

                    // Path editor on top
                    Positioned.fill(
                      child: PathEditor(
                        controller: controller,
                        renderOffset: renderOffset,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoundsPainter extends CustomPainter {
  final Rect bounds;
  final Offset offset;

  _BoundsPainter({
    required this.bounds,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw the bounds rectangle
    canvas.drawRect(bounds, paint);

    // Draw the center point
    canvas.drawCircle(
      bounds.center,
      3,
      paint..style = PaintingStyle.fill,
    );

    // Draw diagonal guides
    canvas.drawLine(
      bounds.topLeft,
      bounds.bottomRight,
      paint..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      bounds.topRight,
      bounds.bottomLeft,
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoundsPainter oldDelegate) {
    return bounds != oldDelegate.bounds || offset != oldDelegate.offset;
  }
}

class FilledPath extends StatelessWidget {
  final PathEditorController controller;
  final Color color;
  final BlendMode blendMode;
  final Offset renderOffset;

  const FilledPath({
    super.key,
    required this.controller,
    this.color = Colors.black,
    this.blendMode = BlendMode.srcOver,
    this.renderOffset = Offset.zero,
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
            offset: renderOffset,
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
  final Offset offset;

  _FilledPathPainter({
    required this.path,
    required this.color,
    required this.blendMode,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

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
    return path != oldDelegate.path ||
        color != oldDelegate.color ||
        blendMode != oldDelegate.blendMode ||
        offset != oldDelegate.offset;
  }
}
