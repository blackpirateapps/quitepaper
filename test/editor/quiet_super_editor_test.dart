import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';

class _MockTypographyNotifier extends TypographySettingsNotifier {
  _MockTypographyNotifier(TypographySettings settings) : super(null) {
    state = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SuperEditor Markdown Serialization Tests', () {
    test('deserializes and serializes task items correctly', () {
      const markdown = '''# Tasks

- [ ] Buy groceries
- [x] Clean desk
''';

      final doc = deserializeMarkdownToDocument(markdown);
      expect(doc.nodeCount, equals(3));

      expect(doc.getNodeAt(0), isA<ParagraphNode>());
      expect((doc.getNodeAt(0) as ParagraphNode).text.toPlainText(), equals('Tasks'));

      expect(doc.getNodeAt(1), isA<TaskNode>());
      final task1 = doc.getNodeAt(1) as TaskNode;
      expect(task1.text.toPlainText(), equals('Buy groceries'));
      expect(task1.isComplete, isFalse);

      expect(doc.getNodeAt(2), isA<TaskNode>());
      final task2 = doc.getNodeAt(2) as TaskNode;
      expect(task2.text.toPlainText(), equals('Clean desk'));
      expect(task2.isComplete, isTrue);

      final serialized = serializeDocumentToMarkdown(doc);
      expect(serialized, contains('- [ ] Buy groceries'));
      expect(serialized, contains('- [x] Clean desk'));
    });

    test('toggling task completion serializes updated markdown', () {
      const markdown = '- [ ] Incomplete task\n';
      final doc = deserializeMarkdownToDocument(markdown);
      final task = doc.getNodeAt(0) as TaskNode;
      expect(task.isComplete, isFalse);

      doc.replaceNodeById(task.id, task.copyTaskWith(isComplete: true));
      final serialized = serializeDocumentToMarkdown(doc);
      expect(serialized, contains('- [x] Incomplete task'));
    });
  });

  group('QuietSuperEditor Widget Tests', () {
    Widget buildTestWidget({
      required String markdown,
      required ValueChanged<String> onChanged,
      bool stripFrontmatter = false,
    }) {
      return ProviderScope(
        overrides: [
          typographySettingsProvider.overrideWith(
            (ref) => _MockTypographyNotifier(const TypographySettings()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Scaffold(
            body: QuietSuperEditor(
              initialMarkdown: markdown,
              onChanged: onChanged,
              stripFrontmatter: stripFrontmatter,
            ),
          ),
        ),
      );
    }

    testWidgets('renders SuperEditor and displays initial markdown content', (tester) async {
      const markdown = '# Hello World\n\nThis is a super editor note.';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietSuperEditor), findsOneWidget);
      expect(find.byType(SuperEditor), findsOneWidget);
      expect(find.text('Hello World', findRichText: true), findsOneWidget);
      expect(find.text('This is a super editor note.', findRichText: true), findsOneWidget);
    });

    testWidgets('renders task nodes with checkboxes', (tester) async {
      const markdown = '- [ ] First task\n- [x] Second task';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperEditor), findsOneWidget);
      expect(find.text('First task', findRichText: true), findsOneWidget);
      expect(find.text('Second task', findRichText: true), findsOneWidget);
    });

    testWidgets('preserves frontmatter prefix when stripFrontmatter is true', (tester) async {
      const frontmatter = '---\ntitle: Test Note\ntags:\n  - sample\n---\n';
      const body = 'Actual body text here.';
      const full = '$frontmatter$body';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: full,
          stripFrontmatter: true,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actual body text here.', findRichText: true), findsOneWidget);
      // Frontmatter should be stripped from visible document
      expect(find.text('title: Test Note', findRichText: true), findsNothing);
    });
  });
}
