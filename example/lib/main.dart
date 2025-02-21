import 'package:flutter/material.dart';
import 'package:path_editor/path_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();

    controller = PathEditorController(widget.initialPath);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          // Check if shift key is pressed for horizontal pan
          if (pointerSignal.scrollDelta.dx != 0 ||
              pointerSignal.scrollDelta.dy != 0) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              // Pan horizontally
              final delta = pointerSignal.scrollDelta.dy;
              final matrix = Matrix4.identity()..translate(-delta);
              _transformationController.value =
                  matrix * _transformationController.value;
            } else if (HardwareKeyboard.instance.isControlPressed) {
              // Zoom (existing code)
              final delta = pointerSignal.scrollDelta.dy;
              final scaleChange = delta > 0 ? 0.95 : 1.05;

              final box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(pointerSignal.position);

              final matrix = Matrix4.identity()
                ..translate(localPosition.dx, localPosition.dy)
                ..scale(scaleChange)
                ..translate(-localPosition.dx, -localPosition.dy);

              _transformationController.value =
                  matrix * _transformationController.value;
            } else {
              // Normal panning
              final matrix = Matrix4.identity()
                ..translate(-pointerSignal.scrollDelta.dx,
                    -pointerSignal.scrollDelta.dy);
              _transformationController.value =
                  matrix * _transformationController.value;
            }
          }
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 10.0,
        child: Stack(
          children: [
            // Background content
            Positioned.fill(
              child: FilledPath(
                controller: controller,
                color: Colors.blue.withOpacity(0.5),
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
        ),
      ),
    );
  }
}
