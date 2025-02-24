import 'package:flutter/foundation.dart';
import 'package:path_parsing/path_parsing.dart';

/// Path operator class heirarchy. The coordinates expressed in the subclasses
/// are always absolute coordinates
sealed class PathOperator {
  const PathOperator();

  /// Parse the [path] to a list of operators
  static List<PathOperator> parse(String path) {
    final proxy = _PathProxy();
    writeSvgPathDataToPath(path, proxy);
    return proxy.operators;
  }

  /// Convert the operator to an svg path operator
  String toSvg();

  /// Map the operator to its type
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

/// Extensions on [List<PathOperator>]
extension PathOpListExt on List<PathOperator> {
  /// Checks if the list equals [other]
  bool deepEquals(List<PathOperator> other) {
    if (length != other.length) return false;

    for (var i = 0; i < length; ++i) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  /// Helper method that converts the list to a full svg string
  String toSvg() => map((op) => op.toSvg()).join('');

  /// Helper method that calls [map] on each element seperately
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

  /// Apply the [x] and [y] as scale's to each point and control points
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
          x: cubicTo.x * x,
          y: cubicTo.y * y,
        ),
        close: (close) => close,
      ),
    ).toList(growable: false);
  }

  /// Translate the path points by [x] and [y]
  List<PathOperator> translate(double x, double y) {
    return map(
      (e) => e.map(
        moveTo: (moveTo) => MoveTo(x: moveTo.x + x, y: moveTo.y + y),
        lineTo: (lineTo) => LineTo(x: lineTo.x + x, y: lineTo.y + y),
        cubicTo: (cubicTo) => CubicTo(
          x1: cubicTo.x1 + x,
          y1: cubicTo.y1 + y,
          x2: cubicTo.x2 + x,
          y2: cubicTo.y2 + y,
          x: cubicTo.x + x,
          y: cubicTo.y + y,
        ),
        close: (close) => close,
      ),
    ).toList(growable: false);
  }
}

/// Move to operator. Coordinates are absolute
@immutable
class MoveTo extends PathOperator {
  /// The x coordinate (absolute) of the operator
  final double x;

  /// The y coordinate (absolute) of the operator
  final double y;

  /// Creates a new move to operator
  const MoveTo({required this.x, required this.y});

  @override
  String toSvg() => 'M$x $y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoveTo && x == other.x && y == other.y);

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Line to operator. Coordinates are absolute
@immutable
class LineTo extends PathOperator {
  /// The x coordinate (absolute) of the operator
  final double x;

  /// The y coordinate (absolute) of the operator
  final double y;

  /// Creates a new line to operator
  const LineTo({required this.x, required this.y});

  @override
  String toSvg() => 'L$x $y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineTo && x == other.x && y == other.y);

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Cubic bezier curve operator. Coordinates are absolute
@immutable
class CubicTo extends PathOperator {
  /// The x coordinate (absolute) of the first control point
  final double x1;

  /// The y coordinate (absolute) of the first control point
  final double y1;

  /// The x coordinate (absolute) of the second control point
  final double x2;

  /// The y coordinate (absolute) of the second control point
  final double y2;

  /// The x coordinate (absolute) of the end of the curve
  final double x;

  /// The y coordinate (absolute) of the end of the curve
  final double y;

  /// Creates a new cubic curve to operator
  const CubicTo({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.x,
    required this.y,
  });

  @override
  String toSvg() => 'C$x1 $y1 $x2 $y2 $x $y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CubicTo &&
          x1 == other.x1 &&
          y1 == other.y1 &&
          x2 == other.x2 &&
          y2 == other.y2 &&
          x == other.x &&
          y == other.y);

  @override
  int get hashCode =>
      x1.hashCode ^
      y1.hashCode ^
      x2.hashCode ^
      y2.hashCode ^
      x.hashCode ^
      y.hashCode;
}

/// Operator that closses the current (sub)path
class Close extends PathOperator {
  /// Constructor
  const Close();

  @override
  String toSvg() => 'Z';

  @override
  bool operator ==(Object other) => other is Close;

  @override
  int get hashCode => 0;
}

/// [PathProxy] implementation that used to transform a string path into a list
/// of path operators
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
          x: x3,
          y: y3,
        ),
      );

  @override
  void lineTo(double x, double y) => operators.add(LineTo(x: x, y: y));

  @override
  void moveTo(double x, double y) => operators.add(MoveTo(x: x, y: y));
}
