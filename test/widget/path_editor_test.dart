import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  group('PathEditor widget tests', () {
    testWidgets('renders simple path golden', (tester) async {
      final controller = PathEditorController('M10 10L20 20');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: PathEditor(
                controller: controller,
                strokeColor: Colors.black,
                pathStrokeWidth: 2,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/path_editor_simple.png'),
      );
    });

    testWidgets('renders cubic path golden', (tester) async {
      final controller = PathEditorController('M10 10C20 55 30 35 40 40');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: PathEditor(
                controller: controller,
                strokeColor: Colors.black,
                pathStrokeWidth: 2,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/path_editor_cubic.png'),
      );
    });

    testWidgets('renders with selected point golden', (tester) async {
      final controller = PathEditorController('M10 10L20 20');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: PathEditor(
                controller: controller,
                strokeColor: Colors.black,
                pathStrokeWidth: 2,
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/path_editor_selected_point.png'),
      );
    });

    testWidgets('renders with segment highlight golden', (tester) async {
      final controller = PathEditorController('M10 10L20 20');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: PathEditor(
                controller: controller,
                strokeColor: Colors.black,
                pathStrokeWidth: 2,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(15, 15));
      await tester.pump();

      await expectLater(
        find.byType(PathEditor),
        matchesGoldenFile('goldens/path_editor_segment_highlight.png'),
      );
    });
  });
}
