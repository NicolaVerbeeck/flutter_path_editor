import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_node.dart';

void main() {
  group('EditablePath conversion', () {
    test('parses a single move command', () {
      final path = EditablePath.fromSvg('M1 2');

      expect(path.subpaths, hasLength(1));
      expect(path.subpaths.single.nodes, hasLength(1));
      expect(path.subpaths.single.first.position, const Offset(1, 2));
      expect(path.subpaths.single.closed, isFalse);
      expect(path.toSvg(), 'M1.0 2.0');
    });

    test('parses lines into corner nodes', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10');

      expect(path.nodeCount, 3);
      expect(
        path.subpaths.single.nodes.map((n) => n.type),
        everyElement(PathNodeType.corner),
      );
      expect(path.toSvg(), 'M0.0 0.0L10.0 0.0L10.0 10.0');
    });

    test('splits cubic control points across the anchors they belong to', () {
      final path = EditablePath.fromSvg('M0 0C1 2 3 4 5 6');

      final nodes = path.subpaths.single.nodes;
      expect(nodes, hasLength(2));
      // The first control point is the outgoing handle of the start anchor.
      expect(nodes[0].outgoing, const Offset(1, 2));
      expect(nodes[0].incoming, isNull);
      // The second control point is the incoming handle of the end anchor.
      expect(nodes[1].incoming, const Offset(3, 4));
      expect(nodes[1].position, const Offset(5, 6));
    });

    test('round trips a cubic path', () {
      const svg = 'M0.0 0.0C1.0 2.0 3.0 4.0 5.0 6.0';
      expect(EditablePath.fromSvg(svg).toSvg(), svg);
    });

    test('round trips a closed straight path without duplicating the node', () {
      const svg = 'M0.0 0.0L10.0 0.0L10.0 10.0Z';
      final path = EditablePath.fromSvg(svg);

      expect(path.subpaths.single.closed, isTrue);
      expect(path.nodeCount, 3);
      expect(path.subpaths.single.segmentCount, 3);
      expect(path.toSvg(), svg);
    });

    test('merges the duplicated closing node and keeps its handle', () {
      // The path explicitly curves back to its starting point before closing.
      const svg = 'M0.0 0.0L10.0 0.0C10.0 5.0 5.0 10.0 0.0 0.0Z';
      final path = EditablePath.fromSvg(svg);

      expect(path.nodeCount, 2, reason: 'closing node folds into the first');
      expect(path.subpaths.single.first.incoming, const Offset(5, 10));
      expect(path.toSvg(), svg);
    });

    test('round trips a closed loop made of a single curve', () {
      // Regression: folding the duplicated closing node would leave a lone
      // anchor with no segment, silently dropping the curve.
      const svg = 'M100.0 100.0C150.0 50.0 50.0 50.0 100.0 100.0Z';
      final path = EditablePath.fromSvg(svg);

      expect(path.nodeCount, 2);
      expect(path.subpaths.single.closed, isTrue);
      expect(path.subpaths.single.segmentAt(0).isCurve, isTrue);
      expect(path.toSvg(), svg);
      expect(path.bounds().isEmpty, isFalse);
    });

    test('round trips multiple subpaths', () {
      const svg = 'M0.0 0.0L10.0 0.0ZM20.0 20.0L30.0 30.0';
      final path = EditablePath.fromSvg(svg);

      expect(path.subpaths, hasLength(2));
      expect(path.subpaths[0].closed, isTrue);
      expect(path.subpaths[1].closed, isFalse);
      expect(path.toSvg(), svg);
    });

    test('normalises relative, arc and quadratic commands', () {
      final path = EditablePath.fromSvg('M0 0 q 5 0 10 10 t 10 10');

      expect(path.nodeCount, greaterThan(1));
      // Everything is normalised into absolute move/line/cubic operators.
      expect(path.toSvg(), startsWith('M0.0 0.0C'));
    });

    test('infers node types from handle geometry', () {
      final mirrored = EditablePath.fromSvg(
        'M0 0C0 0 -10 0 10 0C30 0 0 0 20 0',
      ).nodeAt(const NodeRef(0, 1));
      expect(mirrored.incoming, const Offset(-10, 0));
      expect(mirrored.outgoing, const Offset(30, 0));
      expect(mirrored.type, PathNodeType.mirrored);

      final aligned = EditablePath.fromSvg(
        'M0 0C0 0 -10 0 10 0C40 0 0 0 20 0',
      ).nodeAt(const NodeRef(0, 1));
      expect(aligned.type, PathNodeType.aligned);

      final broken = EditablePath.fromSvg(
        'M0 0C0 0 -10 5 10 0C40 0 0 0 20 0',
      ).nodeAt(const NodeRef(0, 1));
      expect(broken.type, PathNodeType.disconnected);
    });

    test('exposes segment geometry', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10');

      final segment = path.segmentAt(const SegmentRef(0, 0));
      expect(segment.isCurve, isFalse);
      expect(segment.start, Offset.zero);
      expect(segment.end, const Offset(10, 0));
      expect(segment.midpoint, const Offset(5, 0));
      expect(path.segmentRefs, hasLength(2));
    });

    test('wraps the closing segment of a closed subpath', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10Z');

      final closing = path.segmentAt(const SegmentRef(0, 2));
      expect(closing.start, const Offset(10, 10));
      expect(closing.end, Offset.zero);
    });
  });

  group('EditablePath bounds', () {
    test('are exact for straight paths', () {
      final path = EditablePath.fromSvg('M0 0L10 20');
      expect(path.bounds(), const Rect.fromLTRB(0, 0, 10, 20));
    });

    test('use curve extrema rather than control points', () {
      // The curve never reaches y = 100; its extremum is at y = 75.
      final path = EditablePath.fromSvg('M0 0C0 100 100 100 100 0');
      final bounds = path.bounds();

      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, closeTo(75, 1e-9));
    });

    test('are inflated by half the stroke width', () {
      final path = EditablePath.fromSvg('M0 0L10 10');
      expect(path.bounds(strokeWidth: 4), const Rect.fromLTRB(-2, -2, 12, 12));
    });

    test('are zero for an empty path', () {
      expect(EditablePath.empty.bounds(), Rect.zero);
    });
  });

  group('PathNode handle linkage', () {
    const position = Offset.zero;

    test('mirrored handles mirror the opposite handle', () {
      const node = PathNode(
        position: position,
        incoming: Offset(-10, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.mirrored,
      );

      final moved = node.withLinkedHandle(
        NodeHandle.outgoing,
        const Offset(0, 20),
      );

      expect(moved.outgoing, const Offset(0, 20));
      expect(moved.incoming, const Offset(0, -20));
    });

    test('aligned handles rotate but keep their length', () {
      const node = PathNode(
        position: position,
        incoming: Offset(-30, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.aligned,
      );

      final moved = node.withLinkedHandle(
        NodeHandle.outgoing,
        const Offset(0, 10),
      );

      expect(moved.outgoing, const Offset(0, 10));
      expect(moved.incoming!.dx, closeTo(0, 1e-9));
      expect(moved.incoming!.dy, closeTo(-30, 1e-9));
    });

    test('breaking the link leaves the opposite handle untouched', () {
      const node = PathNode(
        position: position,
        incoming: Offset(-10, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.mirrored,
      );

      final moved = node.withLinkedHandle(
        NodeHandle.outgoing,
        const Offset(0, 20),
        breakLink: true,
      );

      expect(moved.outgoing, const Offset(0, 20));
      expect(moved.incoming, const Offset(-10, 0));
      expect(moved.type, PathNodeType.disconnected);
    });

    test('disconnected handles move independently', () {
      const node = PathNode(
        position: position,
        incoming: Offset(-10, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.disconnected,
      );

      final moved = node.withLinkedHandle(
        NodeHandle.incoming,
        const Offset(-5, 5),
      );

      expect(moved.incoming, const Offset(-5, 5));
      expect(moved.outgoing, const Offset(10, 0));
    });

    test('moving a node drags its handles along', () {
      const node = PathNode(
        position: Offset(10, 10),
        incoming: Offset(0, 10),
        outgoing: Offset(20, 10),
        type: PathNodeType.mirrored,
      );

      final moved = node.movedTo(const Offset(20, 20));

      expect(moved.position, const Offset(20, 20));
      expect(moved.incoming, const Offset(10, 20));
      expect(moved.outgoing, const Offset(30, 20));
    });
  });

  group('PathNode conversion', () {
    test('smooth to corner collapses the handles', () {
      const node = PathNode(
        position: Offset.zero,
        incoming: Offset(-10, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.mirrored,
      );

      final corner = node.convertedTo(PathNodeType.corner);

      expect(corner.hasHandles, isFalse);
      expect(corner.type, PathNodeType.corner);
    });

    test('corner to smooth grows handles along the neighbour tangent', () {
      const node = PathNode.corner(Offset(10, 0));

      final smooth = node.convertedTo(
        PathNodeType.mirrored,
        previous: Offset.zero,
        next: const Offset(20, 0),
      );

      expect(smooth.type, PathNodeType.mirrored);
      expect(smooth.incoming!.dx, closeTo(10 - 10 / 3, 1e-9));
      expect(smooth.incoming!.dy, closeTo(0, 1e-9));
      expect(smooth.outgoing!.dx, closeTo(10 + 10 / 3, 1e-9));
      expect(smooth.outgoing!.dy, closeTo(0, 1e-9));
    });

    test('corner without neighbours stays a corner', () {
      const node = PathNode.corner(Offset(10, 0));
      expect(
        node.convertedTo(PathNodeType.mirrored).type,
        PathNodeType.corner,
      );
    });

    test('aligned to mirrored equalises the handle lengths', () {
      const node = PathNode(
        position: Offset.zero,
        incoming: Offset(-30, 0),
        outgoing: Offset(10, 0),
        type: PathNodeType.aligned,
      );

      final mirrored = node.convertedTo(PathNodeType.mirrored);

      expect(mirrored.incoming!.dx, closeTo(-20, 1e-9));
      expect(mirrored.outgoing!.dx, closeTo(20, 1e-9));
    });

    test('broken handles are realigned when made smooth', () {
      const node = PathNode(
        position: Offset.zero,
        incoming: Offset(-10, 10),
        outgoing: Offset(10, 10),
        type: PathNodeType.disconnected,
      );

      final aligned = node.convertedTo(PathNodeType.aligned);

      // The handles now point in exactly opposite directions.
      final incomingVector = aligned.handleVector(NodeHandle.incoming)!;
      final outgoingVector = aligned.handleVector(NodeHandle.outgoing)!;
      final cross = incomingVector.dx * outgoingVector.dy -
          incomingVector.dy * outgoingVector.dx;
      expect(cross, closeTo(0, 1e-9));
    });
  });
}
