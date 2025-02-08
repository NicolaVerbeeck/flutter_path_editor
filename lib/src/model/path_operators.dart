import 'package:meta/meta.dart';
import 'package:path_parsing/path_parsing.dart';

sealed class PathOperator {
  const PathOperator();

  static List<PathOperator> parse(String path) {
    final proxy = _PathProxy();
    writeSvgPathDataToPath(path, proxy);
    return proxy.operators;
  }

  String toSvg();

  T map<T>({
    required T Function(MoveTo) moveTo,
    required T Function(LineTo) lineTo,
    required T Function(CubicTo) cubicTo,
    required T Function(Close) close,
  }) {
    final local = this;
    return switch (local) {
      MoveTo() => moveTo(local),
      LineTo() => lineTo(local),
      CubicTo() => cubicTo(local),
      Close() => close(local),
    };
  }
}

extension PathOpListExt on List<PathOperator> {
  String toSvg() => map((op) => op.toSvg()).join(' ');

  void switchMap<T>({
    required void Function(MoveTo) moveTo,
    required void Function(LineTo) lineTo,
    required void Function(CubicTo) cubicTo,
    required void Function(Close) close,
  }) {
    for (final op in this) {
      op.map(
        moveTo: moveTo,
        lineTo: lineTo,
        cubicTo: cubicTo,
        close: close,
      );
    }
  }

  List<PathOperator> scale(double x, double y) {
    return map(
      (e) => e.map(
        moveTo: (moveTo) => MoveTo(x: moveTo.x * x, y: moveTo.y * y),
        lineTo: (lineTo) => LineTo(x: lineTo.x * x, y: lineTo.y * y),
        cubicTo: (cubicTo) => CubicTo(
          x1: cubicTo.x1 * x,
          y1: cubicTo.y1 * y,
          x2: cubicTo.x2 * x,
          y2: cubicTo.y2 * y,
          x3: cubicTo.x3 * x,
          y3: cubicTo.y3 * y,
        ),
        close: (close) => close,
      ),
    ).toList(growable: false);
  }
}

@immutable
class MoveTo extends PathOperator {
  final double x;
  final double y;

  const MoveTo({required this.x, required this.y});

  @override
  String toSvg() => 'M $x $y';
}

@immutable
class LineTo extends PathOperator {
  final double x;
  final double y;

  const LineTo({required this.x, required this.y});

  @override
  String toSvg() => 'L $x $y';
}

@immutable
class CubicTo extends PathOperator {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  const CubicTo({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.x3,
    required this.y3,
  });

  @override
  String toSvg() => 'C $x1 $y1 $x2 $y2 $x3 $y3';
}

class Close extends PathOperator {
  const Close();

  @override
  String toSvg() => 'Z';
}

class _PathProxy implements PathProxy {
  final operators = <PathOperator>[];

  @override
  void close() => operators.add(const Close());

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) =>
      operators.add(
        CubicTo(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          x3: x3,
          y3: y3,
        ),
      );

  @override
  void lineTo(double x, double y) => operators.add(LineTo(x: x, y: y));

  @override
  void moveTo(double x, double y) => operators.add(MoveTo(x: x, y: y));
}
