# path_editor example

A demo of the `path_editor` package showing the pen tool and how configurable
the editor is.

## What it demonstrates

- Switching between the **select** and **pen** tools.
- Drawing with the pen: click for corner points, click and drag for smooth
  points, click a segment to insert a point, click the first point to close.
- Converting the selection between corner, smooth and broken handles.
- Removing points either preserving the shape or cutting the path; the cut
  button disables itself when the cut is not allowed.
- A stroke settings panel that opens automatically through `onSegmentCreated`
  as the first segment appears, and drives the editor theme.
- Toggling snapping, a dark canvas and a completely custom theme.
- Zooming with the mouse wheel or the toolbar; the path scales while the
  editing chrome keeps its size.
- Undo and redo, and the live SVG output of the path.

## Running

```sh
flutter run
```

The project ships without platform folders; run `flutter create .` first if
your platform of choice is missing.
