import 'package:flutter/foundation.dart';
import 'package:path_editor/src/controller/path_editor_selection.dart';
import 'package:path_editor/src/model/editable_path.dart';

/// Called when the path changed.
typedef PathChangedCallback = void Function(EditablePath path);

/// Called when the selection changed.
typedef PathSelectionChangedCallback = void Function(
    PathEditorSelection selection);

/// Called when the active tool changed.
typedef PathToolChangedCallback = void Function(PathTool tool);

/// Called when a node was added by the pen tool.
typedef PathNodeAddedCallback = void Function(NodeRef node);

/// Called when nodes were removed.
typedef PathNodesRemovedCallback = void Function(Iterable<NodeRef> nodes);

/// Called when a new segment was drawn between two nodes.
typedef PathSegmentCreatedCallback = void Function(SegmentRef segment);

/// Called when a subpath was closed.
typedef PathSubpathClosedCallback = void Function(int subpath);

/// The callbacks a [PathEditor] can report editing events through.
///
/// These exist so the surrounding application can react to editing without
/// polling: the classic example is opening a stroke settings panel as soon as
/// the pen tool draws its first segment, which is what [onSegmentCreated] is
/// for.
@immutable
class PathEditorCallbacks {
  /// Called whenever the path changed, for any reason.
  final PathChangedCallback? onPathChanged;

  /// Called whenever the selection changed.
  final PathSelectionChangedCallback? onSelectionChanged;

  /// Called whenever the active tool changed.
  final PathToolChangedCallback? onToolChanged;

  /// Called when the pen tool added a node.
  final PathNodeAddedCallback? onNodeAdded;

  /// Called when nodes were removed.
  final PathNodesRemovedCallback? onNodesRemoved;

  /// Called when a segment was created between two nodes.
  ///
  /// The first segment of a path is created as the second node is placed,
  /// which is the moment a stroke settings panel typically opens.
  final PathSegmentCreatedCallback? onSegmentCreated;

  /// Called when a subpath was closed.
  final PathSubpathClosedCallback? onSubpathClosed;

  /// Creates a callback set.
  const PathEditorCallbacks({
    this.onPathChanged,
    this.onSelectionChanged,
    this.onToolChanged,
    this.onNodeAdded,
    this.onNodesRemoved,
    this.onSegmentCreated,
    this.onSubpathClosed,
  });

  /// A callback set that reports nothing.
  static const PathEditorCallbacks none = PathEditorCallbacks();

  /// Returns a copy of this set with the given callbacks replaced.
  PathEditorCallbacks copyWith({
    PathChangedCallback? onPathChanged,
    PathSelectionChangedCallback? onSelectionChanged,
    PathToolChangedCallback? onToolChanged,
    PathNodeAddedCallback? onNodeAdded,
    PathNodesRemovedCallback? onNodesRemoved,
    PathSegmentCreatedCallback? onSegmentCreated,
    PathSubpathClosedCallback? onSubpathClosed,
  }) =>
      PathEditorCallbacks(
        onPathChanged: onPathChanged ?? this.onPathChanged,
        onSelectionChanged: onSelectionChanged ?? this.onSelectionChanged,
        onToolChanged: onToolChanged ?? this.onToolChanged,
        onNodeAdded: onNodeAdded ?? this.onNodeAdded,
        onNodesRemoved: onNodesRemoved ?? this.onNodesRemoved,
        onSegmentCreated: onSegmentCreated ?? this.onSegmentCreated,
        onSubpathClosed: onSubpathClosed ?? this.onSubpathClosed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorCallbacks &&
          onPathChanged == other.onPathChanged &&
          onSelectionChanged == other.onSelectionChanged &&
          onToolChanged == other.onToolChanged &&
          onNodeAdded == other.onNodeAdded &&
          onNodesRemoved == other.onNodesRemoved &&
          onSegmentCreated == other.onSegmentCreated &&
          onSubpathClosed == other.onSubpathClosed);

  @override
  int get hashCode => Object.hash(
        onPathChanged,
        onSelectionChanged,
        onToolChanged,
        onNodeAdded,
        onNodesRemoved,
        onSegmentCreated,
        onSubpathClosed,
      );
}
