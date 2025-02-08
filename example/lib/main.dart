import 'package:flutter/material.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  const path =
      'M 4 8 L 10 1 L 13 0 L 12 3 L 5 9 C 6 10 6 11 7 10 C 7 11 8 12 7 12 a 1.42 1.42 0 0 1 -1 1 A 5 5 0 0 0 4 10 Q 3.5 9.9 3.5 10.5 T 2 11.8 T 1.2 11 T 2.5 9.5 T 3 9 A 5 5 90 0 0 0 7 A 1.42 1.42 0 0 1 1 6 C 1 5 1.894 5.878 3 6 C 2 7 3 7 4 8 M 10 1 L 10 3 L 12 3 L 10.2 2.8 L 10 1 Z';
  var operators = PathOperator.parse(path);
  operators = operators.scale(30, 30);
  final scaledPath = operators.toSvg();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: PathEditor(path: scaledPath),
          ),
        ),
      ),
    ),
  );
}
