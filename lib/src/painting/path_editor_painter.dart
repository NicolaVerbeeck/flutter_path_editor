import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_editor/src/config/path_editor_snapping.dart';
import 'package:path_editor/src/config/path_editor_theme.dart';
import 'package:path_editor/src/config/path_editor_viewport.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_node.dart';
import 'package:path_editor/src/model/path_segment.dart';

/// Paints the path together with all of the editing chrome.
///
/// Everything except the path stroke itself is drawn in screen space, so
/// nodes, handles and indicators keep a constant size regardless of the zoom
/// level of the [viewport].
class PathEditorPainter extends CustomPainter {
  /// The path to paint.
  final EditablePath path;

  /// The current selection, deciding which nodes show their handles.
  final PathEditorSelection selection;

  /// The colours and sizes to paint with.
  final PathEditorThemeData theme;

  /// The viewport mapping scene coordinates onto the canvas.
  final PathEditorViewport viewport;

  /// The segment to highlight as active, if any.
  final SegmentRef? activeSegment;

  /// The segment under the pointer, if any.
  final SegmentRef? hoveredSegment;

  /// The node under the pointer, if any.
  final NodeRef? hoveredNode;

  /// The handle under the pointer, if any.
  final HandleRef? hoveredHandle;

  /// Where a node would be inserted, in scene coordinates.
  final Offset? insertIndicator;

  /// Where the path would be closed, in scene coordinates.
  final Offset? closeIndicator;

  /// The node the pen tool would draw its next segment from.
  final Offset? penAnchor;

  /// The pointer position in scene coordinates.
  final Offset? pointer;

  /// The snap guides to draw.
  final List<SnapGuide> snapGuides;

  /// Creates a painter.
  const PathEditorPainter({
    required this.path,
    required this.selection,
    required this.theme,
    required this.viewport,
    this.activeSegment,
    this.hoveredSegment,
    this.hoveredNode,
    this.hoveredHandle,
    this.insertIndicator,
    this.closeIndicator,
    this.penAnchor,
    this.pointer,
    this.snapGuides = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintPath(canvas);
    _paintSegmentHighlights(canvas);
    _paintSnapGuides(canvas);
    _paintPenPreview(canvas);
    _paintHandles(canvas);
    _paintNodes(canvas);
    _paintIndicators(canvas);
  }

  void _paintPath(Canvas canvas) {
    if (path.isEmpty || theme.strokeWidth <= 0) return;

    canvas.save();
    viewport.applyTo(canvas);
    canvas.drawPath(
      path.toUiPath(),
      Paint()
        ..color = theme.strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.strokeWidth
        ..blendMode = theme.blendMode,
    );
    canvas.restore();
  }

  void _paintSegmentHighlights(Canvas canvas) {
    final hovered = hoveredSegment;
    if (hovered != null &&
        hovered != activeSegment &&
        path.containsSegment(hovered)) {
      _strokeSegment(
        canvas,
        path.segmentAt(hovered),
        theme.hoveredSegmentColor,
        theme.hoveredSegmentWidth,
      );
    }

    final active = activeSegment;
    if (active != null && path.containsSegment(active)) {
      _strokeSegment(
        canvas,
        path.segmentAt(active),
        theme.activeSegmentColor,
        theme.activeSegmentWidth,
      );
    }
  }

  void _strokeSegment(
    Canvas canvas,
    PathSegment segment,
    Color color,
    double width,
  ) {
    if (width <= 0) return;

    final start = viewport.toScreen(segment.start);
    final screenPath = Path()..moveTo(start.dx, start.dy);
    if (segment.isCurve) {
      final control1 = viewport.toScreen(segment.control1);
      final control2 = viewport.toScreen(segment.control2);
      final end = viewport.toScreen(segment.end);
      screenPath.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    } else {
      final end = viewport.toScreen(segment.end);
      screenPath.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(
      screenPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..blendMode = theme.blendMode,
    );
  }

  void _paintSnapGuides(Canvas canvas) {
    if (snapGuides.isEmpty) return;

    final linePaint = Paint()
      ..color = theme.snapGuideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.snapGuideWidth
      ..blendMode = theme.blendMode;

    for (final guide in snapGuides) {
      if (guide.isPoint) {
        final center = viewport.toScreen(guide.start);
        canvas.drawCircle(
          center,
          theme.snapTargetRadius,
          Paint()
            ..color = theme.snapTargetColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = theme.snapGuideWidth
            ..blendMode = theme.blendMode,
        );
        continue;
      }

      _drawDashedLine(
        canvas,
        viewport.toScreen(guide.start),
        viewport.toScreen(guide.end),
        linePaint,
        theme.snapGuideDashPattern,
      );
    }
  }

  void _paintPenPreview(Canvas canvas) {
    final anchor = penAnchor;
    final target = pointer;
    if (anchor == null || target == null || theme.penPreviewWidth <= 0) return;

    _drawDashedLine(
      canvas,
      viewport.toScreen(anchor),
      viewport.toScreen(target),
      Paint()
        ..color = theme.penPreviewColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.penPreviewWidth
        ..blendMode = theme.blendMode,
      theme.penPreviewDashPattern,
    );
  }

  void _paintHandles(Canvas canvas) {
    if (selection.isEmpty) return;

    final linePaint = Paint()
      ..color = theme.handleLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.handleLineWidth
      ..blendMode = theme.blendMode;

    for (final ref in selection.nodes) {
      if (!path.contains(ref)) continue;
      final node = path.nodeAt(ref);
      final anchor = viewport.toScreen(node.position);

      for (final which in NodeHandle.values) {
        final handle = node.handle(which);
        if (handle == null) continue;

        final position = viewport.toScreen(handle);
        canvas.drawLine(anchor, position, linePaint);
        _drawShape(
          canvas,
          position,
          theme.resolveHandleStyle(
            hovered: hoveredHandle == HandleRef(ref, which),
          ),
        );
      }
    }
  }

  void _paintNodes(Canvas canvas) {
    for (final ref in path.nodeRefs) {
      final node = path.nodeAt(ref);
      _drawShape(
        canvas,
        viewport.toScreen(node.position),
        theme.resolveNodeStyle(
          node.type,
          selected: selection.contains(ref),
          hovered: hoveredNode == ref,
        ),
      );
    }
  }

  void _paintIndicators(Canvas canvas) {
    final insert = insertIndicator;
    if (insert != null) {
      final center = viewport.toScreen(insert);
      final paint = Paint()
        ..color = theme.insertIndicatorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.insertIndicatorWidth
        ..blendMode = theme.blendMode;

      canvas.drawCircle(center, theme.insertIndicatorRadius, paint);
      // A small plus sign makes the "add point" affordance unmistakable.
      final arm = theme.insertIndicatorRadius / 2;
      canvas.drawLine(
        center - Offset(arm, 0),
        center + Offset(arm, 0),
        paint,
      );
      canvas.drawLine(
        center - Offset(0, arm),
        center + Offset(0, arm),
        paint,
      );
    }

    final close = closeIndicator;
    if (close != null) {
      canvas.drawCircle(
        viewport.toScreen(close),
        theme.closeIndicatorRadius,
        Paint()
          ..color = theme.closeIndicatorColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = theme.closeIndicatorWidth
          ..blendMode = theme.blendMode,
      );
    }
  }

  void _drawShape(Canvas canvas, Offset center, PathNodeStyle style) {
    final fill = Paint()
      ..color = style.fillColor
      ..style = PaintingStyle.fill
      ..blendMode = theme.blendMode;
    final border = style.borderWidth <= 0
        ? null
        : (Paint()
          ..color = style.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.borderWidth
          ..blendMode = theme.blendMode);

    switch (style.shape) {
      case PathNodeShape.circle:
        canvas.drawCircle(center, style.radius, fill);
        if (border != null) canvas.drawCircle(center, style.radius, border);
      case PathNodeShape.square:
        final rect = Rect.fromCenter(
          center: center,
          width: style.radius * 2,
          height: style.radius * 2,
        );
        canvas.drawRect(rect, fill);
        if (border != null) canvas.drawRect(rect, border);
      case PathNodeShape.diamond:
        final diamond = Path()
          ..moveTo(center.dx, center.dy - style.radius)
          ..lineTo(center.dx + style.radius, center.dy)
          ..lineTo(center.dx, center.dy + style.radius)
          ..lineTo(center.dx - style.radius, center.dy)
          ..close();
        canvas.drawPath(diamond, fill);
        if (border != null) canvas.drawPath(diamond, border);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    List<double> pattern,
  ) {
    if (pattern.isEmpty) {
      canvas.drawLine(start, end, paint);
      return;
    }

    final total = (end - start).distance;
    if (total == 0) return;

    final direction = (end - start) / total;
    var travelled = 0.0;
    var index = 0;
    while (travelled < total) {
      final length = pattern[index % pattern.length];
      final next = math.min(travelled + length, total);
      if (index.isEven) {
        canvas.drawLine(
          start + direction * travelled,
          start + direction * next,
          paint,
        );
      }
      travelled = next;
      index++;
      if (length <= 0) break;
    }
  }

  @override
  bool shouldRepaint(PathEditorPainter oldDelegate) =>
      path != oldDelegate.path ||
      selection != oldDelegate.selection ||
      theme != oldDelegate.theme ||
      viewport != oldDelegate.viewport ||
      activeSegment != oldDelegate.activeSegment ||
      hoveredSegment != oldDelegate.hoveredSegment ||
      hoveredNode != oldDelegate.hoveredNode ||
      hoveredHandle != oldDelegate.hoveredHandle ||
      insertIndicator != oldDelegate.insertIndicator ||
      closeIndicator != oldDelegate.closeIndicator ||
      penAnchor != oldDelegate.penAnchor ||
      pointer != oldDelegate.pointer ||
      !listEquals(snapGuides, oldDelegate.snapGuides);
}
