import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/model/editing.dart';

void main() {
  group('Editing controller tests', () {
    late PathEditorController sut;

    setUp(() {
      sut = PathEditorController('M1 2');
    });

    test('it has initial path set', () {
      expect(sut.value.pathString, 'M1.0 2.0');
    });

    test('it can add points', () {
      sut.insertPoint(PathSegmentIndex(0), const Offset(3, 4));
      expect(sut.value.pathString, 'M1.0 2.0L3.0 4.0');
    });

    group('it can move points', () {
      test('moveTo', () {
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        expect(sut.value.pathString, 'M3.0 4.0');
      });
      test('lineTo', () {
        sut.updatePath('M1 2L3 4');
        sut.updatePointPosition(PathPointIndex(1), const Offset(5, 6));
        expect(sut.value.pathString, 'M1.0 2.0L5.0 6.0');
      });
      test('cubicTo', () {
        sut.updatePath('M1 2C3 4 5 6 7 8');
        sut.updatePointPosition(PathPointIndex(1), const Offset(10, 11));
        expect(sut.value.pathString, 'M1.0 2.0C3.0 4.0 5.0 6.0 10.0 11.0');
      });
      test('close', () {
        sut.updatePath('M1 2Z');
        expect(
            () =>
                sut.updatePointPosition(PathPointIndex(1), const Offset(3, 4)),
            throwsArgumentError);
      });
    });

    test('it can move control point', () {
      sut.updatePath('M1 2C3 4 5 6 7 8');
      sut.updateControlPointPosition(
          ControlPointIndex(0), PathPointIndex(1), const Offset(10, 11));
      expect(sut.value.pathString, 'M1.0 2.0C10.0 11.0 5.0 6.0 7.0 8.0');
    });

    test('it throws if the control point is out of range', () {
      sut.updatePath('M1 2C3 4 5 6 7 8');
      expect(
        () => sut.updateControlPointPosition(
            ControlPointIndex(2), PathPointIndex(1), const Offset(10, 11)),
        throwsArgumentError,
      );
    });

    test('it can update path', () {
      sut.updatePath('M5 6');
      expect(sut.value.pathString, 'M5.0 6.0');
    });

    test('it can get control points', () {
      sut.updatePath('M1 2C3 4 5 6 7 8');
      final controlPoints = sut.controlPointsAt(PathPointIndex(1));
      expect(controlPoints, [const Offset(3, 4), const Offset(5, 6)]);
    });

    test('it returns empty list for non-cubic control points', () {
      sut.updatePath('M1 2L3 4');
      final controlPoints = sut.controlPointsAt(PathPointIndex(1));
      expect(controlPoints, isEmpty);
    });

    test('it returns a native path via getter', () {
      expect(identical(sut.value.path, sut.path), isTrue);
    });

    group('undo/redo tests', () {
      test('it can undo point moves', () {
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        expect(sut.value.pathString, 'M3.0 4.0');

        sut.undo();
        expect(sut.value.pathString, 'M1.0 2.0');
      });

      test('it can redo point moves', () {
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        sut.undo();
        sut.redo();
        expect(sut.value.pathString, 'M3.0 4.0');
      });

      test('canUndo/canRedo are correct', () {
        expect(sut.canUndo, isFalse);
        expect(sut.canRedo, isFalse);

        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        expect(sut.canUndo, isTrue);
        expect(sut.canRedo, isFalse);

        sut.undo();
        expect(sut.canUndo, isFalse);
        expect(sut.canRedo, isTrue);
      });

      test('new operation clears redo stack', () {
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        sut.undo();
        expect(sut.canRedo, isTrue);

        sut.updatePointPosition(PathPointIndex(0), const Offset(5, 6));
        expect(sut.canRedo, isFalse);
      });

      test('respects max undo steps', () {
        final localSut = PathEditorController('M1 2', maxUndoSteps: 2);

        localSut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        localSut.updatePointPosition(PathPointIndex(0), const Offset(5, 6));
        localSut.updatePointPosition(PathPointIndex(0), const Offset(7, 8));

        expect(localSut.canUndo, isTrue);
        localSut.undo();
        localSut.undo();
        expect(localSut.canUndo, isFalse);
        expect(localSut.value.pathString, 'M3.0 4.0');
      });
    });

    group('pan gesture tests', () {
      test('creates single undo entry for pan sequence', () {
        sut.beginPan();
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        sut.updatePointPosition(PathPointIndex(0), const Offset(5, 6));
        sut.endPan();

        expect(sut.value.pathString, 'M5.0 6.0');
        sut.undo();
        expect(sut.value.pathString, 'M1.0 2.0');
      });

      test('does not create undo entry if no changes during pan', () {
        sut.beginPan();
        sut.endPan();
        expect(sut.canUndo, isFalse);
      });

      test('ignores nested pan calls', () {
        sut.beginPan();
        sut.beginPan(); // Should be ignored
        sut.updatePointPosition(PathPointIndex(0), const Offset(3, 4));
        sut.endPan();
        sut.endPan(); // Should be ignored

        expect(sut.value.pathString, 'M3.0 4.0');
        sut.undo();
        expect(sut.value.pathString, 'M1.0 2.0');
      });
    });

    group('bounds checking tests', () {
      test('returns zero rect for empty path', () {
        sut.updatePath('');
        expect(sut.calculateBoundingBox(2.0), Rect.zero);
      });

      test('includes stroke width in bounds', () {
        sut.updatePath('M0 0L10 0');
        final bounds = sut.calculateBoundingBox(2.0);
        expect(bounds.top, -1.1); // Half stroke width + padding
        expect(bounds.bottom, 1.1);
      });

      test('calculates correct bounds for cubic curves', () {
        // Curve that extends beyond its control points
        sut.updatePath('M0 0C0 10 10 10 10 0');
        final bounds = sut.calculateBoundingBox(
          2.0,
          accurracy: BoundsCheckAccuracy.finest,
        );
        expect(bounds.top, lessThan(0));
        expect(bounds.bottom, greaterThan(5)); // Should catch the curve's peak
      });
    });
  });
}
