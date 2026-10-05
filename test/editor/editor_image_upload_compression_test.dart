import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/image_processing/image_compression_service.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/image_compression_dialog.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/default_settings_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/domain/default_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestImageCompressionService implements ImageCompressionService {
  TestImageCompressionService({this.sizeThreshold = 500 * 1024});

  final int sizeThreshold;
  int compressCallCount = 0;

  @override
  bool isEligibleForCompression(int byteSize) => byteSize > sizeThreshold;

  @override
  Future<({int width, int height})> probeDimensions(Uint8List rawBytes) async {
    return (width: 2400, height: 1600);
  }

  @override
  Future<CompressedImageResult> compressImage({
    required Uint8List rawBytes,
    required String fileName,
    ImageCompressionPreset preset = ImageCompressionPreset.balanced,
    bool force = false,
  }) async {
    compressCallCount++;
    return CompressedImageResult(
      bytes: rawBytes,
      originalByteSize: rawBytes.length,
      compressedByteSize: (rawBytes.length * 0.4).round(),
      width: preset.maxDimension,
      height: (preset.maxDimension * 0.6).round(),
      mimeType: 'image/jpeg',
      fileName: fileName,
      wasCompressed: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotesRepository repository;
  late SharedPreferences prefs;
  late Directory tempDir;
  late AttachmentLocalStorage storage;
  late MockKeyManager keyManager;
  late AttachmentService attachmentService;
  late TestImageCompressionService compressionService;
  late File largeImageFile;
  late File smallImageFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);

    tempDir = await Directory.systemTemp.createTemp('editor_compression_test_');
    storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
    final cryptoService = DefaultCryptoService();
    final masterKey = cryptoService.generateRandomBytes(32);
    keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

    attachmentService = AttachmentService(
      database: db,
      keyManager: keyManager,
      crypto: AttachmentCrypto(cryptoService: cryptoService),
      storage: storage,
    );

    compressionService = TestImageCompressionService();

    // Create a large image (> 500 KB, e.g. 2400x1600 uncompressed)
    final largeImg = img.Image(width: 2400, height: 1600);
    img.fill(largeImg, color: img.ColorRgb8(120, 140, 180));
    final largeBytes = Uint8List.fromList(img.encodeJpg(largeImg, quality: 100));
    largeImageFile = File('${tempDir.path}/large_photo.jpg');
    if (largeBytes.length < 520 * 1024) {
      // Pad to ensure > 500 KB threshold
      final padded = Uint8List(550 * 1024);
      padded.setRange(0, largeBytes.length, largeBytes);
      await largeImageFile.writeAsBytes(padded);
    } else {
      await largeImageFile.writeAsBytes(largeBytes);
    }

    // Create a small image (<= 500 KB)
    final smallImg = img.Image(width: 200, height: 200);
    img.fill(smallImg, color: img.ColorRgb8(10, 20, 30));
    final smallBytes = Uint8List.fromList(img.encodeJpg(smallImg, quality: 75));
    smallImageFile = File('${tempDir.path}/small_icon.jpg');
    await smallImageFile.writeAsBytes(smallBytes);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildEditorApp(Note note) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        keyManagerProvider.overrideWithValue(keyManager),
        attachmentServiceProvider.overrideWithValue(attachmentService),
        imageCompressionServiceProvider.overrideWithValue(compressionService),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppColors.light],
        ),
        home: EditorScreen(note: note),
      ),
    );
  }

  testWidgets('Dropping image > 500 KB with default setting (ask) triggers ImageCompressionDialog and compresses on confirm', (tester) async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-note-1',
      title: 'Compression Flow Note',
      content: 'Initial body\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTargetFinder = find.byType(DropTarget);
    expect(dropTargetFinder, findsOneWidget);
    final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

    // Simulate drop done with large image inside runAsync so File I/O resolves
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Verify dialog appeared
    expect(find.byType(ImageCompressionDialog), findsOneWidget);
    expect(find.text('Optimize Image'), findsOneWidget);
    expect(find.text('Compress & Optimize'), findsOneWidget);

    // Tap "Insert Image"
    await tester.tap(find.text('Insert Image'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.byType(ImageCompressionDialog), findsNothing);

    // Check that attachment markdown was inserted
    expect(find.textContaining('qp://asset/'), findsOneWidget);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Dropping image > 500 KB with "Remember my choice" updates DefaultSettings to alwaysCompress', (tester) async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-note-2',
      title: 'Remember Choice Note',
      content: 'Hello\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Check "Remember my choice"
    await tester.tap(find.text('Remember my choice'));
    await tester.pumpAndSettle();

    // Confirm insert
    await tester.tap(find.text('Insert Image'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Verify preference was persisted
    expect(
      prefs.getString(DefaultSettingsNotifier.imageCompressionActionKey),
      'always_compress',
    );

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Dropping image > 500 KB when setting is alwaysCompress bypasses dialog and compresses directly', (tester) async {
    // Set setting to alwaysCompress
    prefs.setString(DefaultSettingsNotifier.imageCompressionActionKey, 'always_compress');

    final now = DateTime.now();
    final note = Note(
      id: 'test-note-3',
      title: 'Always Compress Note',
      content: 'Line 1\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Dialog should NEVER have appeared
    expect(find.byType(ImageCompressionDialog), findsNothing);

    // Attachment markdown was inserted directly
    expect(find.textContaining('qp://asset/'), findsOneWidget);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Dropping small image <= 500 KB bypasses dialog and inserts directly', (tester) async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-note-4',
      title: 'Small Image Note',
      content: 'Small\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(smallImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Dialog should not appear for small image
    expect(find.byType(ImageCompressionDialog), findsNothing);

    // Attachment was inserted directly
    expect(find.textContaining('qp://asset/'), findsOneWidget);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Canceling compression dialog aborts image insertion', (tester) async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-note-5',
      title: 'Cancel Test Note',
      content: 'Original content\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ImageCompressionDialog), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog closed and NO attachment snippet was inserted
    expect(find.byType(ImageCompressionDialog), findsNothing);
    expect(find.textContaining('qp://asset/'), findsNothing);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Dropping image > 500 KB with choice "Keep Original" inserts without calling compressImage', (tester) async {
    final now = DateTime.now();
    final note = Note(
      id: 'test-note-6',
      title: 'Keep Original Note',
      content: 'Original note body\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ImageCompressionDialog), findsOneWidget);

    // Tap "Keep Original" card
    await tester.tap(find.text('Keep Original'));
    await tester.pumpAndSettle();

    // Confirm insert
    await tester.tap(find.text('Insert Image'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Dialog dismissed
    expect(find.byType(ImageCompressionDialog), findsNothing);

    // Verify compressImage was NOT called
    expect(compressionService.compressCallCount, 0);

    // Markdown snippet was inserted
    expect(find.textContaining('qp://asset/'), findsOneWidget);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('Dropping image > 500 KB when setting is keepOriginal bypasses dialog and inserts without compressing', (tester) async {
    prefs.setString(DefaultSettingsNotifier.imageCompressionActionKey, 'keep_original');

    final now = DateTime.now();
    final note = Note(
      id: 'test-note-7',
      title: 'Default Keep Original Note',
      content: 'Hello World\n',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildEditorApp(note));
    await tester.pumpAndSettle();

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [DropItemFile(largeImageFile.path)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Dialog should not appear
    expect(find.byType(ImageCompressionDialog), findsNothing);

    // Verify compressImage was NOT called
    expect(compressionService.compressCallCount, 0);

    // Markdown snippet was inserted
    expect(find.textContaining('qp://asset/'), findsOneWidget);

    // Clean up timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });
}
