import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/journal/application/backfill_suppression_store.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/widgets/backfill_place_nudge.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/default_settings_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

/// Builds a note. [address] null → no location frontmatter; [journal] false →
/// a plain note (no journalDate); [locked] → encrypted body.
Note _note(
  String id,
  String date, {
  String? address,
  bool journal = true,
  bool locked = false,
}) {
  final dt = DateTime.parse(date);
  final String content;
  if (locked) {
    content = '<!-- quiet-paper-encrypted-note-v1: $id -->\ncipher';
  } else if (address != null) {
    content = '''---
journal: true
date: $date
location:
  address: "$address"
  latitude: 1.0
  longitude: 2.0
---

Entry for $date.''';
  } else if (journal) {
    content = '''---
journal: true
date: $date
---

Entry for $date.''';
  } else {
    content = 'Just a plain note.';
  }
  return Note(
    id: id,
    title: 'Entry',
    content: content,
    createdAt: dt,
    updatedAt: dt,
    journalDate: journal ? date : null,
  );
}

const _nudgePrompt = 'Add a place to this entry?';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NoteMetadataExtractor.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(NoteMetadataExtractor.clearCache);

  /// Pumps a [BackfillPlaceNudge] inside an uncontrolled scope so the test can
  /// read providers directly from [container]. [onChanged] captures writes.
  Future<void> pumpNudge(
    WidgetTester tester, {
    required ProviderContainer container,
    required Note note,
    bool? isJournal,
    void Function(String updated)? onChanged,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BackfillPlaceNudge(
                note: note,
                rawDocument: note.content,
                isJournal: isJournal ?? note.isJournal,
                onDocumentChanged: (u) => onChanged?.call(u),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<ProviderContainer> makeContainer({
    Map<String, Object> prefsSeed = const {},
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues(prefsSeed);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('BackfillPlaceNudge visibility', () {
    testWidgets('shows for an unlocated, unlocked journal entry (toggle on, '
        'day not suppressed)', (tester) async {
      final c = await makeContainer();
      await pumpNudge(tester, container: c, note: _note('n1', '2026-09-15'));

      expect(find.text(_nudgePrompt), findsOneWidget);
      expect(find.text('Add place'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text("Don't ask again for this day"), findsOneWidget);
      expect(find.text("Don't ask again"), findsOneWidget);
    });

    testWidgets('hidden when the entry already has a location', (tester) async {
      final c = await makeContainer();
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15', address: 'Kolkata, West Bengal, India'),
      );
      expect(find.text(_nudgePrompt), findsNothing);
    });

    testWidgets('hidden on a locked (password-protected) note', (tester) async {
      final c = await makeContainer();
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15', locked: true),
        isJournal: true,
      );
      expect(find.text(_nudgePrompt), findsNothing);
    });

    testWidgets('hidden on a non-journal note', (tester) async {
      final c = await makeContainer();
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15', journal: false),
      );
      expect(find.text(_nudgePrompt), findsNothing);
    });

    testWidgets('hidden when the master toggle is off', (tester) async {
      final c = await makeContainer(prefsSeed: {
        DefaultSettingsNotifier.suggestPlaceForPastEntriesKey: false,
      });
      await pumpNudge(tester, container: c, note: _note('n1', '2026-09-15'));
      expect(find.text(_nudgePrompt), findsNothing);
    });

    testWidgets('hidden when this day is suppressed', (tester) async {
      final c = await makeContainer(prefsSeed: {
        BackfillSuppressionStore.storageKey: '["2026-09-15"]',
      });
      await pumpNudge(tester, container: c, note: _note('n1', '2026-09-15'));
      expect(find.text(_nudgePrompt), findsNothing);
    });
  });

  group('BackfillPlaceNudge actions', () {
    testWidgets('Add place → custom text writes a location: block + fires '
        'onDocumentChanged', (tester) async {
      final c = await makeContainer(overrides: [
        allJournalEntriesStreamProvider
            .overrideWith((ref) => Stream.value(const <Note>[])),
      ]);
      String? captured;
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15'),
        onChanged: (u) => captured = u,
      );

      await tester.tap(find.text('Add place'));
      await tester.pumpAndSettle();

      // Picker open: type a custom place and save.
      await tester.enterText(find.byType(TextField), 'Pondicherry');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, contains('location:'));
      expect(captured, contains('Pondicherry'));
    });

    testWidgets('Add place → known place writes its member location',
        (tester) async {
      final existing = [
        _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
      ];
      final c = await makeContainer(overrides: [
        allJournalEntriesStreamProvider
            .overrideWith((ref) => Stream.value(existing)),
      ]);
      // Warm the entries stream so placeListProvider is populated.
      await c.read(allJournalEntriesStreamProvider.future);

      String? captured;
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15'),
        onChanged: (u) => captured = u,
      );

      await tester.tap(find.text('Add place'));
      await tester.pumpAndSettle();

      // Known place row (city-level display name).
      expect(find.text('Kolkata'), findsOneWidget);
      await tester.tap(find.text('Kolkata'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, contains('location:'));
      expect(captured, contains('Kolkata, West Bengal, India'));
      expect(captured, contains('latitude: 1.0'));
      expect(captured, contains('longitude: 2.0'));
    });

    testWidgets('Not now dismisses without persisting anything', (tester) async {
      final c = await makeContainer();
      String? captured;
      await pumpNudge(
        tester,
        container: c,
        note: _note('n1', '2026-09-15'),
        onChanged: (u) => captured = u,
      );

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(find.text(_nudgePrompt), findsNothing);
      // Nothing persisted: no write, setting unchanged, no day suppressed.
      expect(captured, isNull);
      expect(c.read(defaultSettingsProvider).suggestPlaceForPastEntries, isTrue);
      expect(c.read(backfillSuppressionProvider), isEmpty);
    });

    testWidgets('Don\'t ask again for this day suppresses only that date',
        (tester) async {
      final c = await makeContainer();
      await pumpNudge(tester, container: c, note: _note('n1', '2026-09-15'));

      await tester.tap(find.text("Don't ask again for this day"));
      await tester.pump();

      expect(find.text(_nudgePrompt), findsNothing);
      expect(c.read(backfillSuppressionProvider), {'2026-09-15'});
      // The global master toggle is untouched.
      expect(c.read(defaultSettingsProvider).suggestPlaceForPastEntries, isTrue);

      // A different day still nudges.
      await pumpNudge(tester, container: c, note: _note('n2', '2026-09-16'));
      expect(find.text(_nudgePrompt), findsOneWidget);
    });

    testWidgets('Don\'t ask again flips the master toggle off and shows a '
        'snackbar', (tester) async {
      final c = await makeContainer();
      await pumpNudge(tester, container: c, note: _note('n1', '2026-09-15'));

      await tester.tap(find.text("Don't ask again"));
      await tester.pump();

      expect(c.read(defaultSettingsProvider).suggestPlaceForPastEntries, isFalse);
      expect(find.text('You can change this later in Settings.'), findsOneWidget);

      // Pump settles the snackbar then confirms the nudge is gone everywhere.
      await tester.pumpAndSettle();
      expect(find.text(_nudgePrompt), findsNothing);
      // A different, un-suppressed day is also silent now.
      await pumpNudge(tester, container: c, note: _note('n2', '2026-09-16'));
      expect(find.text(_nudgePrompt), findsNothing);
    });
  });
}
