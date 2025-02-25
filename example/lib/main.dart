import 'package:flutter/material.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  const path =
      'M 4 8 L 10 1 L 13 0 L 12 3 L 5 9 C 6 10 6 11 7 10 C 7 11 8 12 7 12 a 1.42 1.42 0 0 1 -1 1 A 5 5 0 0 0 4 10 Q 3.5 9.9 3.5 10.5 T 2 11.8 T 1.2 11 T 2.5 9.5 T 3 9 A 5 5 90 0 0 0 7 A 1.42 1.42 0 0 1 1 6 C 1 5 1.894 5.878 3 6 C 2 7 3 7 4 8 M 10 1 L 10 3 L 12 3 L 10.2 2.8 L 10 1 Z';
  var operators = PathOperator.parse(path);
  operators = operators.scale(30, 30);
  final scaledPath = operators.toSvg();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: App(initialPath: scaledPath),
          ),
        ),
      ),
    ),
  );
}

class App extends StatefulWidget {
  final String initialPath;

  const App({super.key, required this.initialPath});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final PathEditorController controller;
  @override
  void initState() {
    super.initState();

    controller = PathEditorController(widget.initialPath);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background content
        Positioned.fill(
          child: FilledPath(
            controller: controller,
            color: Colors.blue.withAlpha(127),
            blendMode: BlendMode.srcOver,
          ),
        ),
        // Path editor on top
        Positioned.fill(
          child: PathEditor(
            controller: controller,
          ),
        ),
      ],
    );
  }
}

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
