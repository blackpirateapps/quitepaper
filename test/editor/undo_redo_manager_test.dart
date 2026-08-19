import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/undo_redo_manager.dart';

void main() {
  group('UndoRedoManager', () {
    late UndoRedoManager manager;

    setUp(() {
      manager = UndoRedoManager(
        typingDebounceDuration: const Duration(milliseconds: 100),
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('initial state has empty undo and redo stacks', () {
      manager.initialize(const TextEditingValue(text: 'Hello'));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
    });

    test('registering atomic edit enables undo and clears redo', () {
      manager.initialize(const TextEditingValue(text: 'Initial'));
      manager.pushAtomicEdit(const TextEditingValue(text: 'Formatted text'));

      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);

      final undone = manager.undo(const TextEditingValue(text: 'Formatted text'));
      expect(undone, isNotNull);
      expect(undone!.text, equals('Initial'));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isTrue);

      final redone = manager.redo(undone);
      expect(redone, isNotNull);
      expect(redone!.text, equals('Formatted text'));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
    });

    test('typing debounce flushes snapshot after delay', () async {
      manager.initialize(const TextEditingValue(text: ''));

      manager.registerEdit(const TextEditingValue(text: 'H'));
      manager.registerEdit(const TextEditingValue(text: 'He'));
      manager.registerEdit(const TextEditingValue(text: 'Hell'));
      manager.registerEdit(const TextEditingValue(text: 'Hello'));

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(manager.canUndo, isTrue);
      final undone = manager.undo(const TextEditingValue(text: 'Hello'));
      expect(undone, isNotNull);
      expect(undone!.text, equals(''));
    });

    test('newline immediately flushes snapshot boundary', () {
      manager.initialize(const TextEditingValue(text: 'Line 1'));
      manager.registerEdit(const TextEditingValue(text: 'Line 1\nLine 2'));

      expect(manager.canUndo, isTrue);
      final undone = manager.undo(const TextEditingValue(text: 'Line 1\nLine 2'));
      expect(undone, isNotNull);
      expect(undone!.text, equals('Line 1'));
    });

    test('max history limit is respected', () {
      final limitedManager = UndoRedoManager(
        maxHistory: 5,
        typingDebounceDuration: Duration.zero,
      );
      limitedManager.initialize(const TextEditingValue(text: '0'));

      for (int i = 1; i <= 10; i++) {
        limitedManager.pushAtomicEdit(TextEditingValue(text: '$i'));
      }

      int undoCount = 0;
      var current = const TextEditingValue(text: '10');
      while (limitedManager.canUndo) {
        current = limitedManager.undo(current)!;
        undoCount++;
      }

      expect(undoCount, equals(5));
      expect(current.text, equals('5'));
      limitedManager.dispose();
    });
  });
}
