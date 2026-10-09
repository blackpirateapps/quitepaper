import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_timeline_tile.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  final testNow = DateTime(2026, 10, 9, 9, 0, 0);

  setUp(NoteMetadataExtractor.clearCache);

  Note journalNote(String id, String content) => Note(
        id: id,
        title: 'A Day Out',
        content: content,
        createdAt: testNow,
        updatedAt: testNow,
        journalDate: '2026-10-09',
      );

  Future<void> pumpTile(
    WidgetTester tester,
    Note note, {
    bool showPlaceWeather = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'setting_show_place_and_weather_on_entries': showPlaceWeather,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(family: ThemeFamily.classicPaper),
          home: Scaffold(
            body: JournalTimelineTile(note: note, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const withPlaceAndWeather = '''---
journal: true
date: 2026-10-09
location:
  address: "Kolkata, West Bengal, India"
  latitude: 22.5726
  longitude: 88.3639
weather:
  temperature: 24.0
  condition: "Cloudy"
  code: 3
---

Wandered the city all afternoon.''';

  const noMetadata = '''---
journal: true
date: 2026-10-09
---

A quiet day at home with nothing noted.''';

  testWidgets('composes place and weather when both present', (tester) async {
    await pumpTile(tester, journalNote('j1', withPlaceAndWeather));
    expect(find.textContaining('Kolkata'), findsOneWidget);
    expect(find.textContaining('24°'), findsOneWidget);
  });

  testWidgets('renders only the parts that exist (place only, no weather)',
      (tester) async {
    const placeOnly = '''---
journal: true
date: 2026-10-09
location:
  address: "Mumbai, Maharashtra, India"
  latitude: 19.076
  longitude: 72.8777
---

Visiting family.''';
    await pumpTile(tester, journalNote('j2', placeOnly));
    expect(find.textContaining('Mumbai'), findsOneWidget);
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('renders no dateline when neither place nor weather exists',
      (tester) async {
    await pumpTile(tester, journalNote('j3', noMetadata));
    expect(find.textContaining('°'), findsNothing);
    expect(find.textContaining('Kolkata'), findsNothing);
    // The title still renders.
    expect(find.text('A Day Out'), findsOneWidget);
  });

  testWidgets('toggle OFF hides the dateline even when metadata is present',
      (tester) async {
    await pumpTile(
      tester,
      journalNote('j4', withPlaceAndWeather),
      showPlaceWeather: false,
    );
    expect(find.textContaining('Kolkata'), findsNothing);
    expect(find.textContaining('24°'), findsNothing);
  });

  testWidgets('locked journal note shows no dateline', (tester) async {
    final locked = Note(
      id: 'locked',
      title: 'A Day Out',
      content:
          '<!-- quiet-paper-encrypted-note-v1:deadbeef -->\n$withPlaceAndWeather',
      createdAt: testNow,
      updatedAt: testNow,
      journalDate: '2026-10-09',
    );
    await pumpTile(tester, locked);
    expect(find.textContaining('Kolkata'), findsNothing);
    expect(find.textContaining('24°'), findsNothing);
  });
}
