import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';
import 'package:path_editor/src/util/path_math.dart';

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
  final int maxUndoSteps;
  final List<PathCommand> _undoStack = [];
  final List<PathCommand> _redoStack = [];

  bool _isPanning = false;
  List<PathOperator>? _panStartOperators;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// The path operators describing this path
  List<PathOperator> get operators => _operators;

  /// The [Path] representing the editing path
  Path get path => value.path;

  /// Create a new controller with the given path
  factory PathEditorController(String path, {int maxUndoSteps = 50}) {
    final operators = PathOperator.parse(path);
    final holder = _buildPathHolder(operators);
    return PathEditorController._(holder, operators,
        maxUndoSteps: maxUndoSteps);
  }

  PathEditorController._(
    super.holder,
    this._operators, {
    this.maxUndoSteps = 50,
  });

  void _executeCommand(PathCommand command) {
    // Skip creating undo entries during pan operations
    if (_isPanning) {
      command.execute(_operators);
      value = _buildPathHolder(_operators);
      return;
    }

    command.execute(_operators);
    _undoStack.add(command);
    if (_undoStack.length > maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    value = _buildPathHolder(_operators);
  }

  bool undo() {
    if (!canUndo) return false;
    final command = _undoStack.removeLast();
    command.undo(_operators);
    _redoStack.add(command);
    value = _buildPathHolder(_operators);
    return true;
  }

  bool redo() {
    if (!canRedo) return false;
    final command = _redoStack.removeLast();
    command.execute(_operators);
    _undoStack.add(command);
    value = _buildPathHolder(_operators);
    return true;
  }

  /// Update the path with the given path string
  void updatePath(String path) {
    final newOperators = PathOperator.parse(path);
    if (!newOperators.deepEquals(_operators)) {
      _executeCommand(
        UpdatePathCommand(
          List.from(_operators),
          newOperators,
        ),
      );
    }
  }

  /// Insert a line to from point at the given [index] to the provided [point]
  void insertPoint(PathSegmentIndex index, Offset point) {
    assert(index.value >= 0 && index.value <= _operators.length);
    _executeCommand(
      InsertPointCommand(
        index.value + 1,
        LineTo(x: point.dx, y: point.dy),
      ),
    );
  }

  /// Move the point at the given [index] to the [point]
  void updatePointPosition(PathPointIndex index, Offset point) {
    final oldPoint = _operators[index.value];
    final newPoint = switch (oldPoint) {
      MoveTo() => MoveTo(x: point.dx, y: point.dy),
      LineTo() => LineTo(x: point.dx, y: point.dy),
      CubicTo(x1: var x1, y1: var y1, x2: var x2, y2: var y2) =>
        CubicTo(x1: x1, y1: y1, x2: x2, y2: y2, x: point.dx, y: point.dy),
      Close() =>
        throw ArgumentError('Cannot update position of close operator'),
    };

    _executeCommand(
      UpdateOperatorCommand(
        index.value,
        oldPoint,
        newPoint,
      ),
    );
  }

  /// Move the control point with index [controlPointIndex]
  /// for the point at [selectedPoint] to the given [point]
  void updateControlPointPosition(
    ControlPointIndex controlPointIndex,
    PathPointIndex selectedPoint,
    Offset point,
  ) {
    final oldPoint = _operators[selectedPoint.value] as CubicTo;
    final index = controlPointIndex.value;
    if (index < 0 || index > 1) {
      throw ArgumentError('controlPointIndex must be 0 or 1');
    }

    final newPoint = CubicTo(
      x1: index == 0 ? point.dx : oldPoint.x1,
      y1: index == 0 ? point.dy : oldPoint.y1,
      x2: index == 1 ? point.dx : oldPoint.x2,
      y2: index == 1 ? point.dy : oldPoint.y2,
      x: oldPoint.x,
      y: oldPoint.y,
    );

    _executeCommand(UpdateOperatorCommand(
      selectedPoint.value,
      oldPoint,
      newPoint,
    ));
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

  /// Calcualte the bounding box of the path if the path were stroked with the
  /// given [strokeWidth]. Use [accurracy] to control how accurate the bounds check
  /// should be when dealing with curves. The default is [BoundsCheckAccuracy.fine]
  Rect calculateBoundingBox(
    double strokeWidth, {
    BoundsCheckAccuracy accurracy = BoundsCheckAccuracy.fine,
  }) =>
      calculatePathBounds(
        operators,
        strokeWidth: strokeWidth,
        quadraticSamplingStep: accurracy._steps,
      );

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

  /// Notify the controller that we are entering a pan gesture
  /// This is used to prevent undo/redo commands from being added for every
  /// update during a pan gesture. We do update the path during a pan gesture,
  /// but we only add a single undo command for the entire pan operation
  void beginPan() {
    if (!_isPanning) {
      _isPanning = true;
      _panStartOperators = List.from(_operators);
    }
  }

  /// Notify the controller that we are ending a pan gesture
  /// This is used to prevent undo/redo commands from being added for every
  /// update during a pan gesture. On pan end we add the undo command
  /// for the entire pan operation
  void endPan() {
    if (_isPanning && _panStartOperators != null) {
      _isPanning = false;
      if (!_panStartOperators!.deepEquals(_operators)) {
        // Only create undo command if there were actual changes
        _executeCommand(UpdatePathCommand(
          _panStartOperators!,
          List.from(_operators),
        ));
      }
      _panStartOperators = null;
    }
  }
}

/// How accurate the bounds check should be when dealing with curves
enum BoundsCheckAccuracy {
  /// Very fine accuracy
  finest._(steps: 0.01),

  /// Fine accuracy. Twice as fast as [finest]
  fine._(steps: 0.05),

  /// Coarse accuracy. Twice as fast as [fine]
  coarse._(steps: 0.1),
  ;

  final double _steps;

  const BoundsCheckAccuracy._({required double steps}) : _steps = steps;
}
