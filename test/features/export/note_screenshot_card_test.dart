import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';
import 'package:quitepaper/features/export/presentation/widgets/note_screenshot_card.dart';

void main() {
  testWidgets('NoteScreenshotCard renders note title, tags, markdown and branding', (tester) async {
    final snapshot = NoteExportSnapshot(
      noteId: 'card-test-1',
      title: 'Architectural Blueprint',
      markdown: '# Blueprint\n\n==Important concept== in Quiet Paper.\n\n```dart\nvoid main() {}\n```',
      createdAt: DateTime.utc(2026, 1, 15, 10, 30),
      updatedAt: DateTime.utc(2026, 1, 16, 12, 0),
      tags: const ['architecture', 'design'],
      isPinned: true,
      attachments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteScreenshotCard(
              snapshot: snapshot,
              options: const ImageExportOptions(
                includeMetadata: true,
                includeTags: true,
                includeBranding: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title
    expect(find.text('Architectural Blueprint'), findsOneWidget);

    // Verify tags
    expect(find.text('#architecture'), findsOneWidget);
    expect(find.text('#design'), findsOneWidget);

    // Verify branding footer
    expect(find.text('Quiet Paper'), findsOneWidget);
    expect(find.text('quietpaper.blackpiratex.com'), findsOneWidget);
  });

  testWidgets('NoteScreenshotCard respects options when branding, tags, and metadata are hidden', (tester) async {
    final snapshot = NoteExportSnapshot(
      noteId: 'card-test-2',
      title: 'Quiet Note',
      markdown: 'Only the plain text content here.',
      createdAt: DateTime.utc(2026, 1, 15),
      updatedAt: DateTime.utc(2026, 1, 16),
      tags: const ['hidden-tag'],
      isPinned: false,
      attachments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteScreenshotCard(
              snapshot: snapshot,
              options: const ImageExportOptions(
                includeMetadata: false,
                includeTags: false,
                includeBranding: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Note title is still displayed as the document title
    expect(find.text('Quiet Note'), findsOneWidget);

    // Creation date metadata is absent
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);

    // Tags should be absent
    expect(find.text('#hidden-tag'), findsNothing);

    // Branding should be absent
    expect(find.text('quietpaper.blackpiratex.com'), findsNothing);

    // Body content is present
    expect(find.text('Only the plain text content here.'), findsOneWidget);
  });

  testWidgets('NoteScreenshotCard automatically deserializes RichDocument JSON and displays formatted text instead of raw JSON', (tester) async {
    const richJson = '{"\$schema":"quietpaper:rich_document:v1","blocks":[{"type":"paragraph","id":"p-1","spans":[{"text":"There was a video tape of abuse and murder"}]},{"type":"paragraph","id":"p-2","spans":[{"text":"there were two "},{"text":"people","attributes":{"bold":true}},{"text":" involved in it."}]}]}';

    final snapshot = NoteExportSnapshot(
      noteId: 'card-test-rich',
      title: 'There was a video tape of...',
      markdown: richJson,
      createdAt: DateTime.utc(2026, 10, 7),
      updatedAt: DateTime.utc(2026, 10, 7),
      tags: const [],
      attachments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteScreenshotCard(
              snapshot: snapshot,
              options: const ImageExportOptions(
                includeMetadata: true,
                includeTags: true,
                includeBranding: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title
    expect(find.text('There was a video tape of...'), findsOneWidget);

    // Verify raw JSON keys are NEVER visible
    expect(find.textContaining(r'{"$schema":'), findsNothing);
    expect(find.textContaining('"blocks":'), findsNothing);
    expect(find.textContaining('"spans":'), findsNothing);

    // Verify formatted text is displayed
    expect(find.textContaining('There was a video tape of abuse and murder'), findsOneWidget);
    expect(find.textContaining('involved in it.'), findsOneWidget);

    // Verify branding footer is present
    expect(find.text('quietpaper.blackpiratex.com'), findsOneWidget);
  });
}
