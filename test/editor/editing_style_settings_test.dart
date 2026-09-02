import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/application/editor_state.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorEditingStyle Domain Tests', () {
    test('default editing style is wysiwyg', () {
      expect(EditorEditingStyle.fromString(null), equals(EditorEditingStyle.wysiwyg));
      expect(EditorEditingStyle.fromString(''), equals(EditorEditingStyle.wysiwyg));
      expect(EditorEditingStyle.fromString('invalid'), equals(EditorEditingStyle.wysiwyg));
    });

    test('parses markdown style correctly', () {
      expect(EditorEditingStyle.fromString('markdown'), equals(EditorEditingStyle.markdown));
    });

    test('storageKey and labels are consistent', () {
      expect(EditorEditingStyle.wysiwyg.storageKey, equals('wysiwyg'));
      expect(EditorEditingStyle.markdown.storageKey, equals('markdown'));
      expect(EditorEditingStyle.wysiwyg.label, equals('WYSIWYG'));
      expect(EditorEditingStyle.markdown.label, equals('Markdown'));
      expect(EditorEditingStyle.wysiwyg.description, contains('Hide Markdown syntax'));
      expect(EditorEditingStyle.markdown.description, contains('Show Markdown syntax'));
    });
  });

  group('EditingStyleNotifier Persistence Tests', () {
    test('initializes with default wysiwyg when SharedPreferences is empty', () {
      SharedPreferences.setMockInitialValues({});
      final prefs = SharedPreferences.getInstance();
      return prefs.then((p) {
        final notifier = EditingStyleNotifier(p);
        expect(notifier.state, equals(EditorEditingStyle.wysiwyg));
      });
    });

    test('initializes with stored preference if available', () {
      SharedPreferences.setMockInitialValues({'app_editor_editing_style': 'markdown'});
      final prefs = SharedPreferences.getInstance();
      return prefs.then((p) {
        final notifier = EditingStyleNotifier(p);
        expect(notifier.state, equals(EditorEditingStyle.markdown));
      });
    });

    test('setEditingStyle updates state and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = EditingStyleNotifier(prefs);

      expect(notifier.state, equals(EditorEditingStyle.wysiwyg));

      await notifier.setEditingStyle(EditorEditingStyle.markdown);
      expect(notifier.state, equals(EditorEditingStyle.markdown));
      expect(prefs.getString('app_editor_editing_style'), equals('markdown'));

      await notifier.setEditingStyle(EditorEditingStyle.wysiwyg);
      expect(notifier.state, equals(EditorEditingStyle.wysiwyg));
      expect(prefs.getString('app_editor_editing_style'), equals('wysiwyg'));
    });
  });

  group('EditorState Per-Note Override Tests', () {
    final now = DateTime.now();
    test('effectiveEditingStyle returns global style when no per-note override is set', () {
      final note = Note(id: '1', title: 'Test', content: 'Content', createdAt: now, updatedAt: now);
      final state = EditorState(note: note);

      expect(state.effectiveEditingStyle(EditorEditingStyle.wysiwyg), equals(EditorEditingStyle.wysiwyg));
      expect(state.effectiveEditingStyle(EditorEditingStyle.markdown), equals(EditorEditingStyle.markdown));
    });

    test('effectiveEditingStyle respects per-note override over global style', () {
      final note = Note(id: '1', title: 'Test', content: 'Content', createdAt: now, updatedAt: now);
      final state = EditorState(
        note: note,
        perNoteEditingStyleOverride: EditorEditingStyle.markdown,
      );

      expect(state.effectiveEditingStyle(EditorEditingStyle.wysiwyg), equals(EditorEditingStyle.markdown));
      expect(state.effectiveEditingStyle(EditorEditingStyle.markdown), equals(EditorEditingStyle.markdown));

      final wysiwygOverride = state.copyWith(perNoteEditingStyleOverride: EditorEditingStyle.wysiwyg);
      expect(wysiwygOverride.effectiveEditingStyle(EditorEditingStyle.markdown), equals(EditorEditingStyle.wysiwyg));
    });

    test('copyWith clears per-note override when requested', () {
      final note = Note(id: '1', title: 'Test', content: 'Content', createdAt: now, updatedAt: now);
      final state = EditorState(
        note: note,
        perNoteEditingStyleOverride: EditorEditingStyle.markdown,
      );

      final cleared = state.copyWith(clearPerNoteEditingStyleOverride: true);
      expect(cleared.perNoteEditingStyleOverride, isNull);
      expect(cleared.effectiveEditingStyle(EditorEditingStyle.wysiwyg), equals(EditorEditingStyle.wysiwyg));
    });
  });
}
