import 'package:flutter_test/flutter_test.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  final path = EditablePath.fromSvg('M0 0L10 0L20 0');
  const first = NodeRef(0, 0);
  const middle = NodeRef(0, 1);
  const last = NodeRef(0, 2);
  const handle = HandleRef(middle, NodeHandle.outgoing);

  group('selection state', () {
    test('reports membership and cardinality', () {
      const empty = PathEditorSelection.empty;
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(empty.isMultiple, isFalse);
      expect(empty.contains(first), isFalse);

      final selection = PathEditorSelection(
        nodes: {first, middle},
        active: middle,
        activeHandle: handle,
        pendingSubpath: 0,
      );
      expect(selection.isEmpty, isFalse);
      expect(selection.isNotEmpty, isTrue);
      expect(selection.isMultiple, isTrue);
      expect(selection.contains(first), isTrue);
      expect(selection.contains(last), isFalse);
    });

    test('copies and clears each optional property', () {
      final selection = PathEditorSelection(
        nodes: {first, middle},
        active: middle,
        activeHandle: handle,
        pendingSubpath: 0,
      );

      final copy = selection.copyWith(
        nodes: {last},
        active: last,
        activeHandle: const HandleRef(last, NodeHandle.incoming),
        pendingSubpath: 2,
      );
      expect(copy.nodes, {last});
      expect(copy.active, last);
      expect(copy.activeHandle, const HandleRef(last, NodeHandle.incoming));
      expect(copy.pendingSubpath, 2);

      final cleared = selection.copyWith(
        clearActive: true,
        clearActiveHandle: true,
        clearPendingSubpath: true,
      );
      expect(cleared.active, isNull);
      expect(cleared.activeHandle, isNull);
      expect(cleared.pendingSubpath, isNull);
    });

    test('selects, adds, removes, toggles and clears nodes', () {
      final selection = PathEditorSelection.single(first, pendingSubpath: 0);
      expect(selection.selectOnly(last).nodes, {last});
      expect(selection.selectOnly(last).active, last);
      expect(selection.add(middle).nodes, {first, middle});
      expect(selection.add(middle).active, middle);
      expect(selection.remove(first).nodes, isEmpty);
      expect(selection.remove(first).active, isNull);
      expect(selection.remove(last).nodes, {first});
      expect(selection.toggle(middle).nodes, {first, middle});
      expect(selection.toggle(first).nodes, isEmpty);
      expect(selection.clear().nodes, isEmpty);
      expect(selection.clear().pendingSubpath, 0);
    });

    test('sanitizes stale nodes, handles and pending subpaths', () {
      final selection = PathEditorSelection(
        nodes: {first, const NodeRef(4, 4)},
        active: const NodeRef(4, 4),
        activeHandle: const HandleRef(NodeRef(4, 4), NodeHandle.incoming),
        pendingSubpath: 4,
      );
      final sanitized = selection.sanitized(path);

      expect(sanitized.nodes, {first});
      expect(sanitized.active, isNull);
      expect(sanitized.activeHandle, isNull);
      expect(sanitized.pendingSubpath, isNull);
      final unchanged = PathEditorSelection.single(first, pendingSubpath: 0);
      expect(unchanged.sanitized(path), same(unchanged));

      final closed = EditablePath.fromSvg('M0 0L10 0Z');
      expect(
        PathEditorSelection.single(first, pendingSubpath: 0)
            .sanitized(closed)
            .pendingSubpath,
        isNull,
      );
    });

    test('reports selected node types and value semantics', () {
      final smoothPath = EditablePath.fromSvg('M0 0L10 0C15 0 15 10 20 10');
      final selection = PathEditorSelection(
        nodes: {first, middle, last, const NodeRef(2, 0)},
        active: first,
      );

      expect(selection.typesIn(smoothPath), {
        PathNodeType.corner,
        PathNodeType.disconnected,
      });
      expect(selection, selection.copyWith());
      expect(selection.hashCode, selection.copyWith().hashCode);
      expect(selection.toString(), contains('4 nodes'));
      expect(selection == Object(), isFalse);
    });
  });
}
