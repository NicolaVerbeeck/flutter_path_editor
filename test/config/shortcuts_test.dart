// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:path_editor/path_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds actions for every editor intent', () {
    final controller = PathEditorController.empty();
    final handler = PathEditorToolHandler(controller: controller);
    final actions = buildPathEditorActions(
      controller: controller,
      handler: handler,
    );

    expect(
      actions.keys,
      containsAll([
        DeleteNodesIntent,
        ClosePathIntent,
        FinishPathIntent,
        ConvertNodesIntent,
        SelectAllNodesIntent,
        NudgeNodesIntent,
        PathUndoIntent,
        PathRedoIntent,
        SelectToolIntent,
      ]),
    );

    expect(
      actions[DeleteNodesIntent]!.invoke(const DeleteNodesIntent()),
      isFalse,
    );
    expect(
      actions[ClosePathIntent]!.invoke(const ClosePathIntent()),
      isFalse,
    );
    expect(
      actions[FinishPathIntent]!.invoke(const FinishPathIntent()),
      isNull,
    );
    expect(
      actions[ConvertNodesIntent]!
          .invoke(const ConvertNodesIntent(PathNodeType.mirrored)),
      isNull,
    );
    expect(
      actions[SelectAllNodesIntent]!.invoke(const SelectAllNodesIntent()),
      isNull,
    );
    expect(
      actions[NudgeNodesIntent]!.invoke(
        const NudgeNodesIntent(Offset(1, 0)),
      ),
      isNull,
    );
    expect(
      actions[NudgeNodesIntent]!.invoke(
        const NudgeNodesIntent(Offset(0, 1), large: true),
      ),
      isNull,
    );
    expect(
      actions[PathUndoIntent]!.invoke(const PathUndoIntent()),
      isFalse,
    );
    expect(
      actions[PathRedoIntent]!.invoke(const PathRedoIntent()),
      isFalse,
    );

    expect(controller.tool, PathTool.pen);
    expect(
      actions[SelectToolIntent]!.invoke(
        const SelectToolIntent(PathTool.select),
      ),
      isNull,
    );
    expect(controller.tool, PathTool.select);

    handler.dispose();
    controller.dispose();
  });

  test('fallback activators respect NumLock requirements', () {
    final keyboard = HardwareKeyboard();
    ShortcutActivator fallbackFor(LockState numLock) {
      final shortcuts = PathEditorShortcuts.withFallbacks({
        SingleActivator(
          LogicalKeyboardKey.enter,
          numLock: numLock,
        ): const ClosePathIntent(),
      });
      return shortcuts.keys.singleWhere(
        (activator) => activator is! SingleActivator,
      );
    }

    final requiresNumLock = fallbackFor(LockState.locked);
    final requiresNoNumLock = fallbackFor(LockState.unlocked);
    const enter = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: LogicalKeyboardKey.enter,
      timeStamp: Duration.zero,
    );

    expect(requiresNumLock.accepts(enter, keyboard), isFalse);
    expect(requiresNoNumLock.accepts(enter, keyboard), isTrue);

    keyboard.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.numLock,
        logicalKey: LogicalKeyboardKey.numLock,
        timeStamp: Duration.zero,
      ),
    );
    expect(requiresNumLock.accepts(enter, keyboard), isTrue);
    expect(requiresNoNumLock.accepts(enter, keyboard), isFalse);

    keyboard.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.numLock,
        logicalKey: LogicalKeyboardKey.numLock,
        timeStamp: Duration.zero,
      ),
    );
  });

  test('fallback activators describe their shortcut', () {
    final shortcuts = PathEditorShortcuts.withFallbacks({
      const SingleActivator(
        LogicalKeyboardKey.enter,
        shift: true,
      ): const ClosePathIntent(),
    });
    final fallback = shortcuts.keys.singleWhere(
      (activator) => activator is! SingleActivator,
    );

    expect(fallback.debugDescribeKeys(), startsWith('at least '));
  });
}
