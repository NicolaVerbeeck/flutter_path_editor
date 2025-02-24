import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';

/// Holds the current path string and cached version of the path
@immutable
class PathHolder {
  /// The path represented as a string
  final String pathString;

  /// The path object associated with the path string. Do not mutate this path,
  /// it is provided as a convenience to avoid creating a path multiple times
  final Path path;

  /// Create a new path holder
  const PathHolder({
    required this.pathString,
    required this.path,
  });
}

/// Controller for the path editor. Fires when changes happen
class PathEditorController extends ValueNotifier<PathHolder> {
  final List<PathOperator> _operators;

  /// The path operators describing this path
  List<PathOperator> get operators => _operators;

  /// The [Path] representing the editing path
  Path get path => value.path;

  /// Create a new controller with the given path
  factory PathEditorController(String path) {
    final operators = PathOperator.parse(path);
    final holder = _buildPathHolder(operators);
    return PathEditorController._(holder, operators);
  }

  PathEditorController._(super.holder, this._operators);

  /// Update the path with the given path string
  void updatePath(String path) {
    _operators.clear();
    _operators.addAll(PathOperator.parse(path));

    value = _buildPathHolder(operators);
  }

  /// Insert a line to from point at the given [index] to the provided [point]
  void insertPoint(PathSegmentIndex index, Offset point) {
    assert(index.value >= 0 && index.value <= _operators.length);
    _operators.insert(index.value + 1, LineTo(x: point.dx, y: point.dy));

    value = _buildPathHolder(operators);
  }

  /// Move the point at the given [index] to the [point]
  void updatePointPosition(PathPointIndex index, Offset point) {
    final oldPoint = _operators[index.value];

    switch (oldPoint) {
      case MoveTo():
        operators[index.value] = MoveTo(
          x: point.dx,
          y: point.dy,
        );
      case LineTo():
        operators[index.value] = LineTo(
          x: point.dx,
          y: point.dy,
        );
      case CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2):
        operators[index.value] = CubicTo(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          x: point.dx,
          y: point.dy,
        );
      case Close():
      // Do nothing for close operator
    }

    value = _buildPathHolder(operators);
  }

  /// Move the control point with index [controlPointIndex]
  /// for the point at [selectedPoint] to the given [point]
  void updateControlPointPosition(
    ControlPointIndex controlPointIndex,
    PathPointIndex selectedPoint,
    Offset point,
  ) {
    final updatingPoint = _operators[selectedPoint.value];
    assert(updatingPoint is CubicTo);

    updatingPoint as CubicTo;
    final index = controlPointIndex.value;
    if (index < 0 || index > 1) {
      throw ArgumentError('controlPointIndex must be 0 or 1');
    }

    _operators[selectedPoint.value] = CubicTo(
      x1: index == 0 ? point.dx : updatingPoint.x1,
      y1: index == 0 ? point.dy : updatingPoint.y1,
      x2: index == 1 ? point.dx : updatingPoint.x2,
      y2: index == 1 ? point.dy : updatingPoint.y2,
      x: updatingPoint.x,
      y: updatingPoint.y,
    );

    value = _buildPathHolder(operators);
  }

  /// Get the control points (if any) for an operator at [index]
  List<Offset> controlPointsAt(PathPointIndex index) {
    final pt = _operators[index.value];
    return switch (pt) {
      CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2) => [
          Offset(x1, y1),
          Offset(x2, y2),
        ],
      _ => [],
    };
  }

  static PathHolder _buildPathHolder(List<PathOperator> operators) {
    final str = operators.map((e) => e.toSvg()).join('');
    final path = Path();

    for (final op in operators) {
      op.map(
        moveTo: (op) => path.moveTo(op.x, op.y),
        lineTo: (op) => path.lineTo(op.x, op.y),
        cubicTo: (op) => path.cubicTo(
          op.x1,
          op.y1,
          op.x2,
          op.y2,
          op.x,
          op.y,
        ),
        close: (_) => path.close(),
      );
    }

    return PathHolder(
      pathString: str,
      path: path,
    );
  }
}
