import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

/// A modifier that is always considered held down, so tests can exercise the
/// modifier driven behaviours without touching the hardware keyboard.
final KeyModifier alwaysHeld = KeyModifier.custom('always', (_) => true);

PathEditorToolHandler handlerFor(
  PathEditorController controller, {
  PathEditorModifiers? modifiers,
  PathEditorSnapping snapping = PathEditorSnapping.disabled,
  PathEditorBehavior behavior = PathEditorBehavior.defaults,
  PathEditorViewport viewport = PathEditorViewport.identity,
  PathEditorCallbacks callbacks = PathEditorCallbacks.none,
}) =>
    PathEditorToolHandler(
      controller: controller,
      modifiers: modifiers ?? const PathEditorModifiers(),
      snapping: snapping,
      behavior: behavior,
      viewport: viewport,
      callbacks: callbacks,
    );

extension on PathEditorToolHandler {
  /// Presses and releases the pointer at [position] without moving.
  void click(Offset position) {
    handlePointerDown(position);
    handlePointerUp(position);
  }

  /// Presses at [from], drags to [to] and releases.
  void drag(Offset from, Offset to) {
    handlePointerDown(from);
    handlePointerMove(to);
    handlePointerUp(to);
  }
}

void main() {
  // Modifier lookups go through HardwareKeyboard, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pen tool', () {
    test('the first click starts a path with a single corner node', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));

      expect(controller.path.nodeCount, 1);
      expect(controller.path.nodeAt(const NodeRef(0, 0)).position,
          const Offset(10, 10));
      expect(controller.path.nodeAt(const NodeRef(0, 0)).type,
          PathNodeType.corner);
      expect(controller.svg, 'M10.0 10.0');
      expect(handler.activeSegment, isNull);
    });

    test('a second click creates a straight segment', () {
      final controller = PathEditorController.empty();
      final segments = <SegmentRef>[];
      final handler = handlerFor(
        controller,
        callbacks: PathEditorCallbacks(onSegmentCreated: segments.add),
      );

      handler.click(const Offset(10, 10));
      handler.click(const Offset(50, 10));

      expect(controller.svg, 'M10.0 10.0L50.0 10.0');
      expect(segments, [const SegmentRef(0, 0)]);
      expect(handler.activeSegment, const SegmentRef(0, 0),
          reason: 'the new segment stays highlighted');
      expect(controller.selection.active, const NodeRef(0, 1),
          reason: 'the last point stays selected');
    });

    test('click and drag creates a smooth node with mirrored handles', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      handler.drag(const Offset(50, 10), const Offset(70, 10));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.type, PathNodeType.mirrored);
      expect(node.outgoing, const Offset(70, 10));
      expect(node.incoming, const Offset(30, 10));
      expect(controller.svg, contains('C'));
    });

    test('a drag shorter than the threshold stays a corner node', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      handler.drag(const Offset(50, 10), const Offset(51, 10));

      expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.corner);
      expect(controller.svg, 'M10.0 10.0L50.0 10.0');
    });

    test('clicking the first node closes the path', () {
      final controller = PathEditorController.empty();
      final closed = <int>[];
      final handler = handlerFor(
        controller,
        callbacks: PathEditorCallbacks(onSubpathClosed: closed.add),
      );

      handler.click(const Offset(0, 0));
      handler.click(const Offset(40, 0));
      handler.click(const Offset(40, 40));
      handler.click(const Offset(1, 1));

      expect(controller.path.subpaths.single.closed, isTrue);
      expect(controller.path.nodeCount, 3, reason: 'no extra node is added');
      expect(controller.svg, 'M0.0 0.0L40.0 0.0L40.0 40.0Z');
      expect(closed, [0]);
      expect(controller.selection.pendingSubpath, isNull,
          reason: 'the path is finished once it is closed');
    });

    test('hovering the first node offers the close cursor', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(0, 0));
      handler.click(const Offset(40, 0));
      handler.handleHover(const Offset(2, 2));

      expect(handler.hover, isA<CloseTargetHit>());
      expect(handler.cursorState, PathEditorCursorState.closePath);
      expect(handler.closeIndicator, Offset.zero);
    });

    test('hovering a segment offers the add point cursor and indicator', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L100 0',
        tool: PathTool.pen,
      );
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(50, 2));

      expect(handler.hover, isA<SegmentHit>());
      expect(handler.cursorState, PathEditorCursorState.addPoint);
      expect(handler.insertIndicator, const Offset(50, 0));
    });

    test('clicking a segment inserts a node on it', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L100 0',
        tool: PathTool.pen,
      );
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 2));

      expect(controller.path.nodeCount, 3);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
      expect(controller.selection.active, const NodeRef(0, 1));
    });

    test('inserting on a curve keeps the shape', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 100 100 100 100 0',
        tool: PathTool.pen,
      );
      final handler = handlerFor(controller);
      final before = controller.path.segmentAt(const SegmentRef(0, 0));

      handler.click(before.pointAt(0.5));

      expect(controller.path.nodeCount, 3);
      final left = controller.path.segmentAt(const SegmentRef(0, 0));
      final right = controller.path.segmentAt(const SegmentRef(0, 1));
      // The split point comes from projecting the click onto the curve, so it
      // lands a hair away from t = 0.5; the geometry itself is exact.
      for (var i = 0; i <= 10; ++i) {
        final u = i / 10;
        expect(
            (left.pointAt(u) - before.pointAt(u / 2)).distance, lessThan(1e-5));
        expect((right.pointAt(u) - before.pointAt(0.5 + u / 2)).distance,
            lessThan(1e-5));
      }
    });

    test('the remove modifier turns a node click into a removal', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L50 0L100 0',
        tool: PathTool.pen,
      );
      final removed = <NodeRef>[];
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(removeNode: alwaysHeld),
        callbacks: PathEditorCallbacks(
          onNodesRemoved: removed.addAll,
        ),
      );

      handler.handleHover(const Offset(50, 0));
      expect(handler.cursorState, PathEditorCursorState.removePoint);

      handler.click(const Offset(50, 0));

      expect(controller.svg, 'M0.0 0.0L100.0 0.0');
      expect(removed, [const NodeRef(0, 1)]);
    });

    test('a rubber band is offered while a path is being extended', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      handler.handleHover(const Offset(60, 60));

      expect(handler.penAnchor, const Offset(10, 10));
      expect(handler.pointer, const Offset(60, 60));
    });

    test('finishing the path stops the rubber band', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      handler.finishPath();
      handler.handleHover(const Offset(60, 60));

      expect(handler.penAnchor, isNull);
      expect(controller.selection.pendingSubpath, isNull);
    });

    test('switching away from the pen finishes the path', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      controller.tool = PathTool.select;

      expect(controller.selection.pendingSubpath, isNull);
    });
  });

  group('single subpath editors', () {
    PathEditorToolHandler restricted(PathEditorController controller) =>
        handlerFor(
          controller,
          behavior: const PathEditorBehavior(allowMultipleSubpaths: false),
        );

    test('refuse to start a second path after one is closed', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L40 0L40 40Z',
        tool: PathTool.pen,
      );
      final handler = restricted(controller);

      handler.click(const Offset(200, 200));

      expect(controller.path.subpaths, hasLength(1));
      expect(controller.svg, 'M0.0 0.0L40.0 0.0L40.0 40.0Z');
    });

    test('refuse to start a second path next to an open one', () {
      final controller = PathEditorController.empty();
      final handler = restricted(controller);

      handler.click(const Offset(10, 10));
      handler.click(const Offset(50, 10));
      handler.finishPath();
      handler.click(const Offset(200, 200));

      expect(controller.path.subpaths, hasLength(1));
      expect(controller.svg, 'M10.0 10.0L50.0 10.0');
    });

    test('still allow the very first path', () {
      final controller = PathEditorController.empty();
      final handler = restricted(controller);

      handler.click(const Offset(10, 10));
      handler.click(const Offset(50, 10));

      expect(controller.svg, 'M10.0 10.0L50.0 10.0');
    });

    test('still allow extending and closing the existing path', () {
      final controller = PathEditorController.empty();
      final handler = restricted(controller);

      handler.click(const Offset(0, 0));
      handler.click(const Offset(40, 0));
      handler.click(const Offset(40, 40));
      handler.click(const Offset(1, 1));

      expect(controller.svg, 'M0.0 0.0L40.0 0.0L40.0 40.0Z');
    });

    test('still allow inserting a node on an existing segment', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L100 0',
        tool: PathTool.pen,
      );
      final handler = restricted(controller);

      handler.click(const Offset(50, 1));

      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
    });

    test('offer the idle cursor where a click would do nothing', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L40 0L40 40Z',
        tool: PathTool.pen,
      );
      final handler = restricted(controller);

      handler.handleHover(const Offset(200, 200));

      expect(handler.canStartNewSubpath, isFalse);
      expect(handler.cursorState, PathEditorCursorState.idle);
    });

    test('multiple subpaths are allowed by default', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L40 0L40 40Z',
        tool: PathTool.pen,
      );
      final handler = handlerFor(controller);

      handler.click(const Offset(200, 200));

      expect(controller.path.subpaths, hasLength(2));
      expect(handler.canStartNewSubpath, isFalse,
          reason: 'a path is now being extended');
    });
  });

  group('select tool', () {
    test('clicking a node selects it', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));

      expect(controller.selection.nodes, {const NodeRef(0, 1)});
      expect(controller.selection.active, const NodeRef(0, 1));
    });

    test('the multi select modifier adds to the selection', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(multiSelect: alwaysHeld),
      );

      handler.click(const Offset(0, 0));
      handler.click(const Offset(50, 0));

      expect(controller.selection.nodes, {
        const NodeRef(0, 0),
        const NodeRef(0, 1),
      });
    });

    test('the multi select modifier toggles a selected node back off', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(multiSelect: alwaysHeld),
      );

      handler.click(const Offset(0, 0));
      handler.click(const Offset(50, 0));
      handler.click(const Offset(50, 0));

      expect(controller.selection.nodes, {const NodeRef(0, 0)});
    });

    test('dragging a node moves it and its connected segments', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.drag(const Offset(50, 0), const Offset(50, 40));

      expect(controller.svg, 'M0.0 0.0L50.0 40.0L100.0 0.0');
    });

    test('dragging a multi selection moves every selected node', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final withModifier = handlerFor(
        controller,
        modifiers: PathEditorModifiers(multiSelect: alwaysHeld),
      );

      withModifier.click(const Offset(0, 0));
      withModifier.click(const Offset(50, 0));

      // The modifier is released before the drag, as it would be in practice.
      handlerFor(controller).drag(const Offset(50, 0), const Offset(50, 20));

      expect(controller.svg, 'M0.0 20.0L50.0 20.0L100.0 0.0');
    });

    test('shift clicking a selected node removes it instead of dragging it',
        () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(multiSelect: alwaysHeld),
      );

      handler.click(const Offset(0, 0));
      handler.click(const Offset(50, 0));
      handler.drag(const Offset(50, 0), const Offset(50, 20));

      expect(controller.selection.nodes, {const NodeRef(0, 0)});
      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
    });

    test('clicking a selected node reduces a multi selection to it', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(multiSelect: alwaysHeld),
      );

      handler.click(const Offset(0, 0));
      handler.click(const Offset(50, 0));
      expect(controller.selection.nodes, hasLength(2));

      // Clicking without the modifier collapses the selection.
      handlerFor(controller).click(const Offset(50, 0));
      expect(controller.selection.nodes, {const NodeRef(0, 1)});
    });

    test('clicking empty canvas clears the selection', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(0, 0));
      expect(controller.selection.isNotEmpty, isTrue);

      handler.click(const Offset(400, 400));
      expect(controller.selection.isEmpty, isTrue);
    });

    test('clicking a segment selects both of its nodes', () {
      final controller = PathEditorController.fromSvg('M0 0L100 0L100 100');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 1));

      expect(controller.selection.nodes, {
        const NodeRef(0, 0),
        const NodeRef(0, 1),
      });
      expect(handler.activeSegment, const SegmentRef(0, 0));
    });
  });

  group('handles', () {
    test('dragging a handle of a smooth node mirrors the opposite one', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 0 50 0C110 0 0 0 100 0',
      );
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));
      expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.mirrored);

      handler.drag(const Offset(110, 0), const Offset(50, 60));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.outgoing, const Offset(50, 60));
      expect(node.incoming, const Offset(50, -60));
    });

    test('the break modifier leaves the opposite handle untouched', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 0 50 0C110 0 0 0 100 0',
      );
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(breakHandle: alwaysHeld),
      );

      handler.click(const Offset(50, 0));
      handler.drag(const Offset(110, 0), const Offset(50, 60));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.type, PathNodeType.disconnected);
      expect(node.outgoing, const Offset(50, 60));
      expect(node.incoming, const Offset(-10, 0));
    });

    test('handles are only hit tested for selected nodes', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 0 50 0C110 0 0 0 100 0',
      );
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(110, 0));
      expect(handler.hover, isNot(isA<HandleHit>()));

      handler.click(const Offset(50, 0));
      handler.handleHover(const Offset(110, 0));
      expect(handler.hover, isA<HandleHit>());
      expect(handler.cursorState, PathEditorCursorState.adjustHandle);
    });
  });

  group('bending existing points', () {
    PathEditorToolHandler bender(PathEditorController controller) => handlerFor(
          controller,
          modifiers: PathEditorModifiers(bendPoint: alwaysHeld),
        );

    test('turns a corner point into a smooth one without moving it', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = bender(controller);

      handler.drag(const Offset(50, 0), const Offset(80, 30));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.position, const Offset(50, 0),
          reason: 'bending never moves the point itself');
      expect(node.type, PathNodeType.mirrored);
      expect(node.outgoing, const Offset(80, 30));
      expect(node.incoming, const Offset(20, -30));
      expect(controller.svg, contains('C'));
    });

    test('keeps reshaping a point that is already smooth', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 0 50 0C110 0 0 0 100 0',
      );
      final handler = bender(controller);

      handler.drag(const Offset(50, 0), const Offset(50, 40));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.position, const Offset(50, 0));
      expect(node.outgoing, const Offset(50, 40));
      expect(node.incoming, const Offset(50, -40));
    });

    test('respects broken handles instead of relinking them', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 5 50 0C110 0 0 0 100 0',
      );
      expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.disconnected);
      final handler = bender(controller);

      handler.drag(const Offset(50, 0), const Offset(50, 40));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.outgoing, const Offset(50, 40));
      expect(node.incoming, const Offset(-10, 5),
          reason: 'the broken handle is left alone');
    });

    test('a click without a drag leaves the point untouched', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = bender(controller);

      handler.drag(const Offset(50, 0), const Offset(51, 0));

      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
      expect(controller.path.nodeAt(const NodeRef(0, 1)).type,
          PathNodeType.corner);
    });

    test('works with the pen tool too', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L50 0L100 0',
        tool: PathTool.pen,
      );
      final handler = bender(controller);

      handler.drag(const Offset(50, 0), const Offset(80, 30));

      final node = controller.path.nodeAt(const NodeRef(0, 1));
      expect(node.position, const Offset(50, 0));
      expect(node.type, PathNodeType.mirrored);
    });

    test('bends the first node instead of closing the path', () {
      final controller = PathEditorController.empty();
      final handler = bender(controller);

      // Build a path with a handler that is not holding the bend modifier.
      final plain = handlerFor(controller);
      plain.click(const Offset(0, 0));
      plain.click(const Offset(40, 0));
      plain.click(const Offset(40, 40));

      handler.drag(const Offset(0, 0), const Offset(-30, 20));

      expect(controller.path.subpaths.single.closed, isFalse);
      expect(controller.path.nodeAt(const NodeRef(0, 0)).type,
          PathNodeType.mirrored);
    });

    test('offers the adjust handle cursor over a point', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = bender(controller);

      handler.handleHover(const Offset(50, 0));

      expect(handler.cursorState, PathEditorCursorState.adjustHandle);
    });

    test('the whole bend is a single undo step', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = bender(controller);

      handler.handlePointerDown(const Offset(50, 0));
      handler.handlePointerMove(const Offset(70, 20));
      handler.handlePointerMove(const Offset(80, 30));
      handler.handlePointerUp(const Offset(80, 30));

      expect(controller.undo(), isTrue);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('a plain drag still moves the point', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.drag(const Offset(50, 0), const Offset(50, 40));

      expect(controller.svg, 'M0.0 0.0L50.0 40.0L100.0 0.0');
    });
  });

  group('cursor states', () {
    test('reflect the pen tool over empty canvas', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(200, 200));
      expect(handler.cursorState, PathEditorCursorState.penReady);
    });

    test('reflect the select tool over empty canvas', () {
      final controller = PathEditorController.fromSvg('M0 0L10 10');
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(200, 200));
      expect(handler.cursorState, PathEditorCursorState.idle);
    });

    test('distinguish selecting from moving a node', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(50, 0));
      expect(handler.cursorState, PathEditorCursorState.selectPoint);

      handler.click(const Offset(50, 0));
      handler.handleHover(const Offset(50, 0));
      expect(handler.cursorState, PathEditorCursorState.movePoint);
    });

    test('reset when the pointer leaves', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handleHover(const Offset(50, 0));
      handler.handleExit();

      expect(handler.hover, isA<NoHit>());
      expect(handler.pointer, isNull);
    });
  });

  group('viewport', () {
    test('maps pointer positions into scene coordinates', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(
        controller,
        viewport: const PathEditorViewport(
          offset: Offset(100, 50),
          scale: 2,
        ),
      );

      handler.click(const Offset(120, 70));

      expect(controller.path.nodeAt(const NodeRef(0, 0)).position,
          const Offset(10, 10));
    });

    test('keeps hit radii constant in screen pixels while zoomed', () {
      final controller = PathEditorController.fromSvg('M0 0L100 0');
      final zoomed = handlerFor(
        controller,
        viewport: const PathEditorViewport(scale: 4),
      );

      // Eight screen pixels away from the node, which is two scene units at
      // this zoom level.
      zoomed.handleHover(const Offset(8, 0));
      expect(zoomed.hover, isA<NodeHit>());
    });
  });

  group('snapping', () {
    test('pulls a new node onto an existing one', () {
      final controller = PathEditorController.fromSvg(
        'M0 0L100 0',
        tool: PathTool.pen,
      );
      final handler = handlerFor(
        controller,
        // Tight hit radii so the click lands on empty canvas rather than on
        // the existing node, leaving snapping to do the work.
        behavior: const PathEditorBehavior(
          nodeHitRadius: 2,
          segmentHitDistance: 2,
        ),
        snapping: const PathEditorSnapping(threshold: 10),
      );

      handler.click(const Offset(300, 300));
      handler.click(const Offset(105, 5));

      expect(controller.path.subpaths[1].nodes.last.position,
          const Offset(100, 0));
    });

    test('aligns a dragged node with another node on an axis', () {
      final controller = PathEditorController.fromSvg('M0 0L50 80L100 0');
      final handler = handlerFor(
        controller,
        snapping: PathEditorSnapping.defaults,
      );

      handler.drag(const Offset(50, 80), const Offset(50, 3));

      expect(controller.path.nodeAt(const NodeRef(0, 1)).position.dy, 0);
      expect(handler.snapGuides, isEmpty,
          reason: 'guides are cleared when the drag ends');
    });

    test('reports guides while dragging', () {
      final controller = PathEditorController.fromSvg('M0 0L50 80L100 0');
      final handler = handlerFor(
        controller,
        snapping: PathEditorSnapping.defaults,
      );

      handler.handlePointerDown(const Offset(50, 80));
      handler.handlePointerMove(const Offset(50, 3));

      expect(handler.snapGuides, isNotEmpty);
      expect(handler.snapGuides.first.kind, SnapKind.horizontalAxis);
    });

    test('is suppressed by the disable modifier', () {
      final controller = PathEditorController.fromSvg('M0 0L50 80L100 0');
      final handler = handlerFor(
        controller,
        snapping: PathEditorSnapping.defaults,
        modifiers: PathEditorModifiers(disableSnapping: alwaysHeld),
      );

      handler.drag(const Offset(50, 80), const Offset(50, 3));

      expect(controller.path.nodeAt(const NodeRef(0, 1)).position.dy, 3);
    });

    test('constrains handle angles with the constrain modifier', () {
      final controller = PathEditorController.fromSvg(
        'M0 0C0 0 -10 0 50 0C110 0 0 0 100 0',
      );
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(constrainAngle: alwaysHeld),
        snapping: const PathEditorSnapping(angleIncrement: 45),
      );

      handler.click(const Offset(50, 0));
      handler.drag(const Offset(110, 0), const Offset(90, 42));

      // The handle lands exactly on the 45 degree diagonal.
      final outgoing = controller.path.nodeAt(const NodeRef(0, 1)).outgoing!;
      expect(outgoing.dx - 50, closeTo(outgoing.dy, 1e-9));
    });
  });

  group('undo', () {
    test('a whole drag collapses into one step', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handlePointerDown(const Offset(50, 0));
      handler.handlePointerMove(const Offset(60, 10));
      handler.handlePointerMove(const Offset(70, 20));
      handler.handlePointerUp(const Offset(70, 20));

      expect(controller.svg, 'M0.0 0.0L70.0 20.0');
      expect(controller.undo(), isTrue);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('a pen click and its handle drag collapse into one step', () {
      final controller = PathEditorController.empty();
      final handler = handlerFor(controller);

      handler.click(const Offset(10, 10));
      handler.drag(const Offset(50, 10), const Offset(70, 10));

      expect(controller.path.nodeCount, 2);
      controller.undo();
      expect(controller.path.nodeCount, 1);
      controller.undo();
      expect(controller.path.isEmpty, isTrue);
    });

    test('a second pointer cannot unbalance the edit transaction', () {
      // Regression: a second touch used to open a transaction that was never
      // closed, which silently stopped undo from recording.
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handlePointerDown(const Offset(50, 0), pointer: 1);
      handler.handlePointerDown(const Offset(10, 10), pointer: 2);
      handler.handlePointerMove(const Offset(50, 40), pointer: 1);
      handler.handlePointerUp(const Offset(50, 40), pointer: 2);
      handler.handlePointerUp(const Offset(50, 40), pointer: 1);

      expect(controller.isInTransaction, isFalse);
      expect(controller.svg, 'M0.0 0.0L50.0 40.0');
      expect(controller.undo(), isTrue);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0');
    });

    test('disposing mid drag keeps the edit and closes the transaction', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handlePointerDown(const Offset(50, 0));
      handler.handlePointerMove(const Offset(50, 40));
      handler.dispose();

      expect(controller.isInTransaction, isFalse);
      expect(controller.svg, 'M0.0 0.0L50.0 40.0');
      expect(controller.canUndo, isTrue);
    });

    test('cancelling a drag restores the starting path', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.handlePointerDown(const Offset(50, 0));
      handler.handlePointerMove(const Offset(70, 20));
      handler.handlePointerCancel();

      expect(controller.svg, 'M0.0 0.0L50.0 0.0');
      expect(controller.canUndo, isFalse);
    });

    test('restores the selection along with the path', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));
      handler.drag(const Offset(50, 0), const Offset(50, 40));
      controller.undo();

      expect(controller.selection.nodes, {const NodeRef(0, 1)});
    });
  });

  group('removing the selection', () {
    test('preserves the shape by default', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));
      expect(handler.removeSelection(), isTrue);

      expect(controller.svg, 'M0.0 0.0L100.0 0.0');
    });

    test('refuses a cut that would create a second open path', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(cutPath: alwaysHeld),
      );

      handler.click(const Offset(50, 0));
      expect(handler.removeSelection(), isFalse);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
    });

    test('cuts a closed path open', () {
      final controller = PathEditorController.fromSvg('M0 0L100 0L100 100Z');
      final handler = handlerFor(
        controller,
        modifiers: PathEditorModifiers(cutPath: alwaysHeld),
      );

      handler.click(const Offset(100, 0));
      expect(handler.removeSelection(), isTrue);
      expect(controller.svg, 'M100.0 100.0L0.0 0.0');
    });
  });

  group('nudging and converting', () {
    test('nudging moves the selection', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));
      handler.nudgeSelection(const Offset(0, -10));

      expect(controller.svg, 'M0.0 0.0L50.0 -10.0');
    });

    test('converting turns a corner into a smooth node and back', () {
      final controller = PathEditorController.fromSvg('M0 0L50 0L100 0');
      final handler = handlerFor(controller);

      handler.click(const Offset(50, 0));
      handler.convertSelection(PathNodeType.mirrored);
      expect(controller.path.nodeAt(const NodeRef(0, 1)).hasHandles, isTrue);

      handler.convertSelection(PathNodeType.corner);
      expect(controller.svg, 'M0.0 0.0L50.0 0.0L100.0 0.0');
    });
  });
}
