import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/model/path_operators.dart';
import 'package:path_editor/src/painting/path_painter.dart';
import 'package:path_editor/src/painting/points_painter.dart';
import 'package:path_editor/src/painting/segment_painter.dart';

class PathEditor extends StatefulWidget {
  final PathEditorController _controller;

  const PathEditor({
    super.key,
    required PathEditorController controller,
  }) : _controller = controller;

  @override
  State<PathEditor> createState() => _PathEditorState();
}

class _OffsetPointHolder {
  final Offset offset;
  final PathOperator source;

  _OffsetPointHolder(this.offset, this.source);
}

class _PathEditorState extends State<PathEditor> {
  var _points = <_OffsetPointHolder>[];
  var _controlPoints = <Offset>[];

  PathPointIndex? _selectedIndex;
  PathSegmentIndex? _highlightedSegment;
  ControlPointIndex? _selectedControlPointIndex;

  Offset? _indicatorPosition;
  var _cursor = SystemMouseCursors.basic;

  @override
  void initState() {
    super.initState();

    _rebuildPoints();
  }

  @override
  void didUpdateWidget(covariant PathEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    _rebuildPoints();
  }

  void _rebuildPoints() {
    _points = widget._controller.operators
        .map(
          (e) => e.map(
              moveTo: (m) => _OffsetPointHolder(Offset(m.x, m.y), m),
              lineTo: (l) => _OffsetPointHolder(Offset(l.x, l.y), l),
              cubicTo: (c) => _OffsetPointHolder(Offset(c.x3, c.y3), c),
              close: (_) => null),
        )
        .nonNulls
        .toList();
    _highlightedSegment = null;

    // Check if the selected index is still with the valid range
    if (_selectedIndex != null && _selectedIndex!.value >= _points.length) {
      _selectedIndex = null;
    }

    _rebuildControlPoints();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _cursor,
      onHover: _handleHover,
      child: GestureDetector(
        onTapDown: _handleCanvasTap,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PathPainter(
                  operators: widget._controller.operators,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SegmentPainter(
                  widget._controller.operators,
                  _highlightedSegment,
                  _indicatorPosition,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: PointsPainter(
                  points: _points.map((e) => e.offset).toList(),
                  selectedIndex: _selectedIndex,
                  controlPoints: _controlPoints,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleHover(PointerHoverEvent details) {
    // Check if we are hovering over a control point
    final controlPointIndex =
        _findNearestControlPointIndex(details.localPosition);

    _selectedControlPointIndex = controlPointIndex;
    if (controlPointIndex != null) {
      setState(() {
        _cursor = SystemMouseCursors.grab;
        _highlightedSegment = null;
        _indicatorPosition = null;
      });
      return;
    }

    // Check if we are hovering over a point. If it is the selected point,
    // we should show the grab cursor, otherwise we should show the click cursor
    final nearestPointIndex = _findNearestIndex(details.localPosition);
    if (nearestPointIndex != null) {
      final newCursor = _selectedIndex == nearestPointIndex
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click;

      setState(() {
        _cursor = newCursor;
        _highlightedSegment = null;
        _indicatorPosition = null;
      });
      return;
    }

    // Find a segment we are hovering over. If we have a segment, show the
    // indicator for that segment
    final index = widget._controller.findClosestSegment(details.localPosition);
    final indicatorPosition = index == null
        ? null
        : widget._controller
            .calculateIndicatorPosition(details.localPosition, index);
    setState(() {
      _cursor = SystemMouseCursors.basic;
      _highlightedSegment = index;
      _indicatorPosition = indicatorPosition;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (_selectedIndex != null) {
      setState(() {
        _cursor = SystemMouseCursors.grabbing;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_selectedControlPointIndex != null) {
      assert(_selectedIndex != null,
          'Selected control point should have a selected point index');
      widget._controller.updateControlPointPosition(
        _selectedControlPointIndex!,
        _selectedIndex!,
        details.localPosition,
      );
      setState(() {
        _rebuildPoints();
      });
    } else if (_selectedIndex != null) {
      widget._controller
          .updatePointPosition(_selectedIndex!, details.localPosition);
      setState(() {
        _rebuildPoints();
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_selectedIndex != null || _selectedControlPointIndex != null) {
      setState(() {
        _cursor = SystemMouseCursors.grab;
      });
    }
  }

  void _rebuildControlPoints() {
    _controlPoints = _selectedIndex == null
        ? []
        : widget._controller.controlPointsAt(_selectedIndex!);
  }

  static const _pointHitRadiusSquared = 100.0;
  static const _controlPointHitRadiusSquared = 100.0;

  PathPointIndex? _findNearestIndex(Offset position) {
    final scaledPosition = position;
    for (int i = 0; i < _points.length; ++i) {
      if ((scaledPosition - _points[i].offset).distanceSquared <
          _pointHitRadiusSquared) {
        return PathPointIndex(i);
      }
    }
    return null;
  }

  ControlPointIndex? _findNearestControlPointIndex(Offset position) {
    for (int i = 0; i < _controlPoints.length; ++i) {
      if ((position - _controlPoints[i]).distanceSquared <
          _controlPointHitRadiusSquared) {
        return ControlPointIndex(i);
      }
    }
    return null;
  }

  void _handleCanvasTap(TapDownDetails details) {
    final localPosition = details.localPosition;

    final controlPointIndex = _findNearestControlPointIndex(localPosition);
    if (controlPointIndex != null) {
      setState(() {
        _selectedControlPointIndex = controlPointIndex;
        _cursor = SystemMouseCursors.grab;
      });
      return;
    }

    final point = _findNearestIndex(localPosition);

    // If we are not hitting a point, perhaps we are inserting a new point
    // in a segment
    if (point == null && _indicatorPosition != null) {
      final segment = _highlightedSegment;
      assert(segment != null,
          'Having an indicator should also have a segment that indicator applies to');

      widget._controller.insertPoint(segment!, localPosition);

      // If the parent widget does not rebuild the path, we need to rebuild
      // the points manually
      setState(() {
        _highlightedSegment = null;
        _indicatorPosition = null;
        _rebuildPoints();
        _selectedIndex = null;
      });
      return;
    }

    setState(() {
      _selectedIndex = point;
      _selectedControlPointIndex = null;
      _rebuildControlPoints();
      _cursor =
          point != null ? SystemMouseCursors.grab : SystemMouseCursors.basic;
    });
  }
}
