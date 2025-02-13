import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/painting/path_painter.dart';
import 'package:path_editor/src/painting/points_painter.dart';
import 'package:path_editor/src/painting/segment_painter.dart';
import 'package:path_editor/src/util/path_math.dart';

class PathEditor extends StatefulWidget {
  static const _defaiultPointHitRadius = 10.0;
  static const _defaultControlPointHitRadius = 10.0;

  final PathEditorController _controller;
  final double _pointHitRadius;
  final double _controlPointHitRadius;
  final double controlPointStrokeWidth;
  final double controlPointRadius;
  final double selectedPointRadius;
  final double unselectedPointRadius;

  // Add new visual customization properties
  final Color strokeColor;
  final double strokeWidth;
  final BlendMode blendMode;
  final Color indicatorColor;
  final Color controlPointColor;
  final Color selectedPointColor;
  final Color unselectedPointColor;

  const PathEditor({
    super.key,
    required PathEditorController controller,
    double pointHitRadius = _defaiultPointHitRadius,
    double controlPointHitRadius = _defaultControlPointHitRadius,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.blendMode = BlendMode.srcOver,
    this.indicatorColor = Colors.blue,
    this.controlPointColor = Colors.green,
    this.selectedPointColor = Colors.red,
    this.unselectedPointColor = Colors.black,
    this.controlPointStrokeWidth = 2.0,
    this.controlPointRadius = 5.0,
    this.selectedPointRadius = 8.0,
    this.unselectedPointRadius = 5.0,
  })  : _controller = controller,
        _pointHitRadius = pointHitRadius,
        _controlPointHitRadius = controlPointHitRadius;

  @override
  State<PathEditor> createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  var _points = <Offset>[];
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
            moveTo: (m) => Offset(m.x, m.y),
            lineTo: (l) => Offset(l.x, l.y),
            cubicTo: (c) => Offset(c.x3, c.y3),
            close: (_) => null,
          ),
        )
        .nonNulls
        .toList();
    _highlightedSegment = null;

    // Check if the selected index is still with the valid range
    if (_selectedIndex != null && _selectedIndex!.value >= _points.length) {
      _selectedIndex = null;
      _selectedControlPointIndex = null;
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
                  strokeColor: widget.strokeColor,
                  strokeWidth: widget.strokeWidth,
                  blendMode: widget.blendMode,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SegmentPainter(
                  widget._controller.operators,
                  _highlightedSegment,
                  _indicatorPosition,
                  // indicatorColor: widget.indicatorColor,
                  // blendMode: widget.blendMode,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: PointsPainter(
                  points: _points,
                  selectedIndex: _selectedIndex,
                  controlPoints: _controlPoints,
                  controlPointColor: widget.controlPointColor,
                  selectedPointColor: widget.selectedPointColor,
                  unselectedPointColor: widget.unselectedPointColor,
                  blendMode: widget.blendMode,
                  controlPointStrokeWidth: widget.controlPointStrokeWidth,
                  controlPointRadius: widget.controlPointRadius,
                  selectedPointRadius: widget.selectedPointRadius,
                  unselectedPointRadius: widget.unselectedPointRadius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleHover(PointerHoverEvent details) {
    final localPosition = details.localPosition;

    // Check if we are hovering over a control point
    final controlPointIndex = findNearestControlPointIndex(
      _controlPoints,
      localPosition,
      widget._controlPointHitRadius,
    );

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
    final nearestPointIndex =
        findNearestIndex(_points, localPosition, widget._pointHitRadius);
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
    final index = findClosestSegment(
      widget._controller.operators,
      details.localPosition,
    );
    final indicatorPosition = index == null
        ? null
        : calculateIndicatorPosition(
            widget._controller.operators,
            details.localPosition,
            index,
          );
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

    // Check if the selected control point is still valid
    if (_selectedControlPointIndex != null &&
        _selectedControlPointIndex!.value >= _controlPoints.length) {
      _selectedControlPointIndex = null;
    }
  }

  void _handleCanvasTap(TapDownDetails details) {
    final localPosition = details.localPosition;

    final controlPointIndex = findNearestControlPointIndex(
      _controlPoints,
      localPosition,
      widget._controlPointHitRadius,
    );
    if (controlPointIndex != null) {
      setState(() {
        _selectedControlPointIndex = controlPointIndex;
        _cursor = SystemMouseCursors.grab;
      });
      return;
    }

    final point = findNearestIndex(
      _points,
      localPosition,
      widget._pointHitRadius,
    );

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
