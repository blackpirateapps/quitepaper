import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';
import 'package:quitepaper/features/editor/domain/frontmatter_document.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';

void main() {
  const sampleMarkdown = '''---
title: Research Notes
author: Dr. Watson
created: 2026-09-02
source: https://notes.example.org
description: Case study documentation.
tags: [case, investigation]
---
# Content Body
''';

  Widget buildTestSection({
    required FrontmatterDocument frontmatter,
    required String rawDocument,
    required ValueChanged<String> onDocumentChanged,
    bool readOnly = false,
    bool initialExpanded = true,
    bool isJournal = false,
  }) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
      home: Scaffold(
        body: SingleChildScrollView(
          child: FrontmatterPropertiesSection(
            frontmatter: frontmatter,
            rawDocument: rawDocument,
            onDocumentChanged: onDocumentChanged,
            readOnly: readOnly,
            initialExpanded: initialExpanded,
            isJournal: isJournal,
          ),
        ),
      ),
    );
  }

  group('FrontmatterPropertiesSection Widget Tests', () {
    testWidgets('renders expanded by default with recognized fields', (tester) async {
      final doc = FrontmatterEditorHelper.parse(sampleMarkdown);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: sampleMarkdown,
        onDocumentChanged: (_) {},
      ));

      expect(find.text('PROPERTIES'), findsOneWidget);
      expect(find.text('Author'), findsOneWidget);
      expect(find.text('Dr. Watson'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('2026-09-02'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('https://notes.example.org'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Case study documentation.'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('#case'), findsOneWidget);
      expect(find.text('#investigation'), findsOneWidget);
    });

    testWidgets('tapping header collapses and expands properties', (tester) async {
      final doc = FrontmatterEditorHelper.parse(sampleMarkdown);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: sampleMarkdown,
        onDocumentChanged: (_) {},
      ));

      // Initially expanded
      expect(find.text('Author'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('PROPERTIES'));
      await tester.pumpAndSettle();

      // Fields are collapsed, summary label is visible in header
      expect(find.text('Author'), findsNothing);
      expect(find.text('Dr. Watson · 2026-09-02 · 2 tags'), findsOneWidget);

      // Tap header again to expand
      await tester.tap(find.text('PROPERTIES'));
      await tester.pumpAndSettle();

      expect(find.text('Author'), findsOneWidget);
    });

    testWidgets('editing property submits updated canonical markdown', (tester) async {
      final doc = FrontmatterEditorHelper.parse(sampleMarkdown);
      String? updatedDocument;

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: sampleMarkdown,
        onDocumentChanged: (val) => updatedDocument = val,
      ));

      // Find author text field and enter new name
      final authorField = find.widgetWithText(TextField, 'Dr. Watson');
      expect(authorField, findsOneWidget);

      await tester.enterText(authorField, 'Sherlock Holmes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(updatedDocument, isNotNull);
      final updatedDoc = FrontmatterEditorHelper.parse(updatedDocument!);
      expect(updatedDoc.author, equals('Sherlock Holmes'));
      expect(updatedDocument, contains('author: Sherlock Holmes'));
    });

    testWidgets('shows notice when frontmatter is malformed', (tester) async {
      const malformed = FrontmatterDocument(
        hasFrontmatter: true,
        isMalformed: true,
      );

      await tester.pumpWidget(buildTestSection(
        frontmatter: malformed,
        rawDocument: '--- invalid ---',
        onDocumentChanged: (_) {},
      ));

      expect(find.text('YAML frontmatter could not be parsed. Use Edit Markdown to inspect.'), findsOneWidget);
    });

    testWidgets('renders empty SizedBox when document only has title in frontmatter', (tester) async {
      final doc = FrontmatterEditorHelper.parse('''---
title: Only A Title
---
# Main Content
''');
      expect(doc.hasMatchingSectionProperties, isFalse);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: '--- \ntitle: Only A Title\n---\n# Main Content\n',
        onDocumentChanged: (_) {},
      ));

      expect(find.text('PROPERTIES'), findsNothing);
    });

    testWidgets('renders empty SizedBox when document has no frontmatter', (tester) async {
      await tester.pumpWidget(buildTestSection(
        frontmatter: FrontmatterDocument.empty,
        rawDocument: '# Plain Note',
        onDocumentChanged: (_) {},
      ));

      expect(find.byType(FrontmatterPropertiesSection), findsOneWidget);
      expect(find.text('PROPERTIES'), findsNothing);
    });

    testWidgets('journal mode filters out author, source, and description when empty', (tester) async {
      const journalMarkdown = '''---
journal: true
date: 2026-09-21
tags: [diary]
---
# Today
''';
      final doc = FrontmatterEditorHelper.parse(journalMarkdown);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: journalMarkdown,
        onDocumentChanged: (_) {},
        isJournal: true,
      ));

      expect(find.text('PROPERTIES'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('2026-09-21'), findsOneWidget);
      // Author, Source, Description should NOT be visible
      expect(find.text('Author'), findsNothing);
      expect(find.text('Source'), findsNothing);
      expect(find.text('Description'), findsNothing);
      // Location and Tags should be visible
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Fetch Location'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('#diary'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget); // + Tag button
    });

    testWidgets('journal mode shows author if explicitly provided', (tester) async {
      const journalWithAuthor = '''---
journal: true
date: 2026-09-21
author: Alice Walker
tags: [diary]
---
# Today
''';
      final doc = FrontmatterEditorHelper.parse(journalWithAuthor);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: journalWithAuthor,
        onDocumentChanged: (_) {},
        isJournal: true,
      ));

      expect(find.text('Author'), findsOneWidget);
      expect(find.text('Alice Walker'), findsOneWidget);
      // Source and Description remain hidden
      expect(find.text('Source'), findsNothing);
      expect(find.text('Description'), findsNothing);
    });

    testWidgets('journal mode displays address and coordinates when location is present', (tester) async {
      const journalWithLoc = '''---
journal: true
date: 2026-09-21
location:
  address: "1600 Amphitheatre Pkwy, Mountain View, CA"
  latitude: 37.422
  longitude: -122.084
tags: [diary]
---
# Today
''';
      final doc = FrontmatterEditorHelper.parse(journalWithLoc);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: journalWithLoc,
        onDocumentChanged: (_) {},
        isJournal: true,
      ));

      expect(find.text('1600 Amphitheatre Pkwy, Mountain View, CA'), findsOneWidget);
      expect(find.text('37.422000, -122.084000'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('non-journal note displays empty Author, Source, Description fields', (tester) async {
      const noteMarkdown = '''---
title: Standard Note
created: 2026-09-21
tags: [work]
---
# Work Notes
''';
      final doc = FrontmatterEditorHelper.parse(noteMarkdown);

      await tester.pumpWidget(buildTestSection(
        frontmatter: doc,
        rawDocument: noteMarkdown,
        onDocumentChanged: (_) {},
        isJournal: false,
      ));

      expect(find.text('Author'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      // Location is not shown for non-journal notes without location
      expect(find.text('Location'), findsNothing);
    });
  });
}
