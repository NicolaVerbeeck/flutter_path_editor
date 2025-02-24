import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/src/model/path_operators.dart';

void main() {
  group('PathOperator tests', () {
    test('MoveTo toSvg', () {
      const moveTo = MoveTo(x: 1.0, y: 2.0);
      expect(moveTo.toSvg(), 'M1.0 2.0');
    });

    test('LineTo toSvg', () {
      const lineTo = LineTo(x: 3.0, y: 4.0);
      expect(lineTo.toSvg(), 'L3.0 4.0');
    });

    test('CubicTo toSvg', () {
      const cubicTo =
          CubicTo(x1: 1.0, y1: 2.0, x2: 3.0, y2: 4.0, x: 5.0, y: 6.0);
      expect(cubicTo.toSvg(), 'C1.0 2.0 3.0 4.0 5.0 6.0');
    });

    test('Close toSvg', () {
      const close = Close();
      expect(close.toSvg(), 'Z');
    });

    test('PathOperator parse', () {
      final operators = PathOperator.parse('M1 2L3 4C5 6 7 8 9 10Z');
      expect(operators, [
        const MoveTo(x: 1.0, y: 2.0),
        const LineTo(x: 3.0, y: 4.0),
        const CubicTo(x1: 5.0, y1: 6.0, x2: 7.0, y2: 8.0, x: 9.0, y: 10.0),
        const Close(),
      ]);
    });

    test('PathOperator deepEquals', () {
      final operators1 = PathOperator.parse('M1 2L3 4');
      final operators2 = PathOperator.parse('M1 2L3 4');
      final operators3 = PathOperator.parse('M1 2L3 5');
      expect(operators1.deepEquals(operators2), isTrue);
      expect(operators1.deepEquals(operators3), isFalse);
    });

    test('PathOperator scale', () {
      final operators = PathOperator.parse('M1 2L3 4C5 6 7 8 9 10Z');
      final scaled = operators.scale(2.0, 2.0);
      expect(scaled.toSvg(), 'M2.0 4.0L6.0 8.0C10.0 12.0 14.0 16.0 18.0 20.0Z');
    });

    test('PathOperator translate', () {
      final operators = PathOperator.parse('M1 2L3 4C5 6 7 8 9 10Z');
      final translated = operators.translate(1.0, 1.0);
      expect(translated.toSvg(), 'M2.0 3.0L4.0 5.0C6.0 7.0 8.0 9.0 10.0 11.0Z');
    });

    test('Extension toSvg', () {
      final operators = PathOperator.parse('M1 2L3 4C5 6 7 8 9 10Z');
      expect(operators.toSvg(), 'M1.0 2.0L3.0 4.0C5.0 6.0 7.0 8.0 9.0 10.0Z');
    });
    test('Extension switchMap', () {
      final operators = PathOperator.parse('M1 2L3 4C5 6 7 8 9 10Z');
      final results = <String>[];
      operators.switchMap(
        moveTo: (op) => results.add('moveTo'),
        lineTo: (op) => results.add('lineTo'),
        cubicTo: (op) => results.add('cubicTo'),
        close: (op) => results.add('close'),
      );
      expect(results, ['moveTo', 'lineTo', 'cubicTo', 'close']);
    });
    test('hashCode', () {
      expect(const MoveTo(x: 1, y: 2).hashCode, 1.0.hashCode ^ 2.0.hashCode);
      expect(const LineTo(x: 1, y: 2).hashCode, 1.0.hashCode ^ 2.0.hashCode);
      expect(
        const CubicTo(x1: 1, y1: 2, x2: 3, y2: 4, x: 5, y: 6).hashCode,
        1.0.hashCode ^
            2.0.hashCode ^
            3.0.hashCode ^
            4.0.hashCode ^
            5.0.hashCode ^
            6.0.hashCode,
      );
      expect(const Close().hashCode, 0);
    });
  });
}
