import 'package:path_editor/src/model/path_operators.dart';

/// Holder for an index to segments of a path
extension type PathSegmentIndex(int value) {}

/// Holder for an index to an operator
extension type PathPointIndex(int value) {}

/// Holder for an index to a control point. Will be 0 or 1
extension type ControlPointIndex(int value) {}

/// Base class for undoable commands
abstract class PathCommand {
  void execute(List<PathOperator> operators);
  void undo(List<PathOperator> operators);
}

class UpdatePathCommand implements PathCommand {
  final List<PathOperator> oldOperators;
  final List<PathOperator> newOperators;

  UpdatePathCommand(this.oldOperators, this.newOperators);

  @override
  void execute(List<PathOperator> operators) {
    operators.clear();
    operators.addAll(newOperators);
  }

  @override
  void undo(List<PathOperator> operators) {
    operators.clear();
    operators.addAll(oldOperators);
  }
}

class InsertPointCommand implements PathCommand {
  final int index;
  final PathOperator operator;

  InsertPointCommand(this.index, this.operator);

  @override
  void execute(List<PathOperator> operators) {
    operators.insert(index, operator);
  }

  @override
  void undo(List<PathOperator> operators) {
    operators.removeAt(index);
  }
}

class UpdateOperatorCommand implements PathCommand {
  final int index;
  final PathOperator oldOperator;
  final PathOperator newOperator;

  UpdateOperatorCommand(this.index, this.oldOperator, this.newOperator);

  @override
  void execute(List<PathOperator> operators) {
    operators[index] = newOperator;
  }

  @override
  void undo(List<PathOperator> operators) {
    operators[index] = oldOperator;
  }
}
