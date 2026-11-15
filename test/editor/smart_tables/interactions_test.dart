import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';

class _Typography extends TypographySettingsNotifier {
  _Typography() : super(null) {
    state = const TypographySettings();
  }
}

Widget host(Widget child) => ProviderScope(
  overrides: [typographySettingsProvider.overrideWith((ref) => _Typography())],
  child: MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  const source =
      '| Qty | Total |\n| --- | ---: |\n| 2 | =A2*125 |\n| 3 | =A3*40 |';
  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Tab, Shift Tab, caret arrows, Escape and navigation arrows', (
    tester,
  ) async {
    var value = const TextEditingValue(text: source);
    final c = MarkdownTableController(
      table: const MarkdownTableParser().findTables(source).single,
      getDocumentValue: () => value,
      onUpdateDocument: (v) => value = v,
      initialPosition: const TablePosition(row: 1, column: 1),
    );
    await tester.pumpWidget(host(MarkdownTableEditor(controller: c)));
    await tester.pumpAndSettle();
    expect(c.cellController.text, '=A2*125');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(c.activePosition, const TablePosition(row: 1, column: 1));
    await tester.enterText(find.byType(TextField), '=A2*200');
    await tester.pump();
    expect(value.text, contains('=A2*200'));
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.table.getCell(1, 1)!.trimmedText, '=A2*125');
    expect(c.navigationMode, true);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(c.activePosition, const TablePosition(row: 2, column: 1));
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.navigationMode, false);
    await key(tester, LogicalKeyboardKey.tab, shift: true);
    expect(c.activePosition, const TablePosition(row: 2, column: 0));
    await key(tester, LogicalKeyboardKey.tab);
    await key(tester, LogicalKeyboardKey.tab);
    expect(c.table.rowCount, 4);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('range TSV copy/paste and one-step undo/redo', (tester) async {
    var clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    var value = const TextEditingValue(text: source);
    final c = MarkdownTableController(
      table: const MarkdownTableParser().findTables(source).single,
      getDocumentValue: () => value,
      onUpdateDocument: (v) => value = v,
      initialPosition: const TablePosition(row: 1, column: 0),
    );
    await tester.pumpWidget(host(MarkdownTableEditor(controller: c)));
    await tester.pumpAndSettle();
    c.selectRange(
      const TablePosition(row: 1, column: 0),
      const TablePosition(row: 2, column: 1),
    );
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.keyC, control: true);
    expect(clipboard, '2\t=A2*125\n3\t=A3*40');
    clipboard = '4\t=A2*50\n5\t=A3*10';
    c.setActivePosition(const TablePosition(row: 1, column: 0));
    await tester.pumpAndSettle();
    final before = value.text;
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(c.table.getCell(1, 0)!.trimmedText, '4');
    expect(c.calculations.value(1, 1).display, '200');
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(value.text, before);
    await key(tester, LogicalKeyboardKey.keyZ, control: true, shift: true);
    expect(c.table.getCell(1, 0)!.trimmedText, '4');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  testWidgets(
    'mobile Next publishes source, composing input waits for commit',
    (tester) async {
      var value = const TextEditingValue(text: source);
      final c = MarkdownTableController(
        table: const MarkdownTableParser().findTables(source).single,
        getDocumentValue: () => value,
        onUpdateDocument: (v) => value = v,
        initialPosition: const TablePosition(row: 1, column: 0),
      );
      await tester.pumpWidget(host(MarkdownTableEditor(controller: c)));
      await tester.pumpAndSettle();
      c.cellController.value = const TextEditingValue(
        text: '42',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      expect(value.text, source);
      c.cellController.value = const TextEditingValue(
        text: '42',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      expect(c.calculations.value(1, 1).display, '5250');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(c.activePosition, const TablePosition(row: 1, column: 1));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'visual typing publishes before Done and retains metadata on reopen',
    (tester) async {
      const annotated =
          '$source\n<!-- quiet-paper-table:v1 {"id":"qt_test","formats":{"1":{"type":"currency","currency":"INR","digits":2}}} -->';
      var changed = '';
      final superController = QuietSuperEditorController();
      await tester.pumpWidget(
        host(
          QuietSuperEditor(
            initialMarkdown: annotated,
            controller: superController,
            onChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2', findRichText: true));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4');
      await tester.pumpAndSettle();
      expect(changed, contains('| 4 | =A2*125 |'));
      expect(changed, contains('quiet-paper-table:v1'));
      expect(changed, contains('"currency":"INR"'));
      superController.undo();
      await tester.pumpAndSettle();
      expect(changed, contains('| 2 | =A2*125 |'));
      superController.redo();
      await tester.pumpAndSettle();
      expect(changed, contains('| 4 | =A2*125 |'));

      await tester.pumpWidget(
        host(
          QuietSuperEditor(
            key: const ValueKey('reopen'),
            initialMarkdown: changed,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹500.00', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      superController.dispose();
    },
  );
  testWidgets('readonly formula cells expose results without editing actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        QuietSuperEditor(
          initialMarkdown: source,
          readOnly: true,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('250', findRichText: true), findsOneWidget);
    expect(find.byTooltip('Delete table'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('expanded edits return as a single inline history transaction', (
    tester,
  ) async {
    var changed = source;
    await tester.pumpWidget(
      host(
        QuietSuperEditor(
          initialMarkdown: source,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2', findRichText: true));
    await tester.pumpAndSettle();
    final inline = tester
        .widget<MarkdownTableEditor>(find.byType(MarkdownTableEditor))
        .controller;
    final before = changed;
    await tester.tap(find.byTooltip('Open full screen'));
    await tester.pumpAndSettle();
    final expanded = tester
        .widget<MarkdownTableEditor>(find.byType(MarkdownTableEditor))
        .controller;
    expanded.setActivePosition(const TablePosition(row: 1, column: 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '8');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(changed, contains('| 8 | =A2*125 |'));
    inline.undo();
    await tester.pumpAndSettle();
    expect(changed, before);
    inline.redo();
    await tester.pumpAndSettle();
    expect(changed, contains('| 8 | =A2*125 |'));
    await tester.pumpWidget(const SizedBox());
  });
}
