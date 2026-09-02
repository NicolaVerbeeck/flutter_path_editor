import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_editor/src/config/path_editor_behavior.dart';
import 'package:path_editor/src/config/path_editor_callbacks.dart';
import 'package:path_editor/src/config/path_editor_cursors.dart';
import 'package:path_editor/src/config/path_editor_modifiers.dart';
import 'package:path_editor/src/config/path_editor_shortcuts.dart';
import 'package:path_editor/src/config/path_editor_snapping.dart';
import 'package:path_editor/src/config/path_editor_theme.dart';
import 'package:path_editor/src/config/path_editor_viewport.dart';
import 'package:path_editor/src/controller/path_editor_controller.dart';
import 'package:path_editor/src/interaction/tool_handler.dart';
import 'package:path_editor/src/painting/path_editor_painter.dart';

/// An interactive editor for a vector path.
///
/// The editor draws the path of [controller] together with its nodes, Bézier
/// handles and contextual indicators, and turns pointer and keyboard input
/// into edits. Which tool is active, what is selected and what the path looks
/// like all live on the controller, so a surrounding application can drive and
/// observe the editor without reaching into the widget.
///
/// ```dart
/// final controller = PathEditorController.empty();
///
/// PathEditor(
///   controller: controller,
///   theme: const PathEditorThemeData(strokeColor: Color(0xFF000000)),
///   onSegmentCreated: (_) => openStrokePanel(),
/// );
/// ```
///
/// Everything the editor draws and every key it reacts to is configurable:
/// see [PathEditorThemeData], [PathEditorCursors], [PathEditorModifiers],
/// [PathEditorShortcuts], [PathEditorSnapping] and [PathEditorBehavior].
class PathEditor extends StatefulWidget {
  /// The controller holding the path, selection and active tool.
  final PathEditorController controller;

  /// The colours and sizes to draw with.
  ///
  /// Defaults to the nearest enclosing [PathEditorTheme], or to
  /// [PathEditorThemeData.light] when there is none.
  final PathEditorThemeData? theme;

  /// The cursor shown for each contextual state.
  final PathEditorCursors cursors;

  /// Which modifier key triggers which editing behaviour.
  final PathEditorModifiers modifiers;

  /// How positions snap while dragging and creating nodes.
  final PathEditorSnapping snapping;

  /// Hit radii and other interaction tuning.
  final PathEditorBehavior behavior;

  /// The pan and zoom applied to the path.
  final PathEditorViewport viewport;

  /// The keyboard shortcuts of the editor.
  ///
  /// Defaults to [PathEditorShortcuts.defaults].
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// The focus node of the editor. One is created when this is `null`.
  final FocusNode? focusNode;

  /// Whether the editor should grab focus when it is first shown.
  final bool autofocus;

  /// Called whenever the path changed.
  final PathChangedCallback? onPathChanged;

  /// Called whenever the selection changed.
  final PathSelectionChangedCallback? onSelectionChanged;

  /// Called whenever the active tool changed.
  final PathToolChangedCallback? onToolChanged;

  /// Called when the pen tool added a node.
  final PathNodeAddedCallback? onNodeAdded;

  /// Called when nodes were removed.
  final PathNodesRemovedCallback? onNodesRemoved;

  /// Called when a segment was drawn between two nodes.
  ///
  /// The first segment appears as the second node is placed, which is the
  /// moment a stroke settings panel typically opens.
  final PathSegmentCreatedCallback? onSegmentCreated;

  /// Called when a subpath was closed.
  final PathSubpathClosedCallback? onSubpathClosed;

  /// Creates a path editor.
  const PathEditor({
    super.key,
    required this.controller,
    this.theme,
    this.cursors = PathEditorCursors.defaults,
    this.modifiers = PathEditorModifiers.defaults,
    this.snapping = PathEditorSnapping.defaults,
    this.behavior = PathEditorBehavior.defaults,
    this.viewport = PathEditorViewport.identity,
    this.shortcuts,
    this.focusNode,
    this.autofocus = false,
    this.onPathChanged,
    this.onSelectionChanged,
    this.onToolChanged,
    this.onNodeAdded,
    this.onNodesRemoved,
    this.onSegmentCreated,
    this.onSubpathClosed,
  });

  @override
  State<PathEditor> createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor> {
  late PathEditorToolHandler _handler;
  late Listenable _repaint;

  /// Bumped whenever a modifier key is pressed or released, so the cursor and
  /// indicators reflect what a click would do right now.
  final ValueNotifier<int> _modifierRevision = ValueNotifier(0);

  FocusNode? _internalFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_internalFocusNode ??= FocusNode(debugLabel: 'PathEditor'));

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
    HardwareKeyboard.instance.addHandler(_handleRawKey);
  }

  @override
  void didUpdateWidget(covariant PathEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    } else {
      _handler.updateConfiguration(
        behavior: widget.behavior,
        modifiers: widget.modifiers,
        snapping: widget.snapping,
        callbacks: _callbacks,
        viewport: widget.viewport,
      );
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleRawKey);
    _detach(widget.controller);
    _modifierRevision.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _attach(PathEditorController controller) {
    _handler = PathEditorToolHandler(
      controller: controller,
      behavior: widget.behavior,
      modifiers: widget.modifiers,
      snapping: widget.snapping,
      callbacks: _callbacks,
      viewport: widget.viewport,
    );
    _repaint = Listenable.merge([controller, _handler, _modifierRevision]);

    controller.pathListenable.addListener(_handlePathChanged);
    controller.selectionListenable.addListener(_handleSelectionChanged);
    controller.toolListenable.addListener(_handleToolChanged);
  }

  void _detach(PathEditorController controller) {
    controller.pathListenable.removeListener(_handlePathChanged);
    controller.selectionListenable.removeListener(_handleSelectionChanged);
    controller.toolListenable.removeListener(_handleToolChanged);
    _handler.dispose();
  }

  PathEditorCallbacks get _callbacks => PathEditorCallbacks(
        onNodeAdded: widget.onNodeAdded,
        onNodesRemoved: widget.onNodesRemoved,
        onSegmentCreated: widget.onSegmentCreated,
        onSubpathClosed: widget.onSubpathClosed,
      );

  void _handlePathChanged() =>
      widget.onPathChanged?.call(widget.controller.path);

  void _handleSelectionChanged() =>
      widget.onSelectionChanged?.call(widget.controller.selection);

  void _handleToolChanged() =>
      widget.onToolChanged?.call(widget.controller.tool);

  bool _handleRawKey(KeyEvent event) {
    if (!_isModifier(event.logicalKey)) return false;
    // Never consume the event; the editor only wants to re-evaluate what the
    // current modifier state means for the cursor and indicators.
    _modifierRevision.value++;
    return false;
  }

  static bool _isModifier(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? PathEditorTheme.of(context);

    return ListenableBuilder(
      listenable: _repaint,
      builder: (context, _) => FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        mouseCursor: widget.cursors.resolve(_handler.cursorState),
        shortcuts: widget.shortcuts ?? PathEditorShortcuts.defaults,
        actions: buildPathEditorActions(
          controller: widget.controller,
          handler: _handler,
        ),
        child: MouseRegion(
          onHover: (event) => _handler.handleHover(event.localPosition),
          onExit: (_) => _handler.handleExit(),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerMove: (event) => _handler.handlePointerMove(
              event.localPosition,
              pointer: event.pointer,
            ),
            onPointerUp: (event) => _handler.handlePointerUp(
              event.localPosition,
              pointer: event.pointer,
            ),
            onPointerCancel: (event) =>
                _handler.handlePointerCancel(pointer: event.pointer),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: PathEditorPainter(
                  path: widget.controller.path,
                  selection: widget.controller.selection,
                  theme: theme,
                  viewport: widget.viewport,
                  activeSegment: _handler.activeSegment,
                  hoveredSegment: _handler.hoveredSegment,
                  hoveredNode: _handler.hoveredNode,
                  hoveredHandle: _handler.hoveredHandle,
                  insertIndicator: _handler.insertIndicator,
                  closeIndicator: _handler.closeIndicator,
                  penAnchor: _handler.penAnchor,
                  // The pointer only matters for the pen rubber band, so it is
                  // withheld otherwise to avoid repainting on every hover.
                  pointer: _handler.penAnchor == null ? null : _handler.pointer,
                  snapGuides: _handler.snapGuides,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Clicking the canvas gives it focus so the keyboard shortcuts apply.
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    _handler.handlePointerDown(event.localPosition, pointer: event.pointer);
  }
}
