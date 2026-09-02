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

    testWidgets('renders empty SizedBox when document has no frontmatter', (tester) async {
      await tester.pumpWidget(buildTestSection(
        frontmatter: FrontmatterDocument.empty,
        rawDocument: '# Plain Note',
        onDocumentChanged: (_) {},
      ));

      expect(find.byType(FrontmatterPropertiesSection), findsOneWidget);
      expect(find.text('PROPERTIES'), findsNothing);
    });
  });
}
