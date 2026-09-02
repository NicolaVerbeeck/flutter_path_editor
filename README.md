# Path Editor

[![Version](https://img.shields.io/pub/v/path_editor.svg)](https://pub.dev/packages/path_editor)
[![test](https://github.com/NicolaVerbeeck/flutter_path_editor/actions/workflows/pr-cicd.yml/badge.svg)](https://github.com/NicolaVerbeeck/flutter_path_editor/actions/workflows/pr-cicd.yml/badge.svg)
[![codecov](https://codecov.io/gh/NicolaVerbeeck/flutter_path_editor/graph/badge.svg?token=20CAT9JC3Y)](https://codecov.io/gh/NicolaVerbeeck/flutter_path_editor)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/NicolaVerbeeck/flutter_path_editor/badge)](https://securityscorecards.dev/viewer/?uri=github.com/NicolaVerbeeck/flutter_path_editor)
[![live_demo](https://img.shields.io/badge/Live%20Demo-Available-7D64F2)](https://nicolaverbeeck.github.io/flutter_path_editor/)

A Flutter widget for visually editing vector paths, with a design-tool style pen tool.

## Features

- **Pen tool** — click to place corner points, click and drag to pull out Bézier
  handles, click the first point to close the path.
- **Point editing** — select one or many points, drag them around, insert points
  on a segment without changing its shape, and remove them while either
  preserving the shape or cutting the path.
- **Linked and broken handles** — smooth points keep their handles aligned
  through the anchor; hold the break modifier to move a handle independently.
- **Corner ⇄ smooth conversion** at any time.
- **Snapping** to other points, segment midpoints and alignment axes, with
  visual guides and a modifier to switch it off.
- **Contextual cursors** for every interaction.
- **Zoom and pan aware** — the path scales, the editing chrome does not.
- **Undo and redo**, with a whole gesture collapsing into a single step.
- **Everything is configurable**: colours, sizes, shapes, cursors, modifier
  keys, keyboard shortcuts, snapping and hit radii.

## Getting started

```dart
final controller = PathEditorController.fromSvg('M20 20L180 100L100 180');

PathEditor(controller: controller);
```

To start from a blank canvas with the pen tool ready:

```dart
final controller = PathEditorController.empty();
```

Read the result back at any time:

```dart
controller.svg;         // 'M20.0 20.0L180.0 100.0L100.0 180.0'
controller.uiPath;      // a dart:ui Path, ready to paint
controller.operators;   // absolute move/line/cubic operators
controller.bounds(strokeWidth: 2);
```

## Controller

`PathEditorController` owns the path, the selection and the active tool, and
exposes a separate listenable for each so widgets rebuild only on what they
care about:

```dart
ValueListenableBuilder(
  valueListenable: controller.pathListenable,
  builder: (context, path, _) => Text(path.toSvg()),
);
```

Edits go through the controller and are undoable. Use a transaction to collapse
several edits into one undo step:

```dart
controller.transaction(() {
  controller.convertNodes(controller.selection.nodes, PathNodeType.mirrored);
  controller.moveNodes(controller.selection.nodes, const Offset(0, -10));
});

controller.undo();
controller.redo();
```

## The model

A path is a list of subpaths, and every subpath is a list of nodes. A node owns
the two Bézier handles around it, which is what makes linked handles and
corner ⇄ smooth conversion possible:

```dart
class PathNode {
  Offset position;
  Offset? incoming;  // controls the segment arriving at the node
  Offset? outgoing;  // controls the segment leaving the node
  PathNodeType type;
}
```

| `PathNodeType` | Meaning |
|---|---|
| `corner` | No handles. Segments meet at a sharp angle. |
| `mirrored` | Handles collinear and equal length; moving one mirrors the other. |
| `aligned` | Handles collinear, independent lengths; moving one rotates the other. |
| `disconnected` | Broken handles that move completely independently. |

Nodes, segments and handles are addressed by `NodeRef`, `SegmentRef` and
`HandleRef`. Paths convert losslessly to and from SVG, so anything you draw
stays compatible with SVG, PDF and any other consumer of the operator list.

## Tools

```dart
controller.tool = PathTool.pen;     // create points, close paths, insert points
controller.tool = PathTool.select;  // select, move and reshape existing points
```

With the pen tool a click places a corner point, a click and drag pulls out a
symmetric pair of handles, clicking a segment inserts a point on it without
changing its shape, and clicking the first point of the path closes it.

By default the pen may start a second, disconnected subpath once the current
one is finished. Editors that must produce a single continuous path can turn
that off, after which clicking empty canvas does nothing and the cursor falls
back to `idle`:

```dart
PathEditor(
  controller: controller,
  behavior: const PathEditorBehavior(allowMultipleSubpaths: false),
);
```

Paths that already contain several subpaths keep loading, rendering and editing
normally either way.

## Theming

Every colour, size and shape lives in `PathEditorThemeData`:

```dart
PathEditor(
  controller: controller,
  theme: const PathEditorThemeData(
    strokeColor: Color(0xFF000000),
    strokeWidth: 1,
    activeSegmentColor: Color(0xFF4E80F9),
    cornerNodeStyle: PathNodeStyle(
      shape: PathNodeShape.square,
      radius: 3.5,
      fillColor: Color(0xFFFFFFFF),
      borderColor: Color(0xFF4E80F9),
    ),
  ),
);
```

There is a `PathEditorThemeData.light` and a `PathEditorThemeData.dark`, both
`copyWith`-able and `lerp`-able. A theme can also be provided to a whole
subtree:

```dart
PathEditorTheme(
  data: PathEditorThemeData.dark,
  child: PathEditor(controller: controller),
);
```

Node sizes, handle sizes, indicators and guides are expressed in **screen**
pixels, so they stay readable at any zoom level, while the path stroke is
expressed in scene units and scales with the artwork.

## Cursors

Every contextual state maps to a `MouseCursor`:

```dart
PathEditor(
  controller: controller,
  cursors: const PathEditorCursors(
    closePath: SystemMouseCursors.cell,
    addPoint: SystemMouseCursors.copy,
  ),
);
```

The states are `idle`, `selectPoint`, `movePoint`, `addPoint`, `removePoint`,
`closePath`, `adjustHandle`, `penReady` and `penDraw`.

## Modifier keys

```dart
PathEditor(
  controller: controller,
  modifiers: const PathEditorModifiers(
    multiSelect: KeyModifier.shift,
    breakHandle: KeyModifier.alt,
    bendPoint: KeyModifier.controlOrMeta,
    disableSnapping: KeyModifier.controlOrMeta,
    constrainAngle: KeyModifier.shift,
    removeNode: KeyModifier.alt,
    cutPath: KeyModifier.alt,
  ),
);
```

### Bending a point

Holding `bendPoint` (command on macOS, control elsewhere) turns a drag on an
existing point into a curvature drag, the way the bend tool works in design
tools like Figma. The point stays exactly where it is while its handles are
pulled out, so a corner point becomes a smooth one on the first drag and a
point that is already smooth keeps being reshaped. Points with broken handles
keep them broken.

`bendPoint` and `disableSnapping` share a default, which is deliberate: a bend
should not snap. The consequence is that the default bindings give you no way
to move a point with snapping turned off, because the drag bends instead. Remap
either modifier if you need them separated:

```dart
const PathEditorModifiers(disableSnapping: KeyModifier.control);
```

`KeyModifier.controlOrMeta` resolves to command on Apple platforms and control
everywhere else. Use `KeyModifier.none` to disable a behaviour, or
`KeyModifier.custom` for anything else:

```dart
KeyModifier.custom(
  'shiftAndAlt',
  (keyboard) => keyboard.isShiftPressed && keyboard.isAltPressed,
);
```

## Keyboard shortcuts

The editor uses Flutter's `Shortcuts` and `Actions`, so the bindings are
ordinary shortcut maps:

| Shortcut | Action |
|---|---|
| `Delete` / `Backspace` | remove the selected points |
| `Escape` | stop extending the current path |
| `Enter` | close the current path |
| `Ctrl`/`Cmd` + `A` | select every point |
| `Ctrl`/`Cmd` + `Z` | undo |
| `Ctrl`/`Cmd` + `Shift` + `Z` | redo |
| arrow keys | nudge the selection |
| `Shift` + arrow keys | nudge the selection further |
| `V` / `P` | select and pen tool |

Pass your own map to replace them:

```dart
PathEditor(
  controller: controller,
  shortcuts: {
    ...PathEditorShortcuts.defaults,
    const SingleActivator(LogicalKeyboardKey.keyC):
        const ConvertNodesIntent(PathNodeType.corner),
  },
);
```

The same intents can be invoked from a toolbar with `Actions.invoke`.

## Snapping

```dart
PathEditor(
  controller: controller,
  snapping: const PathEditorSnapping(
    snapToNodes: true,
    snapToMidpoints: true,
    snapToAxes: true,
    threshold: 6,       // screen pixels
    angleIncrement: 15, // degrees, for the constrain modifier
  ),
);
```

Snapping applies while creating points, moving points and adjusting handles,
draws guides for whatever it matched, and is suppressed while the
`disableSnapping` modifier is held. Use `PathEditorSnapping.disabled` to switch
it off entirely.

## Zoom and pan

`PathEditorViewport` maps the path onto the widget. Hit radii and editing
chrome are converted through it, so grabbing a point feels the same at any zoom
level:

```dart
PathEditor(
  controller: controller,
  viewport: viewport,
);

// Zoom around the pointer while keeping that point in place.
viewport = viewport.zoomedAround(event.localPosition, viewport.scale * 1.1);
```

## Reacting to edits

```dart
PathEditor(
  controller: controller,
  onSegmentCreated: (segment) => openStrokePanel(),
  onNodeAdded: (node) {},
  onNodesRemoved: (nodes) {},
  onSubpathClosed: (subpath) {},
  onPathChanged: (path) {},
  onSelectionChanged: (selection) {},
  onToolChanged: (tool) {},
);
```

`onSegmentCreated` fires as the pen places the second point of a path, which is
the usual moment to open a stroke settings panel.

## Removing points

Removing a point has two very different meanings, and both are supported:

```dart
// Simplify: the point disappears, the path stays connected and the surrounding
// curve is refitted so the shape is preserved.
controller.removeNodes(nodes);

// Cut: the path is broken at the point.
controller.removeNodes(nodes, mode: NodeRemoval.cut);
```

A cut is refused, and `canRemoveNodes` returns `false`, when it would leave the
path with more than one open subpath.

## Migrating from 0.0.x

Version 0.1.0 replaces the operator centric API with a node centric one. The
`PathOperator` family is unchanged and still used for SVG conversion.

| 0.0.x | 0.1.0 |
|---|---|
| `PathEditorController('M0 0')` | `PathEditorController.fromSvg('M0 0')` |
| `controller.value.pathString` | `controller.svg` |
| `controller.path` (a `ui.Path`) | `controller.uiPath` |
| `controller.operators` | still there, or `controller.path` for the node model |
| `PathPointIndex(i)` | `NodeRef(subpath, node)` |
| `PathSegmentIndex(i)` | `SegmentRef(subpath, index)` |
| `ControlPointIndex(0 or 1)` | `HandleRef(node, NodeHandle.incoming)` |
| `controller.insertPoint(...)` | `controller.insertNodeOn(segment, t)` |
| `controller.updatePointPosition(...)` | `controller.moveNode(...)` |
| `controller.updateControlPointPosition(...)` | `controller.setHandle(...)` |
| `controller.beginUpdate()` / `endUpdate()` | `controller.transaction(...)` |
| `controller.calculateBoundingBox(w)` | `controller.bounds(strokeWidth: w)` |
| `PathEditor(strokeColor:, controlPointColor:, ...)` | `PathEditor(theme: PathEditorThemeData(...))` |
| `PathEditor(renderOffset:)` | `PathEditor(viewport: PathEditorViewport(offset:))` |

The default stroke width changed from `2` to `1` and the segment highlight from
`Colors.blue` to `#4E80F9`.

## Additional information

Paths are transformed into absolute mode and all operations are remapped to
`MoveTo`, `LineTo` and `CubicTo`. This ensures the paths are compatible with all
outputs such as SVG and PDF.

For more information, visit the
[GitHub repository](https://github.com/NicolaVerbeeck/flutter_path_editor).

If you encounter any issues or have feature requests, please file them on the
[issue tracker](https://github.com/NicolaVerbeeck/flutter_path_editor/issues).
