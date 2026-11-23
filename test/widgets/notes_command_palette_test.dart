import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_command_palette.dart';

CommandPaletteEntry entry(String label, int value) => CommandPaletteEntry(
  label: label,
  description: 'Test command',
  icon: Icons.search,
  value: value,
);

void main() {
  Future<void> open(
    WidgetTester tester, {
    required List<CommandPaletteEntry> entries,
    Future<List<CommandPaletteEntry>> Function(String)? search,
    void Function(CommandPaletteEntry?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.linux,
          extensions: const [AppColors.light],
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showCommandPalette(
                context,
                entries: entries,
                search: search,
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'arrow keys select commands and Enter activates the selected result',
    (tester) async {
      CommandPaletteEntry? result;
      await open(
        tester,
        entries: [entry('First', 1), entry('Second', 2)],
        onResult: (value) => result = value,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Second'))
            .selected,
        true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result?.value, 2);
    },
  );

  testWidgets(
    'stale async results cannot replace a newer query or activate after dismissal',
    (tester) async {
      final older = Completer<List<CommandPaletteEntry>>();
      final newer = Completer<List<CommandPaletteEntry>>();
      await open(
        tester,
        entries: [],
        search: (query) {
          if (query == 'old') return older.future;
          if (query == 'new') return newer.future;
          return Future.value([]);
        },
      );
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump(const Duration(milliseconds: 200));
      newer.complete([entry('Current note', 2)]);
      await tester.pumpAndSettle();
      expect(find.text('Current note'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      older.complete([entry('Obsolete note', 1)]);
      await tester.pumpAndSettle();
      expect(find.text('Obsolete note'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiword queries match across command label and description', (
    tester,
  ) async {
    await open(tester, entries: [entry('Sort notes', 1), entry('New note', 2)]);
    await tester.enterText(find.byType(TextField), 'notes sort');
    await tester.pumpAndSettle();
    expect(find.text('Sort notes'), findsOneWidget);
    expect(find.text('New note'), findsNothing);
  });
}
