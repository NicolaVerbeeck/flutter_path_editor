import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';
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
  });
}
