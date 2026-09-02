import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A modifier key combination the editor can test for.
///
/// Instances are compared by identity of their predicate, so use the provided
/// constants (or hold on to your own [KeyModifier.custom] instance) rather
/// than constructing equivalent ones repeatedly.
@immutable
class KeyModifier {
  /// A human readable name, used by [toString] and for debugging.
  final String debugName;

  final bool Function(HardwareKeyboard keyboard) _predicate;

  const KeyModifier._(this.debugName, this._predicate);

  /// Never active.
  static const KeyModifier none = KeyModifier._('none', _never);

  /// Active while any shift key is held.
  static const KeyModifier shift = KeyModifier._('shift', _shift);

  /// Active while any alt/option key is held.
  static const KeyModifier alt = KeyModifier._('alt', _alt);

  /// Active while any control key is held.
  static const KeyModifier control = KeyModifier._('control', _control);

  /// Active while any meta (command/windows) key is held.
  static const KeyModifier meta = KeyModifier._('meta', _meta);

  /// Active while the platform's primary shortcut modifier is held: meta on
  /// macOS and iOS, control everywhere else.
  static const KeyModifier controlOrMeta =
      KeyModifier._('controlOrMeta', _controlOrMeta);

  /// Creates a modifier from an arbitrary predicate.
  ///
  /// ```dart
  /// KeyModifier.custom(
  ///   'shiftAndAlt',
  ///   (keyboard) =>
  ///       keyboard.isShiftPressed && keyboard.isAltPressed,
  /// )
  /// ```
  const KeyModifier.custom(
    this.debugName,
    bool Function(HardwareKeyboard keyboard) predicate,
  ) : _predicate = predicate;

  /// Whether this modifier is currently held down.
  bool isActive([HardwareKeyboard? keyboard]) =>
      _predicate(keyboard ?? HardwareKeyboard.instance);

  static bool _never(HardwareKeyboard keyboard) => false;

  static bool _shift(HardwareKeyboard keyboard) => keyboard.isShiftPressed;

  static bool _alt(HardwareKeyboard keyboard) => keyboard.isAltPressed;

  static bool _control(HardwareKeyboard keyboard) => keyboard.isControlPressed;

  static bool _meta(HardwareKeyboard keyboard) => keyboard.isMetaPressed;

  static bool _controlOrMeta(HardwareKeyboard keyboard) {
    final isApple = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isApple ? keyboard.isMetaPressed : keyboard.isControlPressed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyModifier &&
          debugName == other.debugName &&
          _predicate == other._predicate);

  @override
  int get hashCode => Object.hash(debugName, _predicate);

  @override
  String toString() => 'KeyModifier.$debugName';
}

/// Which modifier key triggers which editing behaviour.
///
/// Every entry can be remapped, including to [KeyModifier.none] to disable the
/// behaviour entirely.
@immutable
class PathEditorModifiers {
  /// Adds the clicked node to the selection instead of replacing it.
  final KeyModifier multiSelect;

  /// Breaks the link between the two handles of a node while dragging one, so
  /// the opposite handle keeps its direction and length.
  final KeyModifier breakHandle;

  /// Turns a drag on an existing point into a curvature drag: the point stays
  /// put while its handles are pulled out, converting a corner point into a
  /// smooth one.
  ///
  /// This mirrors the bend tool of design tools like Figma, which is reached
  /// by holding the same key. Note that it shares its default with
  /// [disableSnapping]; when a drag starts on a point the bend wins, and the
  /// bend itself is unsnapped, which is usually what you want. Remap either
  /// one if you need them separated.
  final KeyModifier bendPoint;

  /// Temporarily turns snapping off.
  final KeyModifier disableSnapping;

  /// Constrains handle and node movement to fixed angle increments.
  final KeyModifier constrainAngle;

  /// Turns a click on a node into a "remove this node" action while the pen
  /// tool is active.
  final KeyModifier removeNode;

  /// Makes a delete action cut the path instead of preserving its shape.
  final KeyModifier cutPath;

  /// Creates a modifier mapping.
  const PathEditorModifiers({
    this.multiSelect = KeyModifier.shift,
    this.breakHandle = KeyModifier.alt,
    this.bendPoint = KeyModifier.controlOrMeta,
    this.disableSnapping = KeyModifier.controlOrMeta,
    this.constrainAngle = KeyModifier.shift,
    this.removeNode = KeyModifier.alt,
    this.cutPath = KeyModifier.alt,
  });

  /// The default mapping.
  static const PathEditorModifiers defaults = PathEditorModifiers();

  /// Returns a copy of this mapping with the given modifiers replaced.
  PathEditorModifiers copyWith({
    KeyModifier? multiSelect,
    KeyModifier? breakHandle,
    KeyModifier? bendPoint,
    KeyModifier? disableSnapping,
    KeyModifier? constrainAngle,
    KeyModifier? removeNode,
    KeyModifier? cutPath,
  }) =>
      PathEditorModifiers(
        multiSelect: multiSelect ?? this.multiSelect,
        breakHandle: breakHandle ?? this.breakHandle,
        bendPoint: bendPoint ?? this.bendPoint,
        disableSnapping: disableSnapping ?? this.disableSnapping,
        constrainAngle: constrainAngle ?? this.constrainAngle,
        removeNode: removeNode ?? this.removeNode,
        cutPath: cutPath ?? this.cutPath,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PathEditorModifiers &&
          multiSelect == other.multiSelect &&
          breakHandle == other.breakHandle &&
          bendPoint == other.bendPoint &&
          disableSnapping == other.disableSnapping &&
          constrainAngle == other.constrainAngle &&
          removeNode == other.removeNode &&
          cutPath == other.cutPath);

  @override
  int get hashCode => Object.hash(
        multiSelect,
        breakHandle,
        bendPoint,
        disableSnapping,
        constrainAngle,
        removeNode,
        cutPath,
      );
}
