import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';

class PathEditorController extends ValueNotifier<String> {
  final List<PathOperator> _operators;

  PathEditorController(super.path) : _operators = PathOperator.parse(path);

  String get path => _operators.map((e) => e.toSvg()).join('');

  List<PathOperator> get operators => _operators;

  void updatePath(String path) {
    _operators.clear();
    _operators.addAll(PathOperator.parse(path));
  }

  void insertPoint(PathSegmentIndex index, Offset point) {
    assert(index.value >= 0 && index.value <= _operators.length);
    _operators.insert(index.value + 1, LineTo(x: point.dx, y: point.dy));

    value = path;
  }

  void updatePointPosition(PathPointIndex index, Offset point) {
    final oldPoint = _operators[index.value];

    switch (oldPoint) {
      case MoveTo():
        operators[index.value] = MoveTo(x: point.dx, y: point.dy);
      case LineTo():
        operators[index.value] = LineTo(x: point.dx, y: point.dy);
      case CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2):
        operators[index.value] =
            CubicTo(x1: x1, y1: y1, x2: x2, y2: y2, x3: point.dx, y3: point.dy);
      case Close():
      // Do nothing for close operator
    }
    value = path;
  }

  void updateControlPointPosition(
    ControlPointIndex controlPointIndex,
    PathPointIndex selectedPoint,
    Offset point,
  ) {
    final updatingPoint = _operators[selectedPoint.value];
    assert(updatingPoint is CubicTo);

    updatingPoint as CubicTo;
    final index = controlPointIndex.value;

    _operators[selectedPoint.value] = CubicTo(
      x1: index == 0 ? point.dx : updatingPoint.x1,
      y1: index == 0 ? point.dy : updatingPoint.y1,
      x2: index == 1 ? point.dx : updatingPoint.x2,
      y2: index == 1 ? point.dy : updatingPoint.y2,
      x3: updatingPoint.x3,
      y3: updatingPoint.y3,
    );
    value = path;
  }

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
}
