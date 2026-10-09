import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/journal_places_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/place_card.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

/// Builds a located journal note.
Note _note(String id, String date, String address) {
  final dt = DateTime.parse(date);
  final content = '''---
journal: true
date: $date
location:
  address: "$address"
  latitude: 1.0
  longitude: 2.0
---

Entry $id for $date.''';
  return Note(
    id: id,
    title: 'Entry $id',
    content: content,
    createdAt: dt,
    updatedAt: dt,
    journalDate: date,
  );
}

Future<Widget> _harness(List<Note> notes) async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allJournalEntriesStreamProvider.overrideWith((ref) => Stream.value(notes)),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: const Scaffold(body: JournalPlacesView()),
    ),
  );
}

/// Two located entries → two place cards (Kolkata, Mumbai).
List<Note> _twoCities() => [
      _note('k1', '2026-09-10', 'Kolkata, West Bengal, India'),
      _note('m1', '2026-09-20', 'Mumbai, Maharashtra, India'),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NoteMetadataExtractor.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  Finder dialogText(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

  testWidgets(
      'selection mode: select two cards and merge into one chosen canonical',
      (tester) async {
    await tester.pumpWidget(await _harness(_twoCities()));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));

    // Enter selection mode via the quiet "Select" header action.
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Tap places to merge'), findsOneWidget);

    // Tap both cards; the Merge action appears once ≥2 are selected.
    await tester.tap(find.text('Kolkata'));
    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    // Choose "Mumbai" as the canonical name inside the dialog, then confirm.
    await tester.tap(dialogText('Mumbai'));
    await tester.pumpAndSettle();
    await tester.tap(dialogText('Merge'));
    await tester.pumpAndSettle();

    // Collapsed to a single card with the chosen name; selection mode exited.
    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    expect(find.text('Kolkata'), findsNothing);
    expect(find.text('Select'), findsNothing); // only one place now
  });

  testWidgets('merge with a custom canonical name', (tester) async {
    await tester.pumpWidget(await _harness(_twoCities()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kolkata'));
    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Field Trip',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(QuietButton, 'Merge'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('Field Trip'), findsOneWidget);
  });

  testWidgets('rename updates the displayed place name', (tester) async {
    await tester.pumpWidget(await _harness(_twoCities()));
    await tester.pumpAndSettle();

    // Long-press opens the per-place actions sheet.
    await tester.longPress(find.text('Kolkata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Calcutta',
    );
    await tester.tap(find.widgetWithText(QuietButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Calcutta'), findsOneWidget);
    expect(find.text('Kolkata'), findsNothing);
    expect(find.text('Mumbai'), findsOneWidget); // the other card is untouched
  });

  testWidgets('unmerge restores the separate cards', (tester) async {
    await tester.pumpWidget(await _harness(_twoCities()));
    await tester.pumpAndSettle();

    // Merge the two into one (default canonical name).
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kolkata'));
    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(QuietButton, 'Merge'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsOneWidget);

    // Long-press the merged card → Unmerge is offered → restores both cards.
    await tester.longPress(find.byType(PlaceCard));
    await tester.pumpAndSettle();
    expect(find.text('Unmerge'), findsOneWidget);
    await tester.tap(find.text('Unmerge'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('Kolkata'), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
  });

  testWidgets('unmerge is NOT offered for an unmerged place', (tester) async {
    await tester.pumpWidget(await _harness(_twoCities()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Kolkata'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Unmerge'), findsNothing);
  });

  testWidgets('merged state persists across a fresh view (device-local)',
      (tester) async {
    final notes = _twoCities();
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kolkata'));
    await tester.tap(find.text('Mumbai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(QuietButton, 'Merge'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsOneWidget);

    // Let the fire-and-forget SharedPreferences write settle, then rebuild a
    // brand-new view over the same prefs: the merge should rehydrate.
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('Kolkata'), findsOneWidget); // default canonical survived
  });
}
