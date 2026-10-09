import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/journal_places_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_timeline_tile.dart';
import 'package:quitepaper/features/journal/presentation/widgets/place_card.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

/// Builds a journal note with (optionally) a located frontmatter block.
Note _note(String id, String date, {String? address}) {
  final dt = DateTime.parse(date);
  final content = address != null
      ? '''---
journal: true
date: $date
location:
  address: "$address"
  latitude: 1.0
  longitude: 2.0
---

Entry $id for $date.'''
      : '''---
journal: true
date: $date
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NoteMetadataExtractor.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders a place card per located place', (tester) async {
    final notes = [
      _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
      _note('m1', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
      _note('n1', '2026-09-25'), // unlocated → excluded
    ];
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('Kolkata'), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    // Silent exclusion: no "Unknown"/"Without location" bucket (§6.4).
    expect(find.textContaining('Unknown'), findsNothing);
    expect(find.textContaining('Without location'), findsNothing);
  });

  testWidgets('shows the calm learning/empty state when no located entries',
      (tester) async {
    await tester.pumpWidget(await _harness([_note('n1', '2026-09-25')]));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsNothing);
    expect(find.text('Places you write from will gather here.'),
        findsOneWidget);
  });

  testWidgets('granularity toggle collapses cities into one country',
      (tester) async {
    final notes = [
      _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
      _note('m1', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
    ];
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsNWidgets(2));

    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
  });

  testWidgets('sort toggle reorders the list (recency vs A–Z)',
      (tester) async {
    final notes = [
      _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
      _note('m1', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
    ];
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    // Default recency → Mumbai (latest entry) is above Kolkata.
    expect(tester.getTopLeft(find.text('Mumbai')).dy,
        lessThan(tester.getTopLeft(find.text('Kolkata')).dy));

    await tester.tap(find.text('A–Z'));
    await tester.pumpAndSettle();

    // Alphabetical → Kolkata is now above Mumbai.
    expect(tester.getTopLeft(find.text('Kolkata')).dy,
        lessThan(tester.getTopLeft(find.text('Mumbai')).dy));
  });

  testWidgets('drill-in shows visit sub-headers and entry tiles',
      (tester) async {
    final notes = [
      _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
      _note('k2', '2026-09-12', address: 'Kolkata, West Bengal, India'),
      _note('m1', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
    ];
    await tester.pumpWidget(await _harness(notes));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kolkata'));
    await tester.pumpAndSettle();

    // Visit sub-header for the clustered September 2026 visit (§6.3).
    expect(find.text('September 2026 · 2 entries'), findsOneWidget);
    // Both Kolkata entries render as timeline tiles; the Mumbai one does not.
    expect(find.byType(JournalTimelineTile), findsNWidgets(2));

    // Back returns to the list.
    await tester.tap(find.byTooltip('Back to places'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
  });
}
