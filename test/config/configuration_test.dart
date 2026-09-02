import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void _onPathChanged(EditablePath path) {}

void _onSelectionChanged(PathEditorSelection selection) {}

void _onToolChanged(PathTool tool) {}

void _onNodeAdded(NodeRef node) {}

void _onNodesRemoved(Iterable<NodeRef> nodes) {}

void _onSegmentCreated(SegmentRef segment) {}

void _onSubpathClosed(int subpath) {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PathEditorBehavior', () {
    test('copies, compares and hashes every setting', () {
      const behavior = PathEditorBehavior(
        nodeHitRadius: 1,
        handleHitRadius: 2,
        segmentHitDistance: 3,
        smoothPointDragThreshold: 4,
        dragThreshold: 5,
        selectOnCreate: false,
        clearSelectionOnBackgroundTap: false,
        insertOnSegmentClick: false,
        closeOnFirstNodeClick: false,
        allowMultipleSubpaths: false,
        nudgeDistance: 6,
        largeNudgeDistance: 7,
      );

      final copy = behavior.copyWith(
        nodeHitRadius: 11,
        handleHitRadius: 12,
        segmentHitDistance: 13,
        smoothPointDragThreshold: 14,
        dragThreshold: 15,
        selectOnCreate: true,
        clearSelectionOnBackgroundTap: true,
        insertOnSegmentClick: true,
        closeOnFirstNodeClick: true,
        allowMultipleSubpaths: true,
        nudgeDistance: 16,
        largeNudgeDistance: 17,
      );

      expect(copy.nodeHitRadius, 11);
      expect(copy.handleHitRadius, 12);
      expect(copy.segmentHitDistance, 13);
      expect(copy.smoothPointDragThreshold, 14);
      expect(copy.dragThreshold, 15);
      expect(copy.selectOnCreate, isTrue);
      expect(copy.clearSelectionOnBackgroundTap, isTrue);
      expect(copy.insertOnSegmentClick, isTrue);
      expect(copy.closeOnFirstNodeClick, isTrue);
      expect(copy.allowMultipleSubpaths, isTrue);
      expect(copy.nudgeDistance, 16);
      expect(copy.largeNudgeDistance, 17);
      expect(behavior.copyWith(), behavior);
      expect(behavior.hashCode, behavior.copyWith().hashCode);
      expect(behavior == Object(), isFalse);
      expect(PathEditorBehavior.defaults, const PathEditorBehavior());
    });
  });

  group('PathEditorCallbacks', () {
    test('copies, compares and hashes every callback', () {
      const callbacks = PathEditorCallbacks(
        onPathChanged: _onPathChanged,
        onSelectionChanged: _onSelectionChanged,
        onToolChanged: _onToolChanged,
        onNodeAdded: _onNodeAdded,
        onNodesRemoved: _onNodesRemoved,
        onSegmentCreated: _onSegmentCreated,
        onSubpathClosed: _onSubpathClosed,
      );

      final copy = callbacks.copyWith(
        onPathChanged: (_) {},
        onSelectionChanged: (_) {},
        onToolChanged: (_) {},
        onNodeAdded: (_) {},
        onNodesRemoved: (_) {},
        onSegmentCreated: (_) {},
        onSubpathClosed: (_) {},
      );

      expect(copy.onPathChanged, isNotNull);
      expect(copy.onSelectionChanged, isNotNull);
      expect(copy.onToolChanged, isNotNull);
      expect(copy.onNodeAdded, isNotNull);
      expect(copy.onNodesRemoved, isNotNull);
      expect(copy.onSegmentCreated, isNotNull);
      expect(copy.onSubpathClosed, isNotNull);
      expect(callbacks.copyWith(), callbacks);
      expect(callbacks.hashCode, callbacks.copyWith().hashCode);
      expect(callbacks == Object(), isFalse);
      expect(PathEditorCallbacks.none, const PathEditorCallbacks());
    });
  });

  group('PathEditorCursors', () {
    test('resolves all states and copies every cursor', () {
      const cursors = PathEditorCursors(
        idle: SystemMouseCursors.click,
        selectPoint: SystemMouseCursors.grab,
        movePoint: SystemMouseCursors.grabbing,
        addPoint: SystemMouseCursors.basic,
        removePoint: SystemMouseCursors.precise,
        closePath: SystemMouseCursors.disappearing,
        adjustHandle: SystemMouseCursors.precise,
        penReady: SystemMouseCursors.grab,
        penDraw: SystemMouseCursors.click,
      );

      expect(cursors.resolve(PathEditorCursorState.idle), cursors.idle);
      expect(
        cursors.resolve(PathEditorCursorState.selectPoint),
        cursors.selectPoint,
      );
      expect(
          cursors.resolve(PathEditorCursorState.movePoint), cursors.movePoint);
      expect(cursors.resolve(PathEditorCursorState.addPoint), cursors.addPoint);
      expect(
        cursors.resolve(PathEditorCursorState.removePoint),
        cursors.removePoint,
      );
      expect(
          cursors.resolve(PathEditorCursorState.closePath), cursors.closePath);
      expect(
        cursors.resolve(PathEditorCursorState.adjustHandle),
        cursors.adjustHandle,
      );
      expect(cursors.resolve(PathEditorCursorState.penReady), cursors.penReady);
      expect(cursors.resolve(PathEditorCursorState.penDraw), cursors.penDraw);

      final copy = cursors.copyWith(
        idle: SystemMouseCursors.basic,
        selectPoint: SystemMouseCursors.basic,
        movePoint: SystemMouseCursors.basic,
        addPoint: SystemMouseCursors.basic,
        removePoint: SystemMouseCursors.basic,
        closePath: SystemMouseCursors.basic,
        adjustHandle: SystemMouseCursors.basic,
        penReady: SystemMouseCursors.basic,
        penDraw: SystemMouseCursors.basic,
      );
      expect(
        copy,
        const PathEditorCursors(
          selectPoint: SystemMouseCursors.basic,
          movePoint: SystemMouseCursors.basic,
          addPoint: SystemMouseCursors.basic,
          removePoint: SystemMouseCursors.basic,
          closePath: SystemMouseCursors.basic,
          adjustHandle: SystemMouseCursors.basic,
          penReady: SystemMouseCursors.basic,
          penDraw: SystemMouseCursors.basic,
        ),
      );
      expect(cursors.copyWith(), cursors);
      expect(cursors.hashCode, cursors.copyWith().hashCode);
      expect(cursors == Object(), isFalse);
    });
  });

  group('PathEditorModifiers', () {
    test('evaluates custom modifiers and copies every mapping', () {
      const always = KeyModifier.custom('always', _always);
      const never = KeyModifier.custom('never', _never);
      expect(always.isActive(), isTrue);
      expect(never.isActive(), isFalse);
      expect(always.toString(), 'KeyModifier.always');
      expect(always == KeyModifier.none, isFalse);

      const modifiers = PathEditorModifiers(
        multiSelect: always,
        breakHandle: never,
        bendPoint: always,
        disableSnapping: never,
        constrainAngle: always,
        removeNode: never,
        cutPath: always,
      );
      final copy = modifiers.copyWith(
        multiSelect: KeyModifier.none,
        breakHandle: KeyModifier.shift,
        bendPoint: KeyModifier.alt,
        disableSnapping: KeyModifier.control,
        constrainAngle: KeyModifier.meta,
        removeNode: KeyModifier.controlOrMeta,
        cutPath: KeyModifier.shift,
      );

      expect(copy.multiSelect, KeyModifier.none);
      expect(copy.breakHandle, KeyModifier.shift);
      expect(copy.bendPoint, KeyModifier.alt);
      expect(copy.disableSnapping, KeyModifier.control);
      expect(copy.constrainAngle, KeyModifier.meta);
      expect(copy.removeNode, KeyModifier.controlOrMeta);
      expect(copy.cutPath, KeyModifier.shift);
      expect(modifiers.copyWith(), modifiers);
      expect(modifiers.hashCode, modifiers.copyWith().hashCode);
      expect(modifiers == Object(), isFalse);
      expect(PathEditorModifiers.defaults, const PathEditorModifiers());
    });
  });

  group('PathEditorSnapping', () {
    test('copies, compares and hashes every setting', () {
      const snapping = PathEditorSnapping(
        enabled: false,
        snapToNodes: false,
        snapToMidpoints: false,
        snapToAxes: false,
        threshold: 1,
        angleIncrement: 2,
      );
      final copy = snapping.copyWith(
        enabled: true,
        snapToNodes: true,
        snapToMidpoints: true,
        snapToAxes: true,
        threshold: 3,
        angleIncrement: 4,
      );

      expect(copy.enabled, isTrue);
      expect(copy.snapToNodes, isTrue);
      expect(copy.snapToMidpoints, isTrue);
      expect(copy.snapToAxes, isTrue);
      expect(copy.threshold, 3);
      expect(copy.angleIncrement, 4);
      expect(snapping.copyWith(), snapping);
      expect(snapping.hashCode, snapping.copyWith().hashCode);
      expect(snapping == Object(), isFalse);
      expect(PathEditorSnapping.disabled.enabled, isFalse);
      expect(PathEditorSnapping.defaults, const PathEditorSnapping());
    });
  });

  group('PathNodeStyle and PathEditorThemeData', () {
    const corner = PathNodeStyle(
      shape: PathNodeShape.square,
      radius: 2,
      fillColor: Color(0xFF112233),
      borderColor: Color(0xFF445566),
    );
    const smooth = PathNodeStyle(
      shape: PathNodeShape.circle,
      radius: 4,
      fillColor: Color(0xFF334455),
      borderColor: Color(0xFF667788),
      borderWidth: 3,
    );

    test('copies, interpolates and compares node styles', () {
      final copy = corner.copyWith(
        shape: PathNodeShape.diamond,
        radius: 5,
        fillColor: const Color(0xFF000000),
        borderColor: const Color(0xFFFFFFFF),
        borderWidth: 6,
      );

      expect(copy.shape, PathNodeShape.diamond);
      expect(copy.radius, 5);
      expect(copy.fillColor, const Color(0xFF000000));
      expect(copy.borderColor, const Color(0xFFFFFFFF));
      expect(copy.borderWidth, 6);
      expect(PathNodeStyle.lerp(corner, smooth, 0), corner);
      expect(PathNodeStyle.lerp(corner, smooth, 1), smooth);
      expect(corner.hashCode, corner.copyWith().hashCode);
      expect(corner == Object(), isFalse);
    });

    test('resolves states and copies every theme property', () {
      const theme = PathEditorThemeData(
        strokeColor: Color(0xFF010203),
        strokeWidth: 2,
        activeSegmentColor: Color(0xFF040506),
        activeSegmentWidth: 3,
        hoveredSegmentColor: Color(0xFF070809),
        hoveredSegmentWidth: 4,
        cornerNodeStyle: corner,
        smoothNodeStyle: smooth,
        selectedNodeStyle: corner,
        hoveredNodeStyle: smooth,
        handleStyle: corner,
        hoveredHandleStyle: smooth,
        handleLineColor: Color(0xFF0A0B0C),
        handleLineWidth: 5,
        insertIndicatorColor: Color(0xFF0D0E0F),
        insertIndicatorRadius: 6,
        insertIndicatorWidth: 7,
        closeIndicatorColor: Color(0xFF101112),
        closeIndicatorRadius: 8,
        closeIndicatorWidth: 9,
        penPreviewColor: Color(0xFF131415),
        penPreviewWidth: 10,
        penPreviewDashPattern: [1, 2],
        snapGuideColor: Color(0xFF161718),
        snapGuideWidth: 11,
        snapGuideDashPattern: [3, 4],
        snapTargetColor: Color(0xFF192021),
        snapTargetRadius: 12,
        blendMode: BlendMode.multiply,
      );

      expect(theme.resolveNodeStyle(PathNodeType.corner), corner);
      expect(
        theme.resolveNodeStyle(PathNodeType.mirrored),
        smooth,
      );
      expect(
        theme.resolveNodeStyle(PathNodeType.corner, selected: true).shape,
        corner.shape,
      );
      expect(
        theme.resolveNodeStyle(PathNodeType.mirrored, selected: true).shape,
        smooth.shape,
      );
      expect(
        theme.resolveNodeStyle(PathNodeType.corner, hovered: true).shape,
        corner.shape,
      );
      expect(theme.resolveHandleStyle(), corner);
      expect(theme.resolveHandleStyle(hovered: true), smooth);

      const replacement = PathNodeStyle(
        shape: PathNodeShape.diamond,
        radius: 20,
        fillColor: Color(0xFFABCDEF),
        borderColor: Color(0xFFFEDCBA),
        borderWidth: 21,
      );
      final copy = theme.copyWith(
        strokeColor: const Color(0xFF222222),
        strokeWidth: 22,
        activeSegmentColor: const Color(0xFF232323),
        activeSegmentWidth: 23,
        hoveredSegmentColor: const Color(0xFF242424),
        hoveredSegmentWidth: 24,
        cornerNodeStyle: replacement,
        smoothNodeStyle: replacement,
        selectedNodeStyle: replacement,
        hoveredNodeStyle: replacement,
        handleStyle: replacement,
        hoveredHandleStyle: replacement,
        handleLineColor: const Color(0xFF252525),
        handleLineWidth: 25,
        insertIndicatorColor: const Color(0xFF262626),
        insertIndicatorRadius: 26,
        insertIndicatorWidth: 27,
        closeIndicatorColor: const Color(0xFF282828),
        closeIndicatorRadius: 28,
        closeIndicatorWidth: 29,
        penPreviewColor: const Color(0xFF292929),
        penPreviewWidth: 30,
        penPreviewDashPattern: const [5, 6],
        snapGuideColor: const Color(0xFF303030),
        snapGuideWidth: 31,
        snapGuideDashPattern: const [7, 8],
        snapTargetColor: const Color(0xFF313131),
        snapTargetRadius: 32,
        blendMode: BlendMode.screen,
      );

      expect(copy.strokeColor, const Color(0xFF222222));
      expect(copy.cornerNodeStyle, replacement);
      expect(copy.penPreviewDashPattern, [5, 6]);
      expect(copy.snapGuideDashPattern, [7, 8]);
      expect(copy.blendMode, BlendMode.screen);
      expect(theme.copyWith(), theme);
      expect(theme.hashCode, theme.copyWith().hashCode);
      expect(theme == Object(), isFalse);
    });

    test('interpolates both sides of discrete theme properties', () {
      final early = PathEditorThemeData.lerp(
        PathEditorThemeData.light,
        PathEditorThemeData.dark,
        0.25,
      );
      final late = PathEditorThemeData.lerp(
        PathEditorThemeData.light,
        PathEditorThemeData.dark,
        0.75,
      );

      expect(early.penPreviewDashPattern,
          PathEditorThemeData.light.penPreviewDashPattern);
      expect(late.penPreviewDashPattern,
          PathEditorThemeData.dark.penPreviewDashPattern);
      expect(early.snapGuideDashPattern,
          PathEditorThemeData.light.snapGuideDashPattern);
      expect(late.snapGuideDashPattern,
          PathEditorThemeData.dark.snapGuideDashPattern);
      expect(early.blendMode, PathEditorThemeData.light.blendMode);
      expect(late.blendMode, PathEditorThemeData.dark.blendMode);
    });
  });

  group('PathEditorViewport', () {
    test('converts coordinates, pans, zooms and applies transforms', () {
      const viewport = PathEditorViewport(offset: Offset(10, 20), scale: 2);
      expect(viewport.toScene(const Offset(14, 24)), const Offset(2, 2));
      expect(viewport.toScreen(const Offset(2, 2)), const Offset(14, 24));
      expect(viewport.toSceneDistance(10), 5);
      expect(viewport.toScreenDistance(5), 10);
      expect(viewport.copyWith(), viewport);
      expect(viewport.panned(const Offset(3, 4)).offset, const Offset(13, 24));
      expect(
        viewport
            .zoomedAround(const Offset(14, 24), 4)
            .toScreen(const Offset(2, 2)),
        const Offset(14, 24),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      PathEditorViewport.identity.applyTo(canvas);
      viewport.applyTo(canvas);
      recorder.endRecording().dispose();

      expect(viewport.toString(),
          'PathEditorViewport(offset: Offset(10.0, 20.0), scale: 2.0)');
      expect(viewport.hashCode, viewport.copyWith().hashCode);
      expect(viewport == Object(), isFalse);
      expect(PathEditorViewport.identity, const PathEditorViewport());
    });
  });
}

bool _always(HardwareKeyboard keyboard) => true;

bool _never(HardwareKeyboard keyboard) => false;
