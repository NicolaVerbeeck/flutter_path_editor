import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  final path = EditablePath.fromSvg('M0 0L100 0L100 100');

  group('point snapping', () {
    test('pulls a position onto a nearby node', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(threshold: 10),
      );

      final result = engine.snap(const Offset(104, 4), path: path);

      expect(result.position, const Offset(100, 0));
      expect(result.didSnap, isTrue);
      expect(result.guides.single.kind, SnapKind.node);
      expect(result.guides.single.isPoint, isTrue);
    });

    test('pulls a position onto a segment midpoint', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(snapToNodes: false),
      );

      final result = engine.snap(const Offset(52, 3), path: path);

      expect(result.position, const Offset(50, 0));
      expect(result.guides.single.kind, SnapKind.midpoint);
    });

    test('ignores excluded nodes', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(
          threshold: 10,
          snapToMidpoints: false,
          snapToAxes: false,
        ),
      );

      final result = engine.snap(
        const Offset(104, 4),
        path: path,
        exclude: {const NodeRef(0, 1)},
      );

      expect(result.didSnap, isFalse);
      expect(result.position, const Offset(104, 4));
    });

    test('respects the threshold', () {
      const engine = SnapEngine(config: PathEditorSnapping(threshold: 2));

      final result = engine.snap(const Offset(110, 10), path: path);

      expect(result.didSnap, isFalse);
    });

    test('scales the threshold with the viewport', () {
      const zoomed = SnapEngine(
        config: PathEditorSnapping(threshold: 10),
        scale: 5,
      );

      // Ten screen pixels is two scene units at this zoom level.
      expect(zoomed.sceneThreshold, 2);
      expect(zoomed.snap(const Offset(101, 1), path: path).didSnap, isTrue);
      expect(zoomed.snap(const Offset(105, 5), path: path).didSnap, isFalse);
    });
  });

  group('axis snapping', () {
    test('aligns vertically with another node', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(
          snapToNodes: false,
          snapToMidpoints: false,
        ),
      );

      final result = engine.snap(const Offset(97, 50), path: path);

      expect(result.position.dx, 100);
      expect(result.guides, hasLength(1));
      expect(result.guides.single.kind, SnapKind.verticalAxis);
    });

    test('aligns on both axes at once', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(
          snapToNodes: false,
          snapToMidpoints: false,
        ),
      );

      final result = engine.snap(const Offset(97, 3), path: path);

      expect(result.position, const Offset(100, 0));
      expect(
        result.guides.map((guide) => guide.kind),
        containsAll([SnapKind.verticalAxis, SnapKind.horizontalAxis]),
      );
    });

    test('can be turned off', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(
          snapToNodes: false,
          snapToMidpoints: false,
          snapToAxes: false,
        ),
      );

      expect(engine.snap(const Offset(97, 50), path: path).didSnap, isFalse);
    });
  });

  group('angle constraint', () {
    test('snaps to the nearest increment around the anchor', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(angleIncrement: 45),
      );

      final result = engine.snap(
        const Offset(100, 90),
        path: path,
        anchor: Offset.zero,
        constrainAngle: true,
      );

      expect(result.position.dx, closeTo(result.position.dy, 1e-9));
      expect(result.position.distance,
          closeTo(math.sqrt(100 * 100 + 90 * 90), 1e-9));
      expect(result.guides.single.kind, SnapKind.angle);
    });

    test('takes precedence over disabled snapping', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(enabled: false, angleIncrement: 90),
      );

      final result = engine.snap(
        const Offset(50, 5),
        path: path,
        anchor: Offset.zero,
        constrainAngle: true,
      );

      expect(result.position.dy, closeTo(0, 1e-9));
    });
  });

  group('disabling', () {
    test('returns the position untouched when disabled', () {
      const engine = SnapEngine(config: PathEditorSnapping.disabled);

      expect(engine.snap(const Offset(101, 1), path: path).didSnap, isFalse);
    });

    test('returns the position untouched when suppressed', () {
      const engine = SnapEngine(
        config: PathEditorSnapping(threshold: 10),
      );

      final result =
          engine.snap(const Offset(101, 1), path: path, enabled: false);

      expect(result.didSnap, isFalse);
    });
  });
}
