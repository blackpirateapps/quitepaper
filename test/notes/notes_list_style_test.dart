import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/notes/domain/notes_list_style.dart';
import 'package:quitepaper/features/notes/application/notes_list_style_provider.dart';

void main() {
  group('NotesListStyle Enum Tests', () {
    test('default values and properties', () {
      expect(NotesListStyle.quietPaper.title, 'Quiet Paper');
      expect(NotesListStyle.quietPaper.storageKey, 'quietPaper');
      expect(
        NotesListStyle.quietPaper.description,
        'Your current card-based notes list.',
      );

      expect(NotesListStyle.editorial.title, 'Editorial');
      expect(NotesListStyle.editorial.storageKey, 'editorial');
      expect(
        NotesListStyle.editorial.description,
        'A content-focused list with inline previews and attachments.',
      );
    });

    test('fromString parses correctly with safe fallback', () {
      expect(NotesListStyle.fromString('editorial'), NotesListStyle.editorial);
      expect(NotesListStyle.fromString('quietPaper'), NotesListStyle.quietPaper);
      expect(NotesListStyle.fromString(null), NotesListStyle.quietPaper);
      expect(NotesListStyle.fromString('unknown'), NotesListStyle.quietPaper);
    });
  });

  group('NotesListStyleNotifier Tests', () {
    test('loads default quietPaper when SharedPreferences is empty', () {
      SharedPreferences.setMockInitialValues({});
      final prefs = SharedPreferences.getInstance();

      prefs.then((p) {
        final notifier = NotesListStyleNotifier(p);
        expect(notifier.state, NotesListStyle.quietPaper);
      });
    });

    test('loads persisted editorial value from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_notes_list_style': 'editorial'});
      final prefs = await SharedPreferences.getInstance();

      final notifier = NotesListStyleNotifier(prefs);
      expect(notifier.state, NotesListStyle.editorial);
    });

    test('setStyle updates state and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = NotesListStyleNotifier(prefs);
      expect(notifier.state, NotesListStyle.quietPaper);

      await notifier.setStyle(NotesListStyle.editorial);
      expect(notifier.state, NotesListStyle.editorial);
      expect(prefs.getString('app_notes_list_style'), 'editorial');

      await notifier.setStyle(NotesListStyle.quietPaper);
      expect(notifier.state, NotesListStyle.quietPaper);
      expect(prefs.getString('app_notes_list_style'), 'quietPaper');
    });
  });
}
