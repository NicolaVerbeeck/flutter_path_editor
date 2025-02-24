# Path Editor

[![Version](https://img.shields.io/pub/v/path_editor.svg)](https://pub.dev/packages/path_editor) [![codecov](https://codecov.io/gh/NicolaVerbeeck/flutter_path_editor/graph/badge.svg?token=20CAT9JC3Y)](https://codecov.io/gh/NicolaVerbeeck/flutter_path_editor)[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/NicolaVerbeeck/flutter_path_editor/badge)](https://securityscorecards.dev/viewer/?uri=github.com/NicolaVerbeeck/flutter_path_editor)


A Flutter widget for visually editing SVG paths.

## Features

- Visual editing of SVG paths
- Supports move, line, and cubic bezier curve commands
- Interactive control points for cubic bezier curves
- Customizable appearance

## Example Usage


```dart
Stack(
  children: [
    // Background content
    Positioned.fill(
      child: FilledPath(
        controller: controller,
        color: Colors.blue.withAlpha(127),
        blendMode: BlendMode.srcOver,
      ),
    ),
    // Path editor on top
    Positioned.fill(
      child: PathEditor(
        controller: controller,
      ),
    ),
  ],
)
```

## Additional information

Paths are transformed into absolute mode and all operations are remapped to MoveTo, LineTo and CubicTo. This ensures the paths are compatible with all outputs such as SVG and PDF.

For more information, visit the [GitHub repository](https://github.com/NicolaVerbeeck/flutter_path_editor).

If you encounter any issues or have feature requests, please file them on the [issue tracker](https://github.com/NicolaVerbeeck/flutter_path_editor/issues).
