import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_editor/src/model/path_node.dart';

/// The shape used to draw a node or handle.
enum PathNodeShape {
  /// A filled or stroked circle.
  circle,

  /// An axis aligned square.
  square,

  /// A square rotated by 45 degrees.
  diamond,
}

/// How a single node or handle is drawn.
@immutable
class PathNodeStyle {
  /// The outline shape of the node.
  final PathNodeShape shape;

  /// Half the size of the node, in screen pixels.
  ///
  /// Node sizes are expressed in screen pixels so that they stay constant when
  /// the editor is zoomed.
  final double radius;

  /// The colour the interior is filled with.
  final Color fillColor;

  /// The colour of the outline.
  final Color borderColor;

  /// The width of the outline, in screen pixels. Set to zero to disable it.
  final double borderWidth;

  /// Creates a node style.
  const PathNodeStyle({
    required this.shape,
    required this.radius,
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1,
  });

  /// Returns a copy of this style with the given properties replaced.
  PathNodeStyle copyWith({
    PathNodeShape? shape,
    double? radius,
    Color? fillColor,
    Color? borderColor,
    double? borderWidth,
  }) =>
      PathNodeStyle(
        shape: shape ?? this.shape,
        radius: radius ?? this.radius,
        fillColor: fillColor ?? this.fillColor,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
      );

  /// Linearly interpolates between two node styles.
  static PathNodeStyle lerp(PathNodeStyle a, PathNodeStyle b, double t) =>
      PathNodeStyle(
        shape: t < 0.5 ? a.shape : b.shape,
        radius: lerpDouble(a.radius, b.radius, t)!,
        fillColor: Color.lerp(a.fillColor, b.fillColor, t)!,
        borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
        borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathNodeStyle &&
          shape == other.shape &&
          radius == other.radius &&
          fillColor == other.fillColor &&
          borderColor == other.borderColor &&
          borderWidth == other.borderWidth);

  @override
  int get hashCode =>
      Object.hash(shape, radius, fillColor, borderColor, borderWidth);
}

/// Everything the path editor needs to know about colours and sizes.
///
/// Every value is configurable; the defaults simply provide a neutral,
/// design-tool-like look. Sizes are expressed in screen pixels and are
/// therefore unaffected by the zoom level of the viewport.
@immutable
class PathEditorThemeData {
  /// The colour the path itself is stroked with.
  final Color strokeColor;

  /// The width the path itself is stroked with, in scene units.
  ///
  /// Unlike the editing chrome, the path stroke scales with the viewport
  /// because it is part of the artwork rather than part of the editor.
  final double strokeWidth;

  /// The colour of the active segment, the one that was created or selected
  /// last.
  final Color activeSegmentColor;

  /// The width of the active segment highlight, in screen pixels.
  final double activeSegmentWidth;

  /// The colour used to highlight the segment under the pointer.
  final Color hoveredSegmentColor;

  /// The width of the hovered segment highlight, in screen pixels.
  final double hoveredSegmentWidth;

  /// How an unselected corner node is drawn.
  final PathNodeStyle cornerNodeStyle;

  /// How an unselected smooth node is drawn.
  final PathNodeStyle smoothNodeStyle;

  /// The colours and size used for selected nodes. The shape is taken from the
  /// node type, so a selected corner node still looks like a corner.
  final PathNodeStyle selectedNodeStyle;

  /// The colours and size used for the node under the pointer.
  final PathNodeStyle hoveredNodeStyle;

  /// How a Bézier handle is drawn.
  final PathNodeStyle handleStyle;

  /// How the handle under the pointer is drawn.
  final PathNodeStyle hoveredHandleStyle;

  /// The colour of the line connecting a node to its handles.
  final Color handleLineColor;

  /// The width of the line connecting a node to its handles, in screen pixels.
  final double handleLineWidth;

  /// The colour of the indicator shown where a new node would be inserted.
  final Color insertIndicatorColor;

  /// The radius of the insert indicator, in screen pixels.
  final double insertIndicatorRadius;

  /// The stroke width of the insert indicator, in screen pixels.
  final double insertIndicatorWidth;

  /// The colour of the indicator shown when hovering the first node of an open
  /// path with the pen tool.
  final Color closeIndicatorColor;

  /// The radius of the close indicator, in screen pixels.
  final double closeIndicatorRadius;

  /// The stroke width of the close indicator, in screen pixels.
  final double closeIndicatorWidth;

  /// The colour of the rubber band drawn from the last node to the pointer
  /// while the pen tool is extending a path.
  final Color penPreviewColor;

  /// The width of the pen preview, in screen pixels.
  final double penPreviewWidth;

  /// The dash pattern of the pen preview, as alternating on/off lengths.
  /// An empty list draws a solid line.
  final List<double> penPreviewDashPattern;

  /// The colour of snapping guide lines.
  final Color snapGuideColor;

  /// The width of snapping guide lines, in screen pixels.
  final double snapGuideWidth;

  /// The dash pattern of snapping guide lines.
  final List<double> snapGuideDashPattern;

  /// The colour of the marker drawn on a snapped target.
  final Color snapTargetColor;

  /// The radius of the marker drawn on a snapped target, in screen pixels.
  final double snapTargetRadius;

  /// The blend mode used for every element the editor paints.
  final BlendMode blendMode;

  /// Creates a theme.
  const PathEditorThemeData({
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidth = 1,
    this.activeSegmentColor = _accent,
    this.activeSegmentWidth = 1,
    this.hoveredSegmentColor = _accentMuted,
    this.hoveredSegmentWidth = 1,
    this.cornerNodeStyle = const PathNodeStyle(
      shape: PathNodeShape.square,
      radius: 3.5,
      fillColor: _surface,
      borderColor: _accent,
    ),
    this.smoothNodeStyle = const PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 3.5,
      fillColor: _surface,
      borderColor: _accent,
    ),
    this.selectedNodeStyle = const PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4,
      fillColor: _accent,
      borderColor: _surface,
    ),
    this.hoveredNodeStyle = const PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4.5,
      fillColor: _surface,
      borderColor: _accent,
      borderWidth: 1.5,
    ),
    this.handleStyle = const PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 3,
      fillColor: _accent,
      borderColor: _surface,
      borderWidth: 0.5,
    ),
    this.hoveredHandleStyle = const PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4,
      fillColor: _accent,
      borderColor: _surface,
    ),
    this.handleLineColor = _accentMuted,
    this.handleLineWidth = 1,
    this.insertIndicatorColor = _accent,
    this.insertIndicatorRadius = 4,
    this.insertIndicatorWidth = 1.5,
    this.closeIndicatorColor = _accent,
    this.closeIndicatorRadius = 6.5,
    this.closeIndicatorWidth = 1.5,
    this.penPreviewColor = _accentMuted,
    this.penPreviewWidth = 1,
    this.penPreviewDashPattern = const [4, 3],
    this.snapGuideColor = const Color(0xFFFF3B7B),
    this.snapGuideWidth = 1,
    this.snapGuideDashPattern = const [3, 3],
    this.snapTargetColor = const Color(0xFFFF3B7B),
    this.snapTargetRadius = 3,
    this.blendMode = BlendMode.srcOver,
  });

  /// The default light theme, matching the constructor defaults.
  static const PathEditorThemeData light = PathEditorThemeData();

  /// A theme tuned for dark canvases.
  static const PathEditorThemeData dark = PathEditorThemeData(
    strokeColor: Color(0xFFFFFFFF),
    cornerNodeStyle: PathNodeStyle(
      shape: PathNodeShape.square,
      radius: 3.5,
      fillColor: Color(0xFF1E1E1E),
      borderColor: _accent,
    ),
    smoothNodeStyle: PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 3.5,
      fillColor: Color(0xFF1E1E1E),
      borderColor: _accent,
    ),
    selectedNodeStyle: PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4,
      fillColor: _accent,
      borderColor: Color(0xFF1E1E1E),
    ),
    hoveredNodeStyle: PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4.5,
      fillColor: Color(0xFF1E1E1E),
      borderColor: _accent,
      borderWidth: 1.5,
    ),
    handleStyle: PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 3,
      fillColor: _accent,
      borderColor: Color(0xFF1E1E1E),
      borderWidth: 0.5,
    ),
    hoveredHandleStyle: PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4,
      fillColor: _accent,
      borderColor: Color(0xFF1E1E1E),
    ),
  );

  /// Returns the style to draw a node of [type] with.
  ///
  /// [selected] takes precedence over [hovered]. The shape always follows the
  /// node type so that the two stay distinguishable in every state: nodes that
  /// enforce tangent continuity use [smoothNodeStyle], while corner nodes and
  /// nodes with broken handles - both of which produce a cusp - use
  /// [cornerNodeStyle].
  PathNodeStyle resolveNodeStyle(
    PathNodeType type, {
    bool selected = false,
    bool hovered = false,
  }) {
    final base = type.isSmooth ? smoothNodeStyle : cornerNodeStyle;
    if (selected) return selectedNodeStyle.copyWith(shape: base.shape);
    if (hovered) return hoveredNodeStyle.copyWith(shape: base.shape);
    return base;
  }

  /// Returns the style to draw a handle with.
  PathNodeStyle resolveHandleStyle({bool hovered = false}) =>
      hovered ? hoveredHandleStyle : handleStyle;

  /// Returns a copy of this theme with the given properties replaced.
  PathEditorThemeData copyWith({
    Color? strokeColor,
    double? strokeWidth,
    Color? activeSegmentColor,
    double? activeSegmentWidth,
    Color? hoveredSegmentColor,
    double? hoveredSegmentWidth,
    PathNodeStyle? cornerNodeStyle,
    PathNodeStyle? smoothNodeStyle,
    PathNodeStyle? selectedNodeStyle,
    PathNodeStyle? hoveredNodeStyle,
    PathNodeStyle? handleStyle,
    PathNodeStyle? hoveredHandleStyle,
    Color? handleLineColor,
    double? handleLineWidth,
    Color? insertIndicatorColor,
    double? insertIndicatorRadius,
    double? insertIndicatorWidth,
    Color? closeIndicatorColor,
    double? closeIndicatorRadius,
    double? closeIndicatorWidth,
    Color? penPreviewColor,
    double? penPreviewWidth,
    List<double>? penPreviewDashPattern,
    Color? snapGuideColor,
    double? snapGuideWidth,
    List<double>? snapGuideDashPattern,
    Color? snapTargetColor,
    double? snapTargetRadius,
    BlendMode? blendMode,
  }) =>
      PathEditorThemeData(
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        activeSegmentColor: activeSegmentColor ?? this.activeSegmentColor,
        activeSegmentWidth: activeSegmentWidth ?? this.activeSegmentWidth,
        hoveredSegmentColor: hoveredSegmentColor ?? this.hoveredSegmentColor,
        hoveredSegmentWidth: hoveredSegmentWidth ?? this.hoveredSegmentWidth,
        cornerNodeStyle: cornerNodeStyle ?? this.cornerNodeStyle,
        smoothNodeStyle: smoothNodeStyle ?? this.smoothNodeStyle,
        selectedNodeStyle: selectedNodeStyle ?? this.selectedNodeStyle,
        hoveredNodeStyle: hoveredNodeStyle ?? this.hoveredNodeStyle,
        handleStyle: handleStyle ?? this.handleStyle,
        hoveredHandleStyle: hoveredHandleStyle ?? this.hoveredHandleStyle,
        handleLineColor: handleLineColor ?? this.handleLineColor,
        handleLineWidth: handleLineWidth ?? this.handleLineWidth,
        insertIndicatorColor: insertIndicatorColor ?? this.insertIndicatorColor,
        insertIndicatorRadius:
            insertIndicatorRadius ?? this.insertIndicatorRadius,
        insertIndicatorWidth: insertIndicatorWidth ?? this.insertIndicatorWidth,
        closeIndicatorColor: closeIndicatorColor ?? this.closeIndicatorColor,
        closeIndicatorRadius: closeIndicatorRadius ?? this.closeIndicatorRadius,
        closeIndicatorWidth: closeIndicatorWidth ?? this.closeIndicatorWidth,
        penPreviewColor: penPreviewColor ?? this.penPreviewColor,
        penPreviewWidth: penPreviewWidth ?? this.penPreviewWidth,
        penPreviewDashPattern:
            penPreviewDashPattern ?? this.penPreviewDashPattern,
        snapGuideColor: snapGuideColor ?? this.snapGuideColor,
        snapGuideWidth: snapGuideWidth ?? this.snapGuideWidth,
        snapGuideDashPattern: snapGuideDashPattern ?? this.snapGuideDashPattern,
        snapTargetColor: snapTargetColor ?? this.snapTargetColor,
        snapTargetRadius: snapTargetRadius ?? this.snapTargetRadius,
        blendMode: blendMode ?? this.blendMode,
      );

  /// Linearly interpolates between two themes.
  static PathEditorThemeData lerp(
    PathEditorThemeData a,
    PathEditorThemeData b,
    double t,
  ) =>
      PathEditorThemeData(
        strokeColor: Color.lerp(a.strokeColor, b.strokeColor, t)!,
        strokeWidth: lerpDouble(a.strokeWidth, b.strokeWidth, t)!,
        activeSegmentColor:
            Color.lerp(a.activeSegmentColor, b.activeSegmentColor, t)!,
        activeSegmentWidth:
            lerpDouble(a.activeSegmentWidth, b.activeSegmentWidth, t)!,
        hoveredSegmentColor:
            Color.lerp(a.hoveredSegmentColor, b.hoveredSegmentColor, t)!,
        hoveredSegmentWidth:
            lerpDouble(a.hoveredSegmentWidth, b.hoveredSegmentWidth, t)!,
        cornerNodeStyle:
            PathNodeStyle.lerp(a.cornerNodeStyle, b.cornerNodeStyle, t),
        smoothNodeStyle:
            PathNodeStyle.lerp(a.smoothNodeStyle, b.smoothNodeStyle, t),
        selectedNodeStyle:
            PathNodeStyle.lerp(a.selectedNodeStyle, b.selectedNodeStyle, t),
        hoveredNodeStyle:
            PathNodeStyle.lerp(a.hoveredNodeStyle, b.hoveredNodeStyle, t),
        handleStyle: PathNodeStyle.lerp(a.handleStyle, b.handleStyle, t),
        hoveredHandleStyle:
            PathNodeStyle.lerp(a.hoveredHandleStyle, b.hoveredHandleStyle, t),
        handleLineColor: Color.lerp(a.handleLineColor, b.handleLineColor, t)!,
        handleLineWidth: lerpDouble(a.handleLineWidth, b.handleLineWidth, t)!,
        insertIndicatorColor:
            Color.lerp(a.insertIndicatorColor, b.insertIndicatorColor, t)!,
        insertIndicatorRadius:
            lerpDouble(a.insertIndicatorRadius, b.insertIndicatorRadius, t)!,
        insertIndicatorWidth:
            lerpDouble(a.insertIndicatorWidth, b.insertIndicatorWidth, t)!,
        closeIndicatorColor:
            Color.lerp(a.closeIndicatorColor, b.closeIndicatorColor, t)!,
        closeIndicatorRadius:
            lerpDouble(a.closeIndicatorRadius, b.closeIndicatorRadius, t)!,
        closeIndicatorWidth:
            lerpDouble(a.closeIndicatorWidth, b.closeIndicatorWidth, t)!,
        penPreviewColor: Color.lerp(a.penPreviewColor, b.penPreviewColor, t)!,
        penPreviewWidth: lerpDouble(a.penPreviewWidth, b.penPreviewWidth, t)!,
        penPreviewDashPattern:
            t < 0.5 ? a.penPreviewDashPattern : b.penPreviewDashPattern,
        snapGuideColor: Color.lerp(a.snapGuideColor, b.snapGuideColor, t)!,
        snapGuideWidth: lerpDouble(a.snapGuideWidth, b.snapGuideWidth, t)!,
        snapGuideDashPattern:
            t < 0.5 ? a.snapGuideDashPattern : b.snapGuideDashPattern,
        snapTargetColor: Color.lerp(a.snapTargetColor, b.snapTargetColor, t)!,
        snapTargetRadius:
            lerpDouble(a.snapTargetRadius, b.snapTargetRadius, t)!,
        blendMode: t < 0.5 ? a.blendMode : b.blendMode,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorThemeData &&
          strokeColor == other.strokeColor &&
          strokeWidth == other.strokeWidth &&
          activeSegmentColor == other.activeSegmentColor &&
          activeSegmentWidth == other.activeSegmentWidth &&
          hoveredSegmentColor == other.hoveredSegmentColor &&
          hoveredSegmentWidth == other.hoveredSegmentWidth &&
          cornerNodeStyle == other.cornerNodeStyle &&
          smoothNodeStyle == other.smoothNodeStyle &&
          selectedNodeStyle == other.selectedNodeStyle &&
          hoveredNodeStyle == other.hoveredNodeStyle &&
          handleStyle == other.handleStyle &&
          hoveredHandleStyle == other.hoveredHandleStyle &&
          handleLineColor == other.handleLineColor &&
          handleLineWidth == other.handleLineWidth &&
          insertIndicatorColor == other.insertIndicatorColor &&
          insertIndicatorRadius == other.insertIndicatorRadius &&
          insertIndicatorWidth == other.insertIndicatorWidth &&
          closeIndicatorColor == other.closeIndicatorColor &&
          closeIndicatorRadius == other.closeIndicatorRadius &&
          closeIndicatorWidth == other.closeIndicatorWidth &&
          penPreviewColor == other.penPreviewColor &&
          penPreviewWidth == other.penPreviewWidth &&
          listEquals(penPreviewDashPattern, other.penPreviewDashPattern) &&
          snapGuideColor == other.snapGuideColor &&
          snapGuideWidth == other.snapGuideWidth &&
          listEquals(snapGuideDashPattern, other.snapGuideDashPattern) &&
          snapTargetColor == other.snapTargetColor &&
          snapTargetRadius == other.snapTargetRadius &&
          blendMode == other.blendMode);

  @override
  int get hashCode => Object.hashAll([
        strokeColor,
        strokeWidth,
        activeSegmentColor,
        activeSegmentWidth,
        hoveredSegmentColor,
        hoveredSegmentWidth,
        cornerNodeStyle,
        smoothNodeStyle,
        selectedNodeStyle,
        hoveredNodeStyle,
        handleStyle,
        hoveredHandleStyle,
        handleLineColor,
        handleLineWidth,
        insertIndicatorColor,
        insertIndicatorRadius,
        insertIndicatorWidth,
        closeIndicatorColor,
        closeIndicatorRadius,
        closeIndicatorWidth,
        penPreviewColor,
        penPreviewWidth,
        Object.hashAll(penPreviewDashPattern),
        snapGuideColor,
        snapGuideWidth,
        Object.hashAll(snapGuideDashPattern),
        snapTargetColor,
        snapTargetRadius,
        blendMode,
      ]);

  static const Color _accent = Color(0xFF4E80F9);
  static const Color _accentMuted = Color(0x994E80F9);
  static const Color _surface = Color(0xFFFFFFFF);
}

/// Provides a [PathEditorThemeData] to the editors below it in the tree.
///
/// Editors that are not given an explicit theme look one up with
/// [PathEditorTheme.of], falling back to [PathEditorThemeData.light].
class PathEditorTheme extends InheritedWidget {
  /// The theme to apply to descendant editors.
  final PathEditorThemeData data;

  /// Creates a theme scope.
  const PathEditorTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme from the closest enclosing [PathEditorTheme], or
  /// [PathEditorThemeData.light] when there is none.
  static PathEditorThemeData of(BuildContext context) =>
      maybeOf(context) ?? PathEditorThemeData.light;

  /// The theme from the closest enclosing [PathEditorTheme], or `null`.
  static PathEditorThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PathEditorTheme>()?.data;

  @override
  bool updateShouldNotify(PathEditorTheme oldWidget) => data != oldWidget.data;
}
