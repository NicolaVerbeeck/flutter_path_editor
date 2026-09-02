/// A Flutter widget for visually editing vector paths, with a full pen tool.
///
/// The entry points are [PathEditorController], which owns the path, the
/// selection and the active tool, and [PathEditor], the widget that renders
/// and edits it.
library;

export 'src/config/path_editor_behavior.dart';
export 'src/config/path_editor_callbacks.dart';
export 'src/config/path_editor_cursors.dart';
export 'src/config/path_editor_modifiers.dart';
export 'src/config/path_editor_shortcuts.dart';
export 'src/config/path_editor_snapping.dart';
export 'src/config/path_editor_theme.dart';
export 'src/config/path_editor_viewport.dart';
export 'src/controller/path_editor_controller.dart';
export 'src/controller/path_editor_selection.dart';
export 'src/interaction/hit_test.dart';
export 'src/interaction/snap_engine.dart';
export 'src/interaction/tool_handler.dart';
export 'src/model/editable_path.dart';
export 'src/model/path_edits.dart';
export 'src/model/path_node.dart';
export 'src/model/path_operators.dart';
export 'src/model/path_segment.dart';
export 'src/painting/path_editor_painter.dart';
export 'src/widget/path_editor.dart';
