import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 200, height: 200, child: child),
        ),
      ),
    );

/// Runs [body] as if the app were running on [platform].
///
/// The override has to be cleared before the test body returns, because the
/// test framework asserts that no foundation debug variable is left set.
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Holds [key] down for the duration of [body].
Future<void> holding(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Future<void> Function() body,
) async {
  await tester.sendKeyDownEvent(key);
  try {
    await body();
  } finally {
    await tester.sendKeyUpEvent(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyModifier.controlOrMeta', () {
    testWidgets('resolves to the command key on apple platforms',
        (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        await holding(tester, LogicalKeyboardKey.metaLeft, () async {
          expect(KeyModifier.controlOrMeta.isActive(), isTrue);
          expect(KeyModifier.meta.isActive(), isTrue);
          expect(KeyModifier.control.isActive(), isFalse);
        });

        await holding(tester, LogicalKeyboardKey.controlLeft, () async {
          expect(KeyModifier.controlOrMeta.isActive(), isFalse);
        });
      });
    });

    testWidgets('resolves to the control key elsewhere', (tester) async {
      await onPlatform(TargetPlatform.linux, () async {
        await holding(tester, LogicalKeyboardKey.controlLeft, () async {
          expect(KeyModifier.controlOrMeta.isActive(), isTrue);
        });

        await holding(tester, LogicalKeyboardKey.metaLeft, () async {
          expect(KeyModifier.controlOrMeta.isActive(), isFalse);
        });
      });
    });

    testWidgets('KeyModifier.none is never active', (tester) async {
      await holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        expect(KeyModifier.none.isActive(), isFalse);
        expect(KeyModifier.shift.isActive(), isTrue);
      });
    });
  });

  group('dragging with the command key on macOS', () {
    testWidgets('suppresses snapping while a handle is dragged',
        (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        // Node 1 is a smooth point whose outgoing handle sits at (180, 100).
        final controller = PathEditorController.fromSvg(
          'M40 100C40 100 20 100 100 100C180 100 40 100 160 100',
        );

        await tester.pumpWidget(
          wrap(
            PathEditor(
              controller: controller,
              snapping: const PathEditorSnapping(threshold: 8),
            ),
          ),
        );

        final origin = tester.getTopLeft(find.byType(PathEditor));
        // Select the node so its handles become grabbable.
        await tester.tapAt(origin + const Offset(100, 100));
        await tester.pump();

        // Dragging the handle next to node 2 snaps it onto that node.
        await tester.dragFrom(
          origin + const Offset(180, 100),
          const Offset(-20, 3),
        );
        await tester.pump();
        expect(
          controller.path.nodeAt(const NodeRef(0, 1)).outgoing,
          const Offset(160, 100),
        );

        controller.undo();

        // Holding command suppresses it.
        await holding(tester, LogicalKeyboardKey.metaLeft, () async {
          await tester.dragFrom(
            origin + const Offset(180, 100),
            const Offset(-20, 3),
          );
          await tester.pump();
        });

        expect(
          controller.path.nodeAt(const NodeRef(0, 1)).outgoing,
          const Offset(160, 103),
        );
      });
    });

    testWidgets('bends an existing corner point into a smooth one',
        (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
        final controller = PathEditorController.fromSvg('M20 20L80 20L140 20');

        await tester.pumpWidget(wrap(PathEditor(controller: controller)));
        final origin = tester.getTopLeft(find.byType(PathEditor));

        // A plain drag moves the point.
        await tester.dragFrom(
          origin + const Offset(80, 20),
          const Offset(0, 40),
        );
        await tester.pump();
        expect(
          controller.path.nodeAt(const NodeRef(0, 1)).position,
          const Offset(80, 60),
        );
        expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
            PathNodeType.corner);
        controller.undo();

        // Holding command bends it instead: the point stays put and grows a
        // mirrored pair of handles.
        await holding(tester, LogicalKeyboardKey.metaLeft, () async {
          await tester.dragFrom(
            origin + const Offset(80, 20),
            const Offset(30, 30),
          );
          await tester.pump();
        });

        final node = controller.path.nodeAt(const NodeRef(0, 1));
        expect(node.position, const Offset(80, 20));
        expect(node.type, PathNodeType.mirrored);
        expect(node.outgoing, const Offset(110, 50));
        expect(node.incoming, const Offset(50, -10));
      });
    });

    testWidgets('pulls out handles on a plain drag, without any modifier',
        (tester) async {
      await onPlatform(TargetPlatform.macOS, () async {
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

        expect(
          controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.mirrored,
        );
      });
    });
  });

  group('default shortcuts', () {
    Future<void> undoWith(
      WidgetTester tester,
      TargetPlatform platform,
      LogicalKeyboardKey modifier,
    ) async {
      await onPlatform(platform, () async {
        final controller = PathEditorController.fromSvg('M20 20L120 20');

        await tester.pumpWidget(
          wrap(PathEditor(controller: controller, autofocus: true)),
        );
        await tester.pump();

        final origin = tester.getTopLeft(find.byType(PathEditor));
        await tester.dragFrom(
          origin + const Offset(120, 20),
          const Offset(0, 40),
        );
        await tester.pump();
        expect(controller.svg, 'M20.0 20.0L120.0 60.0');

        await holding(tester, modifier, () async {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.pump();
        });

        expect(controller.svg, 'M20.0 20.0L120.0 20.0');
      });
    }

    testWidgets('command Z undoes on macOS', (tester) async {
      await undoWith(tester, TargetPlatform.macOS, LogicalKeyboardKey.metaLeft);
    });

    testWidgets('control Z undoes elsewhere', (tester) async {
      await undoWith(
        tester,
        TargetPlatform.linux,
        LogicalKeyboardKey.controlLeft,
      );
    });
  });
}
