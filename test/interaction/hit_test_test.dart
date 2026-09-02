import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  final path = EditablePath.fromSvg('M0 0C10 0 20 0 30 0L60 0');
  const first = NodeRef(0, 0);
  const second = NodeRef(0, 1);
  const third = NodeRef(0, 2);

  group('hit value types', () {
    test('compare and describe every hit type', () {
      const noHit = NoHit();
      const nodeHit = NodeHit(first, 1);
      const closeHit = CloseTargetHit(first, 1);
      const handleHit = HandleHit(
        HandleRef(first, NodeHandle.outgoing),
        1,
      );
      const segmentHit = SegmentHit(
        segment: SegmentRef(0, 0),
        t: 0.5,
        position: Offset(15, 0),
        distance: 1,
      );

      expect(noHit, const NoHit());
      expect(nodeHit, const NodeHit(first, 1));
      expect(closeHit, const CloseTargetHit(first, 1));
      expect(
          handleHit,
          const HandleHit(
            HandleRef(first, NodeHandle.outgoing),
            1,
          ));
      expect(
          segmentHit,
          const SegmentHit(
            segment: SegmentRef(0, 0),
            t: 0.5,
            position: Offset(15, 0),
            distance: 1,
          ));
      expect(noHit.hashCode, 0);
      expect(nodeHit.toString(), 'NodeHit(NodeRef(0:0))');
      expect(closeHit.toString(), 'CloseTargetHit(NodeRef(0:0))');
      expect(handleHit.toString(), contains('HandleRef'));
      expect(segmentHit.toString(), contains('t: 0.5'));
      expect(nodeHit == Object(), isFalse);
    });
  });

  group('PathHitTester', () {
    final tester = PathHitTester(path: path);

    test('prioritizes handles, nodes, then segments', () {
      final handle = tester.hitTest(
        const Offset(10, 0),
        handleNodes: {first},
      );
      expect(handle, isA<HandleHit>());
      expect(
          (handle as HandleHit).handle, first.handleRef(NodeHandle.outgoing));

      final node = tester.hitTest(const Offset(30, 0));
      expect(node, const NodeHit(second, 0));

      final segment = tester.hitTest(const Offset(45, 0));
      expect(segment, isA<SegmentHit>());
      expect((segment as SegmentHit).segment, const SegmentRef(0, 1));
    });

    test('recognizes a close target and can exclude segments', () {
      expect(
        tester.hitTest(const Offset(0, 0), closeTarget: first),
        const CloseTargetHit(first, 0),
      );
      expect(
        tester.hitTest(const Offset(15, 4), includeSegments: false),
        const NoHit(),
      );
    });

    test('chooses the closest target and ignores stale handles', () {
      final result = tester.hitTest(
        const Offset(10, 0),
        handleNodes: {
          const NodeRef(99, 99),
          first,
        },
      );
      expect(result, isA<HandleHit>());
      expect(
          (result as HandleHit).handle, first.handleRef(NodeHandle.outgoing));

      expect(
        tester.hitTest(const Offset(100, 100)),
        const NoHit(),
      );
    });

    test('converts screen hit radii through the viewport', () {
      final zoomed = PathHitTester(
        path: path,
        behavior: const PathEditorBehavior(nodeHitRadius: 10),
        viewport: const PathEditorViewport(scale: 2),
      );

      expect(zoomed.hitTest(const Offset(64, 0)), const NodeHit(third, 4));
      expect(zoomed.hitTest(const Offset(66, 0)), const NoHit());
    });
  });
}
