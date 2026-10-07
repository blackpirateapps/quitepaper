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
}
