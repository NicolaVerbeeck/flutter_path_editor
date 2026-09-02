import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  group('construction', () {
    test('parses an svg path', () {
      final controller = PathEditorController.fromSvg('M1 2L3 4');

      expect(controller.path.nodeCount, 2);
      expect(controller.svg, 'M1.0 2.0L3.0 4.0');
      expect(controller.tool, PathTool.select);
    });

    test('starts empty and ready for the pen', () {
      final controller = PathEditorController.empty();

      expect(controller.path.isEmpty, isTrue);
      expect(controller.tool, PathTool.pen);
      expect(controller.svg, isEmpty);
    });

    test('exposes the path as operators and as a ui path', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      expect(controller.operators, hasLength(2));
      expect(controller.uiPath.getBounds(), const Rect.fromLTRB(0, 0, 10, 0));
    });

    test('caches the svg until the path changes', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      expect(identical(controller.svg, controller.svg), isTrue);
      controller.moveNode(const NodeRef(0, 1), const Offset(20, 0));
      expect(controller.svg, 'M0.0 0.0L20.0 0.0');
    });
  });

  group('listenables', () {
    test('the path listenable only fires on path changes', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');
      var pathNotifications = 0;
      var selectionNotifications = 0;
      controller.pathListenable.addListener(() => pathNotifications++);
      controller.selectionListenable
          .addListener(() => selectionNotifications++);

      controller.select([const NodeRef(0, 0)]);
      expect(pathNotifications, 0);
      expect(selectionNotifications, 1);

      controller.moveNode(const NodeRef(0, 0), const Offset(5, 5));
      expect(pathNotifications, 1);
    });

    test('the tool listenable fires on tool changes', () {
      final controller = PathEditorController.fromSvg('M0 0');
      var notifications = 0;
      controller.toolListenable.addListener(() => notifications++);

      controller.tool = PathTool.pen;
      controller.tool = PathTool.pen;

      expect(notifications, 1);
    });

    test('notifies its own listeners for any change', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.select([const NodeRef(0, 0)]);
      controller.tool = PathTool.pen;
      controller.moveNode(const NodeRef(0, 0), const Offset(1, 1));

      expect(notifications, 3);
    });
  });

  group('selection', () {
    test('drops references that no longer exist', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0L20 0');
      controller.select([const NodeRef(0, 0), const NodeRef(0, 2)]);

      controller.removeNodes([const NodeRef(0, 2)]);

      expect(controller.selection.nodes, isEmpty);
    });

    test('ignores references outside the path', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.select([const NodeRef(0, 0), const NodeRef(3, 9)]);

      expect(controller.selection.nodes, {const NodeRef(0, 0)});
    });

    test('selects every node', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0L20 0');

      controller.selectAll();

      expect(controller.selection.nodes, hasLength(3));
    });
  });

  group('undo and redo', () {
    test('undoes and redoes a single edit', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.moveNode(const NodeRef(0, 1), const Offset(50, 0));
      expect(controller.svg, 'M0.0 0.0L50.0 0.0');

      expect(controller.undo(), isTrue);
      expect(controller.svg, 'M0.0 0.0L10.0 0.0');

      expect(controller.redo(), isTrue);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0');
    });

    test('reports when there is nothing to undo or redo', () {
      final controller = PathEditorController.fromSvg('M0 0');

      expect(controller.canUndo, isFalse);
      expect(controller.undo(), isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.redo(), isFalse);
    });

    test('a new edit clears the redo stack', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.moveNode(const NodeRef(0, 1), const Offset(50, 0));
      controller.undo();
      expect(controller.canRedo, isTrue);

      controller.moveNode(const NodeRef(0, 1), const Offset(20, 0));
      expect(controller.canRedo, isFalse);
    });

    test('a transaction collapses many edits into one step', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.transaction(() {
        controller.moveNode(const NodeRef(0, 1), const Offset(20, 0));
        controller.moveNode(const NodeRef(0, 1), const Offset(30, 0));
        controller.moveNode(const NodeRef(0, 1), const Offset(40, 0));
      });

      expect(controller.svg, 'M0.0 0.0L40.0 0.0');
      controller.undo();
      expect(controller.svg, 'M0.0 0.0L10.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('nested transactions produce a single step', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.transaction(() {
        controller.moveNode(const NodeRef(0, 1), const Offset(20, 0));
        controller.transaction(() {
          controller.moveNode(const NodeRef(0, 1), const Offset(30, 0));
        });
        expect(controller.isInTransaction, isTrue);
      });

      controller.undo();
      expect(controller.svg, 'M0.0 0.0L10.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('a transaction without changes records nothing', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.transaction(() {});

      expect(controller.canUndo, isFalse);
    });

    test('cancelling rolls the path back', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.beginTransaction();
      controller.moveNode(const NodeRef(0, 1), const Offset(90, 0));
      controller.cancelTransaction();

      expect(controller.svg, 'M0.0 0.0L10.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('an exception inside a transaction rolls it back', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      expect(
        () => controller.transaction(() {
          controller.moveNode(const NodeRef(0, 1), const Offset(90, 0));
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(controller.svg, 'M0.0 0.0L10.0 0.0');
      expect(controller.isInTransaction, isFalse);
    });

    test('honours the undo limit', () {
      final controller =
          PathEditorController.fromSvg('M0 0L10 0', maxUndoSteps: 2);

      for (var i = 1; i <= 5; ++i) {
        controller.moveNode(const NodeRef(0, 1), Offset(i * 10, 0));
      }

      expect(controller.undo(), isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.canUndo, isFalse);
      expect(controller.svg, 'M0.0 0.0L30.0 0.0');
    });

    test('clearing the history drops both stacks', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.moveNode(const NodeRef(0, 1), const Offset(50, 0));
      controller.clearHistory();

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });
  });

  group('editing', () {
    test('refuses a removal that would split an open path', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0L20 0');

      expect(
        controller.canRemoveNodes(
          [const NodeRef(0, 1)],
          mode: NodeRemoval.cut,
        ),
        isFalse,
      );
      expect(
        controller.removeNodes([const NodeRef(0, 1)], mode: NodeRemoval.cut),
        isFalse,
      );
      expect(controller.svg, 'M0.0 0.0L10.0 0.0L20.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('loads a new svg path', () {
      final controller = PathEditorController.fromSvg('M0 0L10 0');

      controller.loadSvg('M5 5L15 15');

      expect(controller.svg, 'M5.0 5.0L15.0 15.0');
      expect(controller.canUndo, isTrue);
    });

    test('computes bounds with an optional stroke', () {
      final controller = PathEditorController.fromSvg('M0 0L10 10');

      expect(controller.bounds(), const Rect.fromLTRB(0, 0, 10, 10));
      expect(
        controller.bounds(strokeWidth: 2),
        const Rect.fromLTRB(-1, -1, 11, 11),
      );
    });

    test('leaving the pen tool finishes the pending path', () {
      final controller = PathEditorController.empty();
      final ref = controller.startSubpath(const PathNode.corner(Offset.zero));
      controller.selection = PathEditorSelection.single(ref, pendingSubpath: 0);

      controller.tool = PathTool.select;

      expect(controller.selection.pendingSubpath, isNull);
    });
  });
}
