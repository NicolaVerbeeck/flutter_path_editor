## 0.1.0-alpha.1

A rewrite of the editing model and the public API, adding a full pen tool. See
the migration table in the README for the 0.0.x equivalents.

### Added

* Pen tool: click to place corner points, click and drag to pull out Bézier
  handles, click a segment to insert a point, click the first point to close the
  path.
* Node centric model: `PathNode` owns the two handles around it, so handles can
  be linked (`mirrored`, `aligned`), broken (`disconnected`) or absent
  (`corner`), and nodes convert between those at any time.
* Multiple selection, with shift-click toggling and dragging the whole
  selection.
* Two ways to remove a point: `NodeRemoval.preserveShape` refits the surrounding
  curve so the shape survives, `NodeRemoval.cut` breaks the path. Cuts that
  would leave more than one open subpath are refused.
* Snapping to nodes, segment midpoints and alignment axes, with visual guides,
  an angle constraint and a modifier to suppress it.
* `PathEditorThemeData` and the `PathEditorTheme` inherited widget, with light
  and dark presets, `copyWith` and `lerp`.
* A bend interaction: holding `PathEditorModifiers.bendPoint` (command on macOS,
  control elsewhere) drags the curvature out of an existing point instead of
  moving it, converting a corner point into a smooth one, the way the bend tool
  works in design tools like Figma.
* `PathEditorBehavior.allowMultipleSubpaths`, which stops the pen tool from
  starting a second disconnected subpath for editors that must produce a single
  continuous path.
* `PathEditorCursors` for every contextual state, `PathEditorModifiers` for
  every modifier key, `PathEditorShortcuts` built on Flutter's
  `Shortcuts`/`Actions`, `PathEditorSnapping` and `PathEditorBehavior`.
* `PathEditorViewport` with pan and zoom; hit radii and editing chrome keep a
  constant size on screen at any zoom level.
* Editing callbacks, including `onSegmentCreated` for opening a stroke panel as
  the first segment appears.
* Transactions (`controller.transaction`), so a whole gesture is one undo step,
  and undo restores the selection it was made with.
* Keyboard support: delete, cut, close, finish, select all, nudge, undo, redo
  and tool switching.

### Changed

* **Breaking**: `PathEditorController` is now a `ChangeNotifier` owning the
  path, the selection and the active tool, built with
  `PathEditorController.fromSvg`, `.fromPath` or `.empty`. It exposes
  `pathListenable`, `selectionListenable` and `toolListenable`.
* **Breaking**: `PathPointIndex`, `PathSegmentIndex` and `ControlPointIndex`
  are replaced by `NodeRef`, `SegmentRef` and `HandleRef`, which address
  subpaths correctly.
* **Breaking**: the flat styling parameters of `PathEditor` are replaced by the
  configuration objects listed above, and `renderOffset` by `viewport`.
* **Breaking**: the default stroke width is now `1` (was `2`) and the active
  segment highlight is `#4E80F9` (was `Colors.blue`).
* Inserting a point on a curved segment now splits the curve with de Casteljau's
  algorithm instead of inserting a straight line, so the shape is unchanged.
* Bounding boxes are computed from exact curve extrema rather than by sampling,
  so `BoundsCheckAccuracy` is gone.
* The editor paints through a single layered painter inside a repaint boundary,
  and rebuilds through granular listenables instead of `setState` on every
  pointer move.

### Removed

* **Breaking**: `PathHolder`, `beginUpdate`/`endUpdate`, `insertPoint`,
  `updatePointPosition`, `updateControlPointPosition`, `controlPointsAt`,
  `calculateBoundingBox`, `calculateBoundingBoxOfPath` and
  `BoundsCheckAccuracy`.

## 0.0.3

* Add bounds calculation
* Add undo redo system

## 0.0.2

* Updates to pubspec
* Live demo with wasm support

## 0.0.1

* Initial version
