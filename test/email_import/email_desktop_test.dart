import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/email_import/application/email_import_gateway.dart';
import 'package:quitepaper/features/email_import/application/email_input.dart';
import 'package:quitepaper/features/email_import/presentation/email_workspace_actions.dart';
import 'package:quitepaper/features/email_import/presentation/email_import_screen.dart';
import 'email_import_screen_test.dart' show FakeEmailGateway;

void main() {
  test('file URI list normalization ignores ordinary text and URI comments', () {
    final detail = DropDoneDetails(
      files: [],
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
      rawText:
          '# comment\nfile:///run/user/1000/doc/email%20file.eml\n/tmp/other.eml\nordinary paragraph',
    );
    expect(EmailDesktopRouter.paths(detail), [
      '/run/user/1000/doc/email file.eml',
      '/tmp/other.eml',
    ]);
  });
  test('generic MIME candidate uses bounded content inspection', () async {
    final dir = await Directory.systemTemp.createTemp('email-desktop-');
    try {
      final file = await File('${dir.path}/download.bin').writeAsBytes(
        await File('test/email_import/fixtures/plain.eml').readAsBytes(),
      );
      expect(
        await EmailInput(
          path: file.path,
          mimeType: 'application/octet-stream',
        ).isEmailCandidate(),
        isTrue,
      );
      final image = await File(
        '${dir.path}/image.png',
      ).writeAsBytes([137, 80, 78, 71]);
      expect(await EmailInput(path: image.path).isEmailCandidate(), isFalse);
      expect(
        await const EmailInput(path: '/missing/file.eml').isEmailCandidate(),
        isTrue,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
  testWidgets(
    'nested drop routing shares classification and opens only one preview',
    (tester) async {
      final gateway = FakeEmailGateway();
      late BuildContext ctx;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [emailImportGatewayProvider.overrideWithValue(gateway)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(body: Text('Workspace'));
              },
            ),
          ),
        ),
      );
      final first = EmailDesktopRouter.route(ctx, [
        'test/email_import/fixtures/plain.eml',
      ]);
      final second = EmailDesktopRouter.route(ctx, [
        'test/email_import/fixtures/plain.eml',
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(EmailImportScreen), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(gateway.saves, 0);
    },
  );
  testWidgets(
    'ordinary document and image drops remain with original handlers',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final results = await tester.runAsync(() async {
        final first = EmailDesktopRouter.route(ctx, ['/missing/image.png']);
        final nested = EmailDesktopRouter.route(ctx, ['/missing/image.png']);
        return Future.wait([first, nested]);
      });
      expect(results, [false, false]);
      expect(find.byType(EmailImportScreen), findsNothing);
    },
  );
  testWidgets(
    'desktop command palette is searchable and exposes file fallback',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: AppTheme.light(),
          builder: (context, child) =>
              EmailWorkspaceActions(navigatorKey: nav, child: child!),
          home: const Scaffold(body: TextField(autofocus: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Import Email'), findsOneWidget);
      expect(find.text('Import Email from all files'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Commands'),
        'generic',
      );
      await tester.pumpAndSettle();
      expect(find.text('Import Email'), findsNothing);
      expect(find.text('Import Email from all files'), findsOneWidget);
    },
  );
}
