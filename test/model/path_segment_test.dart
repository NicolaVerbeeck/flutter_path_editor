import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  group('straight PathSegment', () {
    const segment = PathSegment.line(start: Offset(0, 0), end: Offset(10, 20));

    test('evaluates, projects, splits and reports bounds', () {
      expect(segment.isCurve, isFalse);
      expect(segment.control1, segment.start);
      expect(segment.control2, segment.end);
      expect(segment.pointAt(-1), segment.start);
      expect(segment.pointAt(0.5), const Offset(5, 10));
      expect(segment.pointAt(2), segment.end);
      expect(segment.tangentAt(0.5), const Offset(10, 20));
      expect(segment.midpoint, const Offset(5, 10));
      expect(segment.bounds, const Rect.fromLTRB(0, 0, 10, 20));

      final projection = segment.project(const Offset(5, 12));
      expect(projection.t, closeTo(0.58, 1e-9));
      expect(segment.distanceTo(const Offset(5, 12)), closeTo(0.8944, 1e-4));
      expect(segment.project(const Offset(-10, -10)).t, 0);
      expect(segment.project(const Offset(100, 100)).t, 1);

      final (left, right) = segment.splitAt(0.25);
      expect(
          left,
          const PathSegment.line(
            start: Offset(0, 0),
            end: Offset(2.5, 5),
          ));
      expect(
          right,
          const PathSegment.line(
            start: Offset(2.5, 5),
            end: Offset(10, 20),
          ));
    });

    test('handles a zero-length chord and paints a line', () {
      const zero = PathSegment.line(start: Offset(3, 4), end: Offset(3, 4));
      expect(
          zero.project(const Offset(6, 8)),
          const SegmentProjection(
            t: 0,
            point: Offset(3, 4),
            distance: 5,
          ));

      final path = Path()..moveTo(3, 4);
      zero.addTo(path);
      expect(path.getBounds(), const Rect.fromLTRB(3, 4, 3, 4));
      expect(zero.toString(),
          'PathSegment.line(Offset(3.0, 4.0), Offset(3.0, 4.0))');
      expect(zero.hashCode, zero.hashCode);
      expect(zero == Object(), isFalse);
    });
  });

  group('curved PathSegment', () {
    const curve = PathSegment(
      start: Offset(0, 0),
      startControl: Offset(0, 30),
      endControl: Offset(30, 30),
      end: Offset(30, 0),
    );

    test('evaluates tangents, projections and split geometry', () {
      expect(curve.isCurve, isTrue);
      expect(curve.pointAt(-1), curve.start);
      expect(curve.pointAt(0.5), const Offset(15, 22.5));
      expect(curve.pointAt(2), curve.end);
      expect(curve.tangentAt(0), const Offset(0, 90));
      expect(curve.tangentAt(1), const Offset(0, -90));
      expect(curve.midpoint, const Offset(15, 22.5));
      expect(curve.project(const Offset(15, 20)).distance, lessThan(3));
      expect(curve.distanceTo(const Offset(15, 20)), lessThan(3));

      final (left, right) = curve.splitAt(0.5);
      expect(left.start, curve.start);
      expect(right.end, curve.end);
      expect(left.end, right.start);
      expect(left.pointAt(0.5), curve.pointAt(0.25));
      expect(right.pointAt(0.5), curve.pointAt(0.75));

      final path = Path()..moveTo(curve.start.dx, curve.start.dy);
      curve.addTo(path);
      expect(path.getBounds().isEmpty, isFalse);
      expect(curve.toString(), contains('PathSegment.curve'));
      expect(curve, curve);
      expect(curve == Object(), isFalse);
    });

    test('falls back for a degenerate tangent', () {
      const degenerate = PathSegment(
        start: Offset.zero,
        startControl: Offset.zero,
        endControl: Offset.zero,
        end: Offset(10, 0),
      );
      expect(degenerate.tangentAt(0), const Offset(10, 0));
      expect(degenerate.tangentAt(1), const Offset(30, 0));
    });

    test('handles cubic extrema with linear and quadratic derivatives', () {
      const twoRoots = PathSegment(
        start: Offset.zero,
        startControl: Offset(100, 100),
        endControl: Offset(-100, -100),
        end: Offset.zero,
      );
      expect(twoRoots.bounds.isFinite, isTrue);

      const noRoots = PathSegment(
        start: Offset.zero,
        startControl: Offset(1 / 3, 1 / 3),
        endControl: Offset(2 / 3, 2 / 3),
        end: Offset(2, 2),
      );
      expect(noRoots.bounds, const Rect.fromLTRB(0, 0, 2, 2));
    });
  });
}
