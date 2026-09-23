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

  static const KeyModifier _unset = KeyModifier._('unset', _never);

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
/// Every entry can be remapped. Set an entry to `null` to disable that
/// behaviour entirely, or use [KeyModifier.none] for an always-inactive
/// modifier.
@immutable
class PathEditorModifiers {
  /// Adds the clicked node to the selection instead of replacing it.
  final KeyModifier? multiSelect;

  /// Breaks the link between the two handles of a node while dragging one, so
  /// the opposite handle keeps its direction and length.
  final KeyModifier? breakHandle;

  /// Turns a drag on an existing point into a curvature drag: the point stays
  /// put while its handles are pulled out, converting a corner point into a
  /// smooth one. Clicking a corner with this modifier also makes it smooth,
  /// with handles inferred from the directions of its neighbouring segments.
  ///
  /// This mirrors the bend tool of design tools like Figma, which is reached
  /// by holding the same key. Note that it shares its default with
  /// [disableSnapping]; when a drag starts on a point the bend wins, and the
  /// bend itself is unsnapped, which is usually what you want. Remap either
  /// one if you need them separated.
  final KeyModifier? bendPoint;

  /// Temporarily turns snapping off.
  final KeyModifier? disableSnapping;

  /// Constrains handle and node movement to fixed angle increments.
  final KeyModifier? constrainAngle;

  /// Turns a click on a node into a "remove this node" action while the pen
  /// tool is active.
  final KeyModifier? removeNode;

  /// Makes a [removeNode] click cut the path instead of removing the point
  /// according to the configured node removal mode.
  ///
  /// This only affects clicks. Keyboard deletion does not look at held
  /// modifiers; cutting from the keyboard has its own shortcut (`Shift` +
  /// `Delete` / `Backspace` by default, see `PathEditorShortcuts`).
  final KeyModifier? cutPath;

  /// Creates a modifier mapping.
  const PathEditorModifiers({
    this.multiSelect = KeyModifier.shift,
    this.breakHandle = KeyModifier.alt,
    this.bendPoint = KeyModifier.controlOrMeta,
    this.disableSnapping = KeyModifier.controlOrMeta,
    this.constrainAngle = KeyModifier.shift,
    this.removeNode = KeyModifier.alt,
    this.cutPath = KeyModifier.shift,
  });

  /// The default mapping.
  static const PathEditorModifiers defaults = PathEditorModifiers();

  /// Returns a copy of this mapping with the given modifiers replaced.
  ///
  /// Passing `null` disables the corresponding behaviour. Omitting an
  /// argument keeps the existing mapping.
  PathEditorModifiers copyWith({
    KeyModifier? multiSelect = KeyModifier._unset,
    KeyModifier? breakHandle = KeyModifier._unset,
    KeyModifier? bendPoint = KeyModifier._unset,
    KeyModifier? disableSnapping = KeyModifier._unset,
    KeyModifier? constrainAngle = KeyModifier._unset,
    KeyModifier? removeNode = KeyModifier._unset,
    KeyModifier? cutPath = KeyModifier._unset,
  }) =>
      PathEditorModifiers(
        multiSelect: _copyModifier(multiSelect, this.multiSelect),
        breakHandle: _copyModifier(breakHandle, this.breakHandle),
        bendPoint: _copyModifier(bendPoint, this.bendPoint),
        disableSnapping: _copyModifier(disableSnapping, this.disableSnapping),
        constrainAngle: _copyModifier(constrainAngle, this.constrainAngle),
        removeNode: _copyModifier(removeNode, this.removeNode),
        cutPath: _copyModifier(cutPath, this.cutPath),
      );

  static KeyModifier? _copyModifier(
    KeyModifier? value,
    KeyModifier? current,
  ) =>
      identical(value, KeyModifier._unset) ? current : value;

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
