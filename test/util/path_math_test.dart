import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/src/model/path_operators.dart';
import 'package:path_editor/src/util/path_math.dart';

void main() {
  group('PathMath tests', () {
    test('findNearestIndex', () {
      final points = <Offset>[
        const Offset(1, 2),
        const Offset(3, 4),
        const Offset(5, 6),
      ];
      const position = Offset(3, 4);
      const hitRadiusSquared = 1.0;
      final index = findNearestIndex(points, position, hitRadiusSquared);
      expect(index, isNotNull);
      expect(index!.value, 1);
    });
    test('findNearestControlPointIndex', () {
      final points = <Offset>[
        const Offset(1, 2),
        const Offset(3, 4),
        const Offset(5, 6),
      ];
      const position = Offset(3, 4);
      const hitRadiusSquared = 1.0;
      final index =
          findNearestControlPointIndex(points, position, hitRadiusSquared);
      expect(index, isNotNull);
      expect(index!.value, 1);
    });
    test('findClosestSegment', () {
      const operators = [
        MoveTo(x: 1, y: 2),
        LineTo(x: 3, y: 4),
        CubicTo(x1: 5, y1: 6, x2: 7, y2: 8, x: 9, y: 10),
      ];
      const point = Offset(3, 4);
      const maxDistance = 1.0;
      final index = findClosestSegment(operators, point, maxDistance);
      expect(index, isNotNull);
      expect(index!.value, 0);
    });
  });
}
