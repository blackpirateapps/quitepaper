import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/location/location_models.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';

const _initial =
    '---\njournal: true\ndate: 2026-11-24\nlocation:\n  address: "Kolkata, India"\n  latitude: 22.57\n  longitude: 88.36\n---\n\nOriginal reflection.';
const _payload = '{"current":{"temperature_2m":25,"weather_code":3}}';

void main() {
  late String live;
  late String? submitted;
  late Object documentId;
  late bool readOnly;
  late StateSetter rebuild;
  late MockClient client;
  late List<Completer<http.Response>> responses;

  setUp(() {
    live = _initial;
    submitted = null;
    documentId = 'journal-a';
    readOnly = false;
    responses = [];
    client = MockClient((_) {
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    });
  });
  tearDown(() => client.close());

  Future<void> mount(
    WidgetTester tester, {
    String Function()? readDocument,
    Future<JournalLocation> Function()? fetchLocation,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return FrontmatterPropertiesSection(
                  key: const ValueKey('properties'),
                  frontmatter: FrontmatterEditorHelper.parse(live),
                  rawDocument: live,
                  readOnly: readOnly,
                  isJournal: true,
                  documentId: documentId,
                  readDocument: readDocument,
                  fetchLocation: fetchLocation,
                  onDocumentChanged: (value) => submitted = value,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fetch(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Fetch Weather'));
    await http.runWithClient(() async {
      await tester.tap(find.text('Fetch Weather'));
      await tester.pump();
    }, () => client);
  }

  testWidgets('weather merges into the rebuilt body and newer properties', (
    tester,
  ) async {
    await mount(tester);
    await fetch(tester);
    expect(responses, hasLength(1));
    rebuild(() {
      live = FrontmatterEditorHelper.updateProperty(
        documentText: '$live\nAdded while fetching.',
        key: 'author',
        newValue: 'New author',
      );
    });
    await tester.pump();
    responses.single.complete(http.Response(_payload, 200));
    await tester.pumpAndSettle();
    expect(submitted, contains('Added while fetching.'));
    expect(FrontmatterEditorHelper.parse(submitted!).author, 'New author');
    expect(FrontmatterEditorHelper.parse(submitted!).weather!.temperature, 25);
  });

  testWidgets('reads the latest buffer even before the parent rebuilds', (
    tester,
  ) async {
    var reads = 0;
    await mount(
      tester,
      readDocument: () {
        reads++;
        return live;
      },
    );
    await fetch(tester);
    live += '\nPending Visual text.';
    responses.single.complete(http.Response(_payload, 200));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(submitted, contains('Pending Visual text.'));
    expect(submitted, contains('temperature: 25.0'));
  });

  testWidgets('edits during both location and weather waits survive', (
    tester,
  ) async {
    live = FrontmatterEditorHelper.removeLocation(documentText: live);
    final location = Completer<JournalLocation>();
    await mount(tester, fetchLocation: () => location.future);
    await fetch(tester);
    expect(responses, isEmpty);
    rebuild(() => live += '\nEdited during GPS.');
    await tester.pump();
    await http.runWithClient(() async {
      location.complete(
        const JournalLocation(
          address: 'Home',
          latitude: 22.57,
          longitude: 88.36,
        ),
      );
      await tester.pump();
    }, () => client);
    expect(responses, hasLength(1));
    rebuild(() => live += '\nEdited during HTTP.');
    await tester.pump();
    responses.single.complete(http.Response(_payload, 200));
    await tester.pumpAndSettle();
    expect(submitted, contains('Edited during GPS.'));
    expect(submitted, contains('Edited during HTTP.'));
    expect(FrontmatterEditorHelper.parse(submitted!).location!.address, 'Home');
  });

  for (final change in ['location', 'weather', 'read-only']) {
    testWidgets('a newer $change state supersedes pending weather', (
      tester,
    ) async {
      await mount(tester);
      await fetch(tester);
      rebuild(() {
        if (change == 'location') {
          live = FrontmatterEditorHelper.updateLocation(
            documentText: live,
            location: const JournalLocation(
              address: 'Kyoto',
              latitude: 35,
              longitude: 135,
            ),
          );
        } else if (change == 'weather') {
          live = live.replaceFirst(
            'journal: true',
            'journal: true\nweather:\n  temperature: 18.0\n  condition: Rain\n  code: 61',
          );
        } else {
          readOnly = true;
        }
        live += '\nKeep the latest text.';
      });
      await tester.pump();
      responses.single.complete(http.Response(_payload, 200));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(live, contains('Keep the latest text.'));
    });
  }

  testWidgets(
    'switching documents ignores an old response without clearing a new request',
    (tester) async {
      await mount(tester);
      await fetch(tester);
      rebuild(() {
        documentId = 'journal-b';
        live = '$_initial\nSecond document.';
      });
      await tester.pump();
      await fetch(tester);
      expect(responses, hasLength(2));
      responses.first.complete(http.Response(_payload, 200));
      await tester.pump();
      expect(submitted, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      responses.last.complete(http.Response(_payload, 200));
      await tester.pumpAndSettle();
      expect(submitted, contains('Second document.'));
    },
  );

  testWidgets('failed or disposed requests cannot replace the document', (
    tester,
  ) async {
    await mount(tester);
    await fetch(tester);
    rebuild(() => live += '\nKeep after failure.');
    await tester.pump();
    responses.first.complete(http.Response('{"current":{}}', 200));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(find.textContaining('Could not fetch weather:'), findsOneWidget);
    await fetch(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    responses.last.complete(http.Response(_payload, 200));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(tester.takeException(), isNull);
  });
}
