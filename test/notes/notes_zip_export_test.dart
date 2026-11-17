import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import '../support/pump_until_found.dart';

class ZipPicker extends FilePicker {
  String? path;
  bool fail = false;
  Uint8List? suppliedBytes;
  int calls = 0;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    if (fail) throw StateError('Picker failed');
    suppliedBytes = bytes;
    return path;
  }
}

void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  late SharedPreferences prefs;
  late Directory directory;
  late ZipPicker picker;
  setUpAll(() => FilePicker.platform = ZipPicker());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repo = DriftNotesRepository(db);
    directory = await Directory.systemTemp.createTemp('qp-notes-zip-');
    picker = ZipPicker();
    final previous = FilePicker.platform;
    FilePicker.platform = picker;
    addTearDown(() => FilePicker.platform = previous);
    for (final title in ['Alpha', 'Beta']) {
      await repo.saveNote(
        Note(
          id: title,
          title: title,
          content: 'Body of $title',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
    }
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<void> export(WidgetTester t, {bool mobile = false}) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await t.pumpAndSettle();
    if (mobile) {
      await t.longPress(find.text('Alpha'));
    } else {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.tap(find.text('Alpha'));
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await t.pumpAndSettle();
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('More actions'));
    await t.pumpAndSettle();
    await t.tap(find.text('Export as ZIP…'));
    await t.pump();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  }

  for (final existing in [false, true]) {
    testWidgets(
      'NL-09: ZIP writes exact bytes to ${existing ? 'existing' : 'new'} desktop destination',
      (t) async {
        final target = File('${directory.path}/notes.zip');
        picker.path = target.path;
        if (existing) {
          await t.runAsync(
            () =>
                target.writeAsString(List.filled(10000, 'old archive').join()),
          );
        }
        await export(t);
        await pumpUntilFound(t, find.text('Exported 2 notes'));
        final bytes = (await t.runAsync(target.readAsBytes))!;
        expect(bytes, picker.suppliedBytes);
        final archive = ZipDecoder().decodeBytes(bytes);
        expect(
          {
            for (final file in archive)
              file.name: utf8.decode(file.content as List<int>),
          },
          {'Alpha.md': 'Body of Alpha', 'Beta.md': 'Body of Beta'},
        );
        await close(t);
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
  for (final path in [null, '']) {
    testWidgets('NL-09: ZIP picker cancellation ($path) saves nothing', (
      t,
    ) async {
      picker.path = path;
      await export(t);
      await t.pumpAndSettle();
      expect(picker.calls, 1);
      expect(await t.runAsync(() => directory.list().toList()), isEmpty);
      expect(find.text('Exported 2 notes'), findsNothing);
      expect(find.text("Couldn't export notes"), findsNothing);
      await close(t);
    }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
  }
  for (final pickerFailure in [false, true]) {
    testWidgets(
      'NL-09: ${pickerFailure ? 'picker' : 'write'} failure reports no success',
      (t) async {
        picker.path = directory.path;
        picker.fail = pickerFailure;
        await export(t);
        await pumpUntilFound(t, find.text("Couldn't export notes"));
        expect(find.text('Exported 2 notes'), findsNothing);
        expect(t.takeException(), isNull);
        await close(t);
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
  testWidgets('NL-09: mobile picker retains byte ownership', (t) async {
    picker.path = 'content://exports/notes.zip';
    await export(t, mobile: true);
    await pumpUntilFound(t, find.text('Exported 2 notes'));
    expect(picker.suppliedBytes, isNotEmpty);
    expect(find.text("Couldn't export notes"), findsNothing);
    await close(t);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));
}
