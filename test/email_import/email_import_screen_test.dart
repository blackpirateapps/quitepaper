import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/security/sensitive_preview_registry.dart';
import 'package:quitepaper/core/note_links/note_link_search_service.dart';
import 'package:quitepaper/features/email_import/application/email_import_gateway.dart';
import 'package:quitepaper/features/email_import/application/email_input.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/email_import/presentation/email_import_screen.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

class FakeEmailGateway implements EmailImportGateway {
  bool unlocked = true;
  bool fail = false;
  int saves = 0;
  Completer<void>? barrier;
  List<({String noteId, bool exact})> matches = [];
  EmailImportMode? mode;
  List<String>? tags;
  String? title;
  final destination = Note(
    id: 'dest',
    title: 'Destination',
    content: 'Existing',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final email = const EmailMessage(
    subject: 'Order confirmation',
    sender: 'Store',
    to: 'Recipient',
    originalDate: 'invalid',
    markdown: 'Thank you for your order.',
    fingerprint: 'hash',
  );
  @override
  bool get isUnlocked => unlocked;
  @override
  Future<void> initialize() async {}
  @override
  Future<EmailMessage> parse(EmailInput input) async {
    if (input.path == 'invalid') {
      throw const EmailImportException('invalid', 'Not a supported email.');
    }
    return email;
  }

  @override
  Future<List<({String noteId, bool exact})>> duplicates(
    EmailMessage email,
  ) async => [...matches];
  @override
  Future<Note?> note(String id) async => destination;
  @override
  Future<List<NoteLinkSearchResultItem>> search(String query) async => [
    NoteLinkSearchResultItem(
      id: 'dest',
      title: 'Destination',
      snippet: 'Existing',
      tags: [],
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  Future<Note> save({
    required EmailMessage email,
    required EmailImportMode mode,
    required String title,
    required List<String> tags,
    Note? destination,
    required bool allowDuplicate,
    required bool Function() isCancelled,
  }) async {
    saves++;
    this.mode = mode;
    this.tags = tags;
    this.title = title;
    await barrier?.future;
    if (fail) {
      throw const EmailImportException(
        'disk',
        'Could not save email. Check storage.',
      );
    }
    return this.destination;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeEmailGateway gateway;
  setUp(() => gateway = FakeEmailGateway());
  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    EmailImportRequest? request,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [emailImportGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<List<Note>>(
                    builder: (_) => EmailImportScreen(
                      request:
                          request ??
                          EmailImportRequest(
                            inputs: const [EmailInput(path: 'email')],
                          ),
                    ),
                  ),
                ),
                child: const Text('Launch'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('metadata, content, editable title, tags and successful return', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Import Email'), findsOneWidget);
    expect(find.text('Thank you for your order.'), findsOneWidget);
    expect(
      find.text(
        'Shared content — original email and missing headers are unavailable.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note title'),
      'My order',
    );
    await reveal(
      tester,
      find.widgetWithText(TextField, 'Tags (comma separated)'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tags (comma separated)'),
      'email, receipts',
    );
    await reveal(tester, find.widgetWithText(FilledButton, 'Import email'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import email'));
    await tester.pumpAndSettle();
    expect(gateway.saves, 1);
    expect(gateway.title, 'My order');
    expect(gateway.tags, ['email', 'receipts']);
    expect(find.text('Launch'), findsOneWidget);
  });
  testWidgets('duplicate warning disables Save until copy is explicit', (
    tester,
  ) async {
    gateway.matches = [(noteId: 'existing', exact: true)];
    await mount(tester);
    await reveal(tester, find.text('This email is already saved.'));
    final save = find.widgetWithText(FilledButton, 'Import email');
    await reveal(tester, save);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await reveal(tester, find.text('Import another copy of duplicate emails'));
    await tester.tap(find.text('Import another copy of duplicate emails'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });
  testWidgets('append requires explicit searchable destination selection', (
    tester,
  ) async {
    await mount(
      tester,
      request: EmailImportRequest(
        inputs: const [EmailInput(path: 'email')],
        currentNoteId: 'dest',
      ),
    );
    final modes = find.byType(DropdownButtonFormField<EmailImportMode>);
    await reveal(tester, modes);
    await tester.tap(modes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Append to existing note').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Destination'));
    await tester.tap(find.text('Destination'));
    await tester.pumpAndSettle();
    expect(find.text('Destination: Destination'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Import email');
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(gateway.mode, EmailImportMode.append);
  });
  testWidgets(
    'save progress prevents duplicate commits and preserves visible errors',
    (tester) async {
      gateway.barrier = Completer<void>();
      gateway.fail = true;
      await mount(tester);
      final save = find.widgetWithText(FilledButton, 'Import email');
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pump();
      expect(gateway.saves, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      gateway.barrier!.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not save email. Check storage.'),
        findsOneWidget,
      );
      expect(gateway.saves, 1);
    },
  );
  testWidgets('Escape cancels preview without saving', (tester) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(gateway.saves, 0);
    expect(find.text('Launch'), findsOneWidget);
  });
  testWidgets('mixed batch lists invalid items and permits valid selection', (
    tester,
  ) async {
    await mount(
      tester,
      request: EmailImportRequest(
        inputs: const [
          EmailInput(path: 'email'),
          EmailInput(path: 'invalid'),
        ],
      ),
    );
    expect(
      find.textContaining('Item 2: invalid — Not a supported email.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 selected • 1 valid • 1 invalid'),
      findsOneWidget,
    );
  });
  testWidgets('lock invalidates retained shared preview and prevents saving', (
    tester,
  ) async {
    final request = EmailImportRequest(sharedContent: gateway.email);
    await mount(tester, request: request);
    SensitivePreviewRegistry.invalidate();
    await tester.pumpAndSettle();
    expect(request.sharedContent, isNull);
    expect(find.text('Thank you for your order.'), findsNothing);
    expect(find.textContaining('Preview cleared.'), findsOneWidget);
    expect(gateway.saves, 0);
  });
  testWidgets('locked vault displays no incoming content', (tester) async {
    gateway.unlocked = false;
    await mount(tester);
    expect(find.text('Thank you for your order.'), findsNothing);
    expect(find.textContaining('Preview cleared.'), findsOneWidget);
  });
  testWidgets('dark narrow phone supports scrolling without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, dark: true);
    await reveal(tester, find.widgetWithText(FilledButton, 'Import email'));
    expect(tester.takeException(), isNull);
  });
}
