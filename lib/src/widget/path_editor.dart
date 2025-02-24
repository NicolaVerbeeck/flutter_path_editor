import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/model/editing.dart';
import 'package:path_editor/src/painting/path_painter.dart';
import 'package:path_editor/src/painting/points_painter.dart';
import 'package:path_editor/src/painting/segment_painter.dart';
import 'package:path_editor/src/util/path_math.dart';

/// A widget that allows the user to edit a path
class PathEditor extends StatefulWidget {
  static const _defaiultPointHitRadius = 10.0;
  static const _defaultControlPointHitRadius = 10.0;
  static const _defaultMinSegmentDistance = 20.0;

  /// The controller for the path
  final PathEditorController controller;

  /// The hit radius to use when checking if the 'cursor' is overlapping a point
  final double pointHitRadius;

  /// The hit radius to use when checking if the 'cursor' is overlapping a control point
  final double controlPointHitRadius;

  /// The minimum distance to consider a segment as 'hovered'
  final double minSegmentDistance;

  /// The stroke width of the control points
  final double controlPointStrokeWidth;

  /// The stroke width of the control point lines
  final double controlPointLineStrokeWidth;

  /// The radius of the control points
  final double controlPointRadius;

  /// The radius of the selected point
  final double selectedPointRadius;

  /// The radius of the unselected point
  final double unselectedPointRadius;

  /// The radius of the insert point
  final double insertPointRadius;

  /// The stroke width of the insert point
  final double insertPointStrokeWidth;

  /// The stroke width of the path
  final double pathStrokeWidth;

  /// The color of the path
  final Color strokeColor;

  /// The blend mode to use when rendering the elements
  final BlendMode blendMode;

  /// The color of the highlighted segment
  final Color segmentHighligtColor;

  /// The color of the control points
  final Color controlPointColor;

  /// The color of the control point lines
  final Color controlPointLineColor;

  /// The color of the selected point
  final Color selectedPointColor;

  /// The color of the unselected point
  final Color unselectedPointColor;

  /// The color of the insert point
  final Color insertPointColor;

  /// Creates a new path editor
  const PathEditor({
    super.key,
    required this.controller,
    this.pointHitRadius = _defaiultPointHitRadius,
    this.controlPointHitRadius = _defaultControlPointHitRadius,
    this.minSegmentDistance = _defaultMinSegmentDistance,
    this.strokeColor = Colors.black,
    this.pathStrokeWidth = 2.0,
    this.blendMode = BlendMode.srcOver,
    this.segmentHighligtColor = Colors.blue,
    this.controlPointColor = Colors.green,
    this.controlPointLineColor = Colors.green,
    this.selectedPointColor = Colors.red,
    this.unselectedPointColor = Colors.black,
    this.insertPointColor = Colors.red,
    this.insertPointRadius = 5.0,
    this.controlPointStrokeWidth = 2.0,
    this.controlPointRadius = 5.0,
    this.selectedPointRadius = 8.0,
    this.unselectedPointRadius = 5.0,
    this.controlPointLineStrokeWidth = 2.5,
    this.insertPointStrokeWidth = 3.0,
  });

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
    _points = widget.controller.operators
        .map(
          (e) => e.map(
            moveTo: (m) => Offset(m.x, m.y),
            lineTo: (l) => Offset(l.x, l.y),
            cubicTo: (c) => Offset(c.x, c.y),
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
    return ClipRect(
      clipBehavior: Clip.none,
      child: MouseRegion(
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
                    path: widget.controller.path,
                    strokeColor: widget.strokeColor,
                    strokeWidth: widget.pathStrokeWidth,
                    blendMode: widget.blendMode,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: SegmentPainter(
                    widget.controller.operators,
                    _highlightedSegment,
                    _indicatorPosition,
                    highlightColor: widget.segmentHighligtColor,
                    blendMode: widget.blendMode,
                    segmentStrokeWidth: widget.pathStrokeWidth,
                    insertPointRadius: widget.insertPointRadius,
                    insertPointStrokeWidth: widget.insertPointStrokeWidth,
                    insertPointColor: widget.insertPointColor,
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
                    controlPointLineStrokeWidth:
                        widget.controlPointLineStrokeWidth,
                    controlPointLineColor: widget.controlPointLineColor,
                  ),
                ),
              ),
            ],
          ),
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
      widget.controlPointHitRadius,
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

    // Check if we are hovering over a point
    final nearestPointIndex =
        findNearestIndex(_points, localPosition, widget.pointHitRadius);
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

    // Find a segment we are hovering over
    final index = findClosestSegment(
      widget.controller.operators,
      details.localPosition,
      widget.minSegmentDistance,
    );
    final indicatorPosition = index == null
        ? null
        : calculateIndicatorPosition(
            widget.controller.operators,
            details.localPosition,
            index,
          );
    setState(() {
      _cursor = SystemMouseCursors.basic;
      _highlightedSegment = indicatorPosition != null ? index : null;
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
      widget.controller.updateControlPointPosition(
        _selectedControlPointIndex!,
        _selectedIndex!,
        details.localPosition,
      );
      setState(() {
        _rebuildPoints();
      });
    } else if (_selectedIndex != null) {
      widget.controller
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
        : widget.controller.controlPointsAt(_selectedIndex!);

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
      widget.controlPointHitRadius,
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
      widget.pointHitRadius,
    );

    // If we are not hitting a point, perhaps we are inserting a new point
    // in a segment
    if (point == null && _indicatorPosition != null) {
      final segment = _highlightedSegment;
      assert(segment != null,
          'Having an indicator should also have a segment that indicator applies to');

      widget.controller.insertPoint(segment!, localPosition);

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
