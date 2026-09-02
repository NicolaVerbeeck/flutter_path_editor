import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_editor/path_editor.dart';

void main() => runApp(const PathEditorDemoApp());

class PathEditorDemoApp extends StatelessWidget {
  const PathEditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Path editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4E80F9),
          useMaterial3: true,
        ),
        home: const EditorPage(),
      );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static const _samplePath =
      'M120 300C120 180 220 120 320 180C420 240 380 380 280 380'
      'C200 380 160 340 120 300Z';

  late final PathEditorController _controller;

  // The stroke settings the demo application owns. The editor only reports
  // that a segment was created; opening a panel is an application concern.
  Color _strokeColor = const Color(0xFF000000);
  double _strokeWeight = 1;
  bool _showStrokePanel = false;

  bool _snappingEnabled = true;
  bool _darkCanvas = false;
  bool _playfulTheme = false;
  PathEditorViewport _viewport = const PathEditorViewport(
    offset: Offset(40, 20),
  );

  @override
  void initState() {
    super.initState();
    _controller = PathEditorController.fromSvg(_samplePath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PathEditorThemeData get _theme {
    final base =
        _darkCanvas ? PathEditorThemeData.dark : PathEditorThemeData.light;
    final themed = base.copyWith(
      strokeColor: _strokeColor,
      strokeWidth: _strokeWeight,
    );
    if (!_playfulTheme) return themed;

    // Proving that nothing is hardcoded: a completely different look.
    return themed.copyWith(
      activeSegmentColor: const Color(0xFFFF6B00),
      hoveredSegmentColor: const Color(0x99FF6B00),
      cornerNodeStyle: const PathNodeStyle(
        shape: PathNodeShape.diamond,
        radius: 5,
        fillColor: Color(0xFFFFE08A),
        borderColor: Color(0xFF8A4B00),
        borderWidth: 1.5,
      ),
      smoothNodeStyle: const PathNodeStyle(
        shape: PathNodeShape.circle,
        radius: 5,
        fillColor: Color(0xFFFFE08A),
        borderColor: Color(0xFF8A4B00),
        borderWidth: 1.5,
      ),
      selectedNodeStyle: const PathNodeStyle(
        shape: PathNodeShape.circle,
        radius: 6,
        fillColor: Color(0xFFFF6B00),
        borderColor: Color(0xFFFFFFFF),
        borderWidth: 2,
      ),
      handleStyle: const PathNodeStyle(
        shape: PathNodeShape.square,
        radius: 4,
        fillColor: Color(0xFFFF6B00),
        borderColor: Color(0xFFFFFFFF),
      ),
      handleLineColor: const Color(0x99FF6B00),
      snapGuideColor: const Color(0xFF00B3A4),
      snapTargetColor: const Color(0xFF00B3A4),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Path editor'),
          actions: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Undo',
                    onPressed: _controller.canUndo ? _controller.undo : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    tooltip: 'Redo',
                    onPressed: _controller.canRedo ? _controller.redo : null,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _Toolbar(
              controller: _controller,
              snappingEnabled: _snappingEnabled,
              darkCanvas: _darkCanvas,
              playfulTheme: _playfulTheme,
              onSnappingChanged: (value) =>
                  setState(() => _snappingEnabled = value),
              onDarkCanvasChanged: (value) =>
                  setState(() => _darkCanvas = value),
              onPlayfulThemeChanged: (value) =>
                  setState(() => _playfulTheme = value),
              onZoom: _zoomBy,
              onResetView: () => setState(
                () => _viewport = const PathEditorViewport(
                  offset: Offset(40, 20),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCanvas()),
                  if (_showStrokePanel) ...[
                    const VerticalDivider(width: 1),
                    _StrokePanel(
                      color: _strokeColor,
                      weight: _strokeWeight,
                      onColorChanged: (value) =>
                          setState(() => _strokeColor = value),
                      onWeightChanged: (value) =>
                          setState(() => _strokeWeight = value),
                      onClose: () => setState(() => _showStrokePanel = false),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            _SvgOutput(controller: _controller),
          ],
        ),
      );

  Widget _buildCanvas() => ColoredBox(
        color: _darkCanvas ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            _zoomAround(
                event.localPosition, event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
          },
          child: PathEditor(
            controller: _controller,
            autofocus: true,
            theme: _theme,
            viewport: _viewport,
            snapping: _snappingEnabled
                ? const PathEditorSnapping()
                : PathEditorSnapping.disabled,
            // Cursors, modifier keys, shortcuts and hit radii are all
            // remappable; see PathEditorModifiers, PathEditorShortcuts and
            // PathEditorBehavior.
            cursors: const PathEditorCursors(
              closePath: SystemMouseCursors.cell,
              addPoint: SystemMouseCursors.copy,
            ),
            // This demo edits a single path, so the pen is not allowed to
            // start a second, disconnected one.
            behavior: const PathEditorBehavior(allowMultipleSubpaths: false),
            onSegmentCreated: (_) {
              // The specification asks for the stroke panel to open as soon as
              // the pen draws its first segment.
              if (!_showStrokePanel) {
                setState(() => _showStrokePanel = true);
              }
            },
          ),
        ),
      );

  void _zoomBy(double factor) {
    final size = context.size;
    _zoomAround(
      size == null ? Offset.zero : Offset(size.width / 2, size.height / 2),
      factor,
    );
  }

  void _zoomAround(Offset focalPoint, double factor) {
    setState(() {
      _viewport = _viewport.zoomedAround(
        focalPoint,
        (_viewport.scale * factor).clamp(0.2, 8.0),
      );
    });
  }
}

class _Toolbar extends StatelessWidget {
  final PathEditorController controller;
  final bool snappingEnabled;
  final bool darkCanvas;
  final bool playfulTheme;
  final ValueChanged<bool> onSnappingChanged;
  final ValueChanged<bool> onDarkCanvasChanged;
  final ValueChanged<bool> onPlayfulThemeChanged;
  final ValueChanged<double> onZoom;
  final VoidCallback onResetView;

  const _Toolbar({
    required this.controller,
    required this.snappingEnabled,
    required this.darkCanvas,
    required this.playfulTheme,
    required this.onSnappingChanged,
    required this.onDarkCanvasChanged,
    required this.onPlayfulThemeChanged,
    required this.onZoom,
    required this.onResetView,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ListenableBuilder(
                listenable: controller.toolListenable,
                builder: (context, _) => SegmentedButton<PathTool>(
                  segments: const [
                    ButtonSegment(
                      value: PathTool.select,
                      icon: Icon(Icons.near_me_outlined),
                      label: Text('Select'),
                      tooltip: 'V',
                    ),
                    ButtonSegment(
                      value: PathTool.pen,
                      icon: Icon(Icons.edit_outlined),
                      label: Text('Pen'),
                      tooltip: 'P',
                    ),
                  ],
                  selected: {controller.tool},
                  onSelectionChanged: (selection) =>
                      controller.tool = selection.first,
                ),
              ),
              const SizedBox(width: 16),
              ListenableBuilder(
                listenable: controller.selectionListenable,
                builder: (context, _) => _NodeActions(controller: controller),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Snap'),
                selected: snappingEnabled,
                onSelected: onSnappingChanged,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Dark canvas'),
                selected: darkCanvas,
                onSelected: onDarkCanvasChanged,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Custom theme'),
                selected: playfulTheme,
                onSelected: onPlayfulThemeChanged,
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Zoom out',
                onPressed: () => onZoom(1 / 1.25),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zoom in',
                onPressed: () => onZoom(1.25),
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined),
                tooltip: 'Reset view',
                onPressed: onResetView,
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Shortcuts and modifiers',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const _ShortcutsHelp(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ShortcutsHelp extends StatelessWidget {
  const _ShortcutsHelp();

  @override
  Widget build(BuildContext context) {
    // The editor resolves its primary modifier per platform, so the help has
    // to say the same thing the editor actually listens for.
    final isApple = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final primary = isApple ? 'Cmd' : 'Ctrl';

    const rows = <(String, String)>[
      ('Click', 'Place a corner point'),
      ('Click + drag', 'Place a smooth point and pull out its handles'),
      ('Click the first point', 'Close the path'),
      ('Click a segment', 'Insert a point on it'),
      ('Shift + click', 'Add or remove a point from the selection'),
      ('Alt + drag a handle', 'Break the handles apart'),
      ('Alt + click a point', 'Remove it (pen tool)'),
      ('Shift + drag', 'Constrain a handle to fixed angles'),
      ('Delete', 'Remove the selected points, keeping the shape'),
      ('Escape', 'Stop extending the current path'),
      ('Enter', 'Close the current path'),
      ('Arrow keys', 'Nudge the selection'),
      ('V / P', 'Select and pen tool'),
    ];

    return AlertDialog(
      title: const Text('Shortcuts and modifiers'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, description) in rows)
                _HelpRow(keys: keys, description: description),
              _HelpRow(
                keys: '$primary + drag a point',
                description: 'Bend it: pull out handles, making it smooth',
              ),
              _HelpRow(
                keys: '$primary + drag',
                description: 'Temporarily turn snapping off',
              ),
              _HelpRow(
                keys: '$primary + Z',
                description: 'Undo (add Shift to redo)',
              ),
              _HelpRow(
                keys: '$primary + A',
                description: 'Select every point',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String keys;
  final String description;

  const _HelpRow({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                keys,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: Text(description)),
          ],
        ),
      );
}

class _NodeActions extends StatelessWidget {
  final PathEditorController controller;

  const _NodeActions({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasSelection = controller.selection.isNotEmpty;
    final canCut = hasSelection &&
        controller.canRemoveNodes(
          controller.selection.nodes,
          mode: NodeRemoval.cut,
        );

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.linear_scale),
          tooltip: 'Make corner',
          onPressed: hasSelection
              ? () => controller.transaction(
                    () => controller.convertNodes(
                      controller.selection.nodes,
                      PathNodeType.corner,
                    ),
                  )
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.bubble_chart_outlined),
          tooltip: 'Make smooth',
          onPressed: hasSelection
              ? () => controller.transaction(
                    () => controller.convertNodes(
                      controller.selection.nodes,
                      PathNodeType.mirrored,
                    ),
                  )
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.call_split),
          tooltip: 'Make handles independent',
          onPressed: hasSelection
              ? () => controller.transaction(
                    () => controller.convertNodes(
                      controller.selection.nodes,
                      PathNodeType.disconnected,
                    ),
                  )
              : null,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove, keeping the shape',
          onPressed: hasSelection
              ? () => controller.removeNodes(controller.selection.nodes)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.content_cut),
          // Cutting is refused when it would leave two open paths.
          tooltip: canCut ? 'Cut the path here' : 'Cutting here is not allowed',
          onPressed: canCut
              ? () => controller.removeNodes(
                    controller.selection.nodes,
                    mode: NodeRemoval.cut,
                  )
              : null,
        ),
      ],
    );
  }
}

class _StrokePanel extends StatelessWidget {
  static const _palette = [
    Color(0xFF000000),
    Color(0xFF4E80F9),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
  ];

  final Color color;
  final double weight;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onClose;

  const _StrokePanel({
    required this.color,
    required this.weight,
    required this.onColorChanged,
    required this.onWeightChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Stroke',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Colour'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in _palette)
                    GestureDetector(
                      onTap: () => onColorChanged(option),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: option,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: option == color
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black26,
                            width: option == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Weight: ${weight.toStringAsFixed(1)}'),
              Slider(
                value: weight,
                min: 0.5,
                max: 12,
                onChanged: onWeightChanged,
              ),
            ],
          ),
        ),
      );
}

class _SvgOutput extends StatelessWidget {
  final PathEditorController controller;

  const _SvgOutput({required this.controller});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 84,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListenableBuilder(
          listenable: controller.pathListenable,
          builder: (context, _) => SingleChildScrollView(
            child: SelectableText(
              controller.svg.isEmpty ? '(empty path)' : controller.svg,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      );
}
