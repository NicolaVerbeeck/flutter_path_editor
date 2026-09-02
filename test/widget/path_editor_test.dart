import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

Widget wrap(Widget child, {Size size = const Size(200, 200)}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  group('rendering', () {
    testWidgets('draws a straight path', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L180 100L100 180');

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/path.png'),
      );
    });

    testWidgets('draws selected nodes with their handles', (tester) async {
      final controller = PathEditorController.fromSvg(
        'M20 100C20 20 180 20 180 100C180 150 100 180 100 180',
      );
      controller.select([const NodeRef(0, 1)]);

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/selected_node_with_handles.png'),
      );
    });

    testWidgets('draws corner and smooth nodes differently', (tester) async {
      final controller = PathEditorController.fromSvg(
        'M20 100C20 40 80 40 100 100C120 160 180 160 180 100',
      );

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/node_types.png'),
      );
    });

    testWidgets('draws the insert indicator when hovering a segment',
        (tester) async {
      final controller = PathEditorController.fromSvg(
        'M20 100L180 100',
        tool: PathTool.pen,
      );

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(PathEditor)));
      await tester.pump();

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/insert_indicator.png'),
      );
    });

    testWidgets('honours a custom theme', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L180 180');
      controller.select([const NodeRef(0, 0)]);

      await tester.pumpWidget(
        wrap(
          PathEditor(
            controller: controller,
            theme: const PathEditorThemeData(
              strokeColor: Color(0xFFCC0000),
              strokeWidth: 3,
              cornerNodeStyle: PathNodeStyle(
                shape: PathNodeShape.diamond,
                radius: 6,
                fillColor: Color(0xFFFFCC00),
                borderColor: Color(0xFF663300),
                borderWidth: 2,
              ),
              selectedNodeStyle: PathNodeStyle(
                shape: PathNodeShape.diamond,
                radius: 8,
                fillColor: Color(0xFF00AA55),
                borderColor: Color(0xFF003311),
                borderWidth: 2,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/custom_theme.png'),
      );
    });

    testWidgets('scales the path but not the chrome with the viewport',
        (tester) async {
      final controller = PathEditorController.fromSvg('M10 10L50 50L90 10');
      controller.select([const NodeRef(0, 1)]);

      await tester.pumpWidget(
        wrap(
          PathEditor(
            controller: controller,
            viewport: const PathEditorViewport(
              offset: Offset(10, 20),
              scale: 2,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/zoomed.png'),
      );
    });
  });

  group('theme inheritance', () {
    testWidgets('picks up an enclosing PathEditorTheme', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L180 180');

      await tester.pumpWidget(
        wrap(
          PathEditorTheme(
            data: PathEditorThemeData.dark,
            child: PathEditor(controller: controller),
          ),
        ),
      );

      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(PathEditor),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as PathEditorPainter;

      expect(painter.theme, PathEditorThemeData.dark);
    });

    testWidgets('an explicit theme wins over the inherited one',
        (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L180 180');
      const explicit = PathEditorThemeData(strokeColor: Color(0xFF00FF00));

      await tester.pumpWidget(
        wrap(
          PathEditorTheme(
            data: PathEditorThemeData.dark,
            child: PathEditor(controller: controller, theme: explicit),
          ),
        ),
      );

      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(PathEditor),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as PathEditorPainter;

      expect(painter.theme, explicit);
    });
  });

  group('pointer interaction', () {
    testWidgets('the pen tool draws a path by clicking', (tester) async {
      final controller = PathEditorController.empty();
      final segments = <SegmentRef>[];

      await tester.pumpWidget(
        wrap(
          PathEditor(
            controller: controller,
            onSegmentCreated: segments.add,
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(20, 20));
      await tester.pump();
      await tester.tapAt(origin + const Offset(120, 20));
      await tester.pump();

      expect(controller.svg, 'M20.0 20.0L120.0 20.0');
      expect(segments, [const SegmentRef(0, 0)]);
    });

    testWidgets('the pen tool drags out handles', (tester) async {
      final controller = PathEditorController.empty();

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(20, 20));
      await tester.pump();
      await tester.dragFrom(
        origin + const Offset(120, 20),
        const Offset(40, 0),
      );
      await tester.pump();

      expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.mirrored);
      expect(controller.svg, contains('C'));
    });

    testWidgets('dragging a node moves it', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L120 20');

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.dragFrom(
        origin + const Offset(120, 20),
        const Offset(0, 60),
      );
      await tester.pump();

      expect(controller.svg, 'M20.0 20.0L120.0 80.0');
    });

    testWidgets('reports path and selection changes', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L120 20');
      var pathChanges = 0;
      var selectionChanges = 0;

      await tester.pumpWidget(
        wrap(
          PathEditor(
            controller: controller,
            onPathChanged: (_) => pathChanges++,
            onSelectionChanged: (_) => selectionChanges++,
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(120, 20));
      await tester.pump();

      expect(selectionChanges, greaterThan(0));
      expect(pathChanges, 0, reason: 'selecting does not change the path');

      await tester.dragFrom(
        origin + const Offset(120, 20),
        const Offset(0, 40),
      );
      await tester.pump();

      expect(pathChanges, greaterThan(0));
    });
  });

  group('keyboard', () {
    testWidgets('delete removes the selected node', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L70 20L120 20');

      await tester.pumpWidget(
        wrap(PathEditor(controller: controller, autofocus: true)),
      );
      await tester.pump();

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(70, 20));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(controller.svg, 'M20.0 20.0L120.0 20.0');
    });

    testWidgets('arrow keys nudge the selection', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L120 20');

      await tester.pumpWidget(
        wrap(PathEditor(controller: controller, autofocus: true)),
      );
      await tester.pump();

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(120, 20));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(controller.svg, 'M20.0 20.0L120.0 21.0');
    });

    testWidgets('escape stops extending the current path', (tester) async {
      final controller = PathEditorController.empty();

      await tester.pumpWidget(
        wrap(PathEditor(controller: controller, autofocus: true)),
      );
      await tester.pump();

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(20, 20));
      await tester.pump();
      expect(controller.selection.pendingSubpath, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller.selection.pendingSubpath, isNull);
    });

    testWidgets('custom shortcuts replace the defaults', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L70 20L120 20');

      await tester.pumpWidget(
        wrap(
          PathEditor(
            controller: controller,
            autofocus: true,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.keyX): DeleteNodesIntent(),
            },
          ),
        ),
      );
      await tester.pump();

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.tapAt(origin + const Offset(70, 20));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(controller.path.nodeCount, 3, reason: 'delete is not mapped');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      expect(controller.svg, 'M20.0 20.0L120.0 20.0');
    });
  });

  group('lifecycle', () {
    testWidgets('swapping the controller keeps the editor working',
        (tester) async {
      final first = PathEditorController.fromSvg('M20 20L120 20');
      final second = PathEditorController.fromSvg('M20 60L120 60');

      await tester.pumpWidget(wrap(PathEditor(controller: first)));
      await tester.pumpWidget(wrap(PathEditor(controller: second)));

      final origin = tester.getTopLeft(find.byType(PathEditor));
      await tester.dragFrom(
        origin + const Offset(120, 60),
        const Offset(0, 40),
      );
      await tester.pump();

      expect(second.svg, 'M20.0 60.0L120.0 100.0');
      expect(first.svg, 'M20.0 20.0L120.0 20.0');
    });

    testWidgets('disposes without errors', (tester) async {
      final controller = PathEditorController.fromSvg('M20 20L120 20');

      await tester.pumpWidget(wrap(PathEditor(controller: controller)));
      await tester.pumpWidget(wrap(const SizedBox()));

      expect(tester.takeException(), isNull);
    });
  });
}
