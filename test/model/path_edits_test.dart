import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/src/model/editable_path.dart';
import 'package:path_editor/src/model/path_edits.dart';
import 'package:path_editor/src/model/path_node.dart';
import 'package:path_editor/src/model/path_segment.dart';

/// The largest distance between the two paths, sampled along every segment.
double maxDeviation(EditablePath a, EditablePath b) {
  final samples = <Offset>[];
  for (final subpath in a.subpaths) {
    for (final segment in subpath.segments) {
      for (var i = 0; i <= 40; ++i) {
        samples.add(segment.pointAt(i / 40));
      }
    }
  }

  final targets = <PathSegment>[
    for (final subpath in b.subpaths) ...subpath.segments,
  ];

  var worst = 0.0;
  for (final sample in samples) {
    var best = double.infinity;
    for (final segment in targets) {
      best = math.min(best, segment.distanceTo(sample));
    }
    worst = math.max(worst, best);
  }
  return worst;
}

void main() {
  group('insertNodeOn', () {
    test('splits a straight segment into two straight segments', () {
      final path = EditablePath.fromSvg('M0 0L10 0');

      final (updated, ref) = path.insertNodeOn(const SegmentRef(0, 0), 0.5);

      expect(ref, const NodeRef(0, 1));
      expect(updated.nodeCount, 3);
      expect(updated.nodeAt(ref).position, const Offset(5, 0));
      expect(updated.nodeAt(ref).hasHandles, isFalse);
      expect(updated.toSvg(), 'M0.0 0.0L5.0 0.0L10.0 0.0');
    });

    test('splits a curve without changing its geometry', () {
      final path = EditablePath.fromSvg('M0 0C0 100 100 100 100 0');
      final original = path.segmentAt(const SegmentRef(0, 0));

      final (updated, ref) = path.insertNodeOn(const SegmentRef(0, 0), 0.5);

      expect(updated.nodeCount, 3);
      expect(updated.nodeAt(ref).type, PathNodeType.mirrored);

      // De Casteljau is exact: the two halves reproduce the original curve
      // point for point.
      final left = updated.segmentAt(const SegmentRef(0, 0));
      final right = updated.segmentAt(const SegmentRef(0, 1));
      for (var i = 0; i <= 20; ++i) {
        final u = i / 20;
        expect(
          (left.pointAt(u) - original.pointAt(u / 2)).distance,
          lessThan(1e-12),
        );
        expect(
          (right.pointAt(u) - original.pointAt(0.5 + u / 2)).distance,
          lessThan(1e-12),
        );
      }
    });

    test('inserts on the wrapping segment of a closed subpath', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10Z');

      final (updated, ref) = path.insertNodeOn(const SegmentRef(0, 2), 0.5);

      expect(ref, const NodeRef(0, 3));
      expect(updated.nodeAt(ref).position, const Offset(5, 5));
      expect(updated.subpaths.single.closed, isTrue);
      expect(updated.toSvg(), 'M0.0 0.0L10.0 0.0L10.0 10.0L5.0 5.0Z');
    });
  });

  group('removeNodes preserving shape', () {
    test('removes an interior node of a polyline', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      final updated = path.removeNodes([const NodeRef(0, 1)]);

      expect(updated.toSvg(), 'M0.0 0.0L20.0 0.0');
    });

    test('recovers the original curve after an insert is undone by removal',
        () {
      // Inserting a node is exact, so removing it again must land back on the
      // original curve. This is the strictest possible check of the refit.
      final path = EditablePath.fromSvg('M0 0C20 90 80 90 100 0');
      final (split, inserted) = path.insertNodeOn(const SegmentRef(0, 0), 0.4);

      final restored = split.removeNodes([inserted]);

      expect(restored.nodeCount, 2);
      expect(maxDeviation(path, restored), lessThan(0.001));
      expect(maxDeviation(restored, path), lessThan(0.001));
    });

    test('keeps the shape of a curve within a tight tolerance', () {
      // A half circle approximated by two cubics, then simplified to one. A
      // single cubic cannot represent a half circle exactly, so the residual
      // error is bounded by the well known ~3% of the radius.
      final path = EditablePath.fromSvg(
        'M0 0C0 55 45 100 100 100C155 100 200 55 200 0',
      );

      final updated = path.removeNodes([const NodeRef(0, 1)]);

      expect(updated.nodeCount, 2);
      expect(maxDeviation(path, updated), lessThan(0.04 * 100));
      expect(updated.nodeAt(const NodeRef(0, 0)).outgoing, isNotNull);
      expect(updated.nodeAt(const NodeRef(0, 1)).incoming, isNotNull);
    });

    test('is far better than naively dropping the node', () {
      final path = EditablePath.fromSvg(
        'M0 0C0 55 45 100 100 100C155 100 200 55 200 0',
      );

      final refitted = path.removeNodes([const NodeRef(0, 1)]);
      final naive = EditablePath.fromSvg('M0 0C0 55 200 55 200 0');

      expect(
        maxDeviation(path, refitted),
        lessThan(maxDeviation(path, naive)),
      );
    });

    test('removing an endpoint clears the dangling handle', () {
      final path = EditablePath.fromSvg('M0 0C10 0 20 0 30 0');

      final updated = path.removeNodes([const NodeRef(0, 1)]);

      expect(updated.nodeCount, 1);
      expect(updated.nodeAt(const NodeRef(0, 0)).hasHandles, isFalse);
    });

    test('removing from a closed subpath keeps it closed', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10L0 10Z');

      final updated = path.removeNodes([const NodeRef(0, 1)]);

      expect(updated.subpaths.single.closed, isTrue);
      expect(updated.nodeCount, 3);
      expect(updated.toSvg(), 'M0.0 0.0L10.0 10.0L0.0 10.0Z');
    });

    test('removes several nodes at once', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0L30 0L40 0');

      final updated = path.removeNodes([
        const NodeRef(0, 1),
        const NodeRef(0, 3),
      ]);

      expect(updated.toSvg(), 'M0.0 0.0L20.0 0.0L40.0 0.0');
    });

    test('dropping every node removes the subpath', () {
      final path = EditablePath.fromSvg('M0 0L10 0');

      final updated = path.removeNodes([
        const NodeRef(0, 0),
        const NodeRef(0, 1),
      ]);

      expect(updated.isEmpty, isTrue);
      expect(updated.subpaths, isEmpty);
    });
  });

  group('removeNodes cutting', () {
    test('opens a closed subpath and rotates it around the cut', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10L0 10Z');

      final updated =
          path.removeNodes([const NodeRef(0, 1)], mode: NodeRemoval.cut);

      expect(updated.subpaths, hasLength(1));
      expect(updated.subpaths.single.closed, isFalse);
      expect(updated.toSvg(), 'M10.0 10.0L0.0 10.0L0.0 0.0');
    });

    test('splitting an open subpath in the middle is rejected', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      expect(
        path.canRemoveNodes([const NodeRef(0, 1)], mode: NodeRemoval.cut),
        isFalse,
        reason: 'it would create a second open path',
      );
    });

    test('cutting at an endpoint of an open subpath is allowed', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      expect(
        path.canRemoveNodes([const NodeRef(0, 0)], mode: NodeRemoval.cut),
        isTrue,
      );
      expect(
        path.removeNodes([const NodeRef(0, 0)], mode: NodeRemoval.cut).toSvg(),
        'M10.0 0.0L20.0 0.0',
      );
    });

    test('cutting a closed subpath is rejected when another path is open', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10ZM50 50L60 60');

      expect(
        path.canRemoveNodes([const NodeRef(0, 0)], mode: NodeRemoval.cut),
        isFalse,
        reason: 'the second subpath is already open',
      );
    });

    test('preserving the shape is always allowed', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      expect(path.canRemoveNodes([const NodeRef(0, 1)]), isTrue);
    });

    test('cutting a closed subpath at several nodes uses the right ones', () {
      // Regression: opening the loop rotates the nodes, so applying the cuts
      // one at a time made every later reference point at the wrong node.
      final path = EditablePath.fromSvg('M0 0L10 0L20 0L30 0Z');

      final updated = path.removeNodes(
        [const NodeRef(0, 0), const NodeRef(0, 1)],
        mode: NodeRemoval.cut,
      );

      expect(updated.subpaths, hasLength(1));
      expect(updated.toSvg(), 'M20.0 0.0L30.0 0.0');
    });

    test('cutting an open subpath at several nodes splits it correctly', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0L30 0L40 0');

      final updated = path.removeNodes(
        [const NodeRef(0, 1), const NodeRef(0, 3)],
        mode: NodeRemoval.cut,
      );

      expect(updated.subpaths, hasLength(3));
      expect(updated.toSvg(), 'M0.0 0.0M20.0 0.0M40.0 0.0');
    });

    test('cutting away every node leaves nothing behind', () {
      final path = EditablePath.fromSvg('M0 0L10 0Z');

      final updated = path.removeNodes(
        [const NodeRef(0, 0), const NodeRef(0, 1)],
        mode: NodeRemoval.cut,
      );

      expect(updated.isEmpty, isTrue);
    });

    test('keeps the dangling handles of ends that were not cut', () {
      // The pen tool leaves a dangling outgoing handle on the node it is
      // extending from; cutting somewhere else must not wipe it.
      final path = EditablePath.fromSvg('M0 0L50 0L100 0').setHandle(
        const HandleRef(NodeRef(0, 2), NodeHandle.outgoing),
        const Offset(120, 20),
      );
      expect(path.nodeAt(const NodeRef(0, 2)).type, PathNodeType.mirrored);

      final updated =
          path.removeNodes([const NodeRef(0, 0)], mode: NodeRemoval.cut);

      final tail = updated.nodeAt(const NodeRef(0, 1));
      expect(tail.outgoing, const Offset(120, 20));
      expect(tail.type, PathNodeType.mirrored);
      // The new head sits where the cut happened, so it does lose its handle.
      expect(updated.nodeAt(const NodeRef(0, 0)).incoming, isNull);
    });

    test('clears only the cut side when cutting the last node', () {
      final path = EditablePath.fromSvg('M0 0L50 0L100 0').setHandle(
        const HandleRef(NodeRef(0, 0), NodeHandle.incoming),
        const Offset(-20, -10),
      );

      final updated =
          path.removeNodes([const NodeRef(0, 2)], mode: NodeRemoval.cut);

      expect(
        updated.nodeAt(const NodeRef(0, 0)).incoming,
        const Offset(-20, -10),
      );
      expect(updated.nodeAt(const NodeRef(0, 1)).outgoing, isNull);
    });

    test('an interior piece loses the handles on both of its cut ends', () {
      final path = EditablePath.fromSvg(
        'M0 0C10 0 20 0 30 0C40 0 50 0 60 0C70 0 80 0 90 0C100 0 110 0 120 0',
      );

      final updated = path.removeNodes(
        [const NodeRef(0, 1), const NodeRef(0, 3)],
        mode: NodeRemoval.cut,
      );

      expect(updated.subpaths, hasLength(3));
      // The middle piece is bounded by a cut on both sides.
      final middle = updated.subpaths[1];
      expect(middle.nodes, hasLength(1));
      expect(middle.first.incoming, isNull);
      expect(middle.first.outgoing, isNull);
      // The outer ends of the original run keep their dangling handles.
      expect(updated.subpaths.first.first.incoming, isNull);
      expect(updated.subpaths.last.last.outgoing, isNull);
    });
  });

  group('structural edits', () {
    test('appends nodes to a subpath', () {
      final (path, ref) = EditablePath.fromSvg('M0 0')
          .appendNode(0, const PathNode.corner(Offset(10, 0)));

      expect(ref, const NodeRef(0, 1));
      expect(path.toSvg(), 'M0.0 0.0L10.0 0.0');
    });

    test('starts a new subpath', () {
      final (path, ref) =
          EditablePath.empty.startSubpath(const PathNode.corner(Offset(5, 5)));

      expect(ref, const NodeRef(0, 0));
      expect(path.toSvg(), 'M5.0 5.0');
    });

    test('closes and reopens a subpath', () {
      final path = EditablePath.fromSvg('M0 0L10 0L10 10');

      final closed = path.closeSubpath(0);
      expect(closed.toSvg(), 'M0.0 0.0L10.0 0.0L10.0 10.0Z');
      expect(closed.openSubpath(0).toSvg(), 'M0.0 0.0L10.0 0.0L10.0 10.0');
    });

    test('translates a selection of nodes', () {
      final path = EditablePath.fromSvg('M0 0C10 0 20 0 30 0');

      final updated = path.translateNodes(
        [const NodeRef(0, 1)],
        const Offset(0, 5),
      );

      expect(updated.toSvg(), 'M0.0 0.0C10.0 0.0 20.0 5.0 30.0 5.0');
    });

    test('growing a handle on a corner node creates a smooth node', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      final updated = path.setHandle(
        const HandleRef(NodeRef(0, 1), NodeHandle.outgoing),
        const Offset(15, 5),
      );

      final node = updated.nodeAt(const NodeRef(0, 1));
      expect(node.type, PathNodeType.mirrored);
      expect(node.outgoing, const Offset(15, 5));
      expect(node.incoming, const Offset(5, -5));
    });

    test('breaking a handle leaves the opposite one alone', () {
      final path = EditablePath.fromSvg('M0 0C0 0 -10 0 10 0C30 0 0 0 20 0');

      final updated = path.setHandle(
        const HandleRef(NodeRef(0, 1), NodeHandle.outgoing),
        const Offset(20, 10),
        breakLink: true,
      );

      final node = updated.nodeAt(const NodeRef(0, 1));
      expect(node.type, PathNodeType.disconnected);
      expect(node.outgoing, const Offset(20, 10));
      expect(node.incoming, const Offset(-10, 0));
    });

    test('converts nodes between corner and smooth', () {
      final path = EditablePath.fromSvg('M0 0L10 0L20 0');

      final smooth = path.convertNodes(
        [const NodeRef(0, 1)],
        PathNodeType.mirrored,
      );
      expect(smooth.nodeAt(const NodeRef(0, 1)).hasHandles, isTrue);
      expect(smooth.toSvg(), contains('C'));

      final corner = smooth.convertNodes(
        [const NodeRef(0, 1)],
        PathNodeType.corner,
      );
      expect(corner.toSvg(), 'M0.0 0.0L10.0 0.0L20.0 0.0');
    });

    test('clearing a handle straightens the segment', () {
      final path = EditablePath.fromSvg('M0 0C10 0 20 0 30 0');

      final updated = path.clearHandle(
        const HandleRef(NodeRef(0, 1), NodeHandle.incoming),
      );

      expect(updated.toSvg(), 'M0.0 0.0C10.0 0.0 30.0 0.0 30.0 0.0');
    });
  });
}
