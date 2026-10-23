import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/attachments/presentation/attachment_viewer_screen.dart';
import 'package:quitepaper/core/attachments/presentation/plain_text_viewer.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';

class _StubKeyManager implements KeyManager {
  final Uint8List _masterKey = Uint8List(32);

  @override
  bool get isUnlocked => true;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List? get cachedMasterKey => _masterKey;

  @override
  Uint8List getMasterKey() => _masterKey;

  @override
  void lock() {}

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Simulates a cloud-only attachment: the initial local row is missing and
/// [resolveAsset] persists metadata only when the remote payload is fetched.
class _CloudOnlyAttachmentService extends AttachmentService {
  _CloudOnlyAttachmentService({
    required super.database,
    required super.keyManager,
    required this.bytes,
    required this.remoteFileName,
    required this.remoteMimeType,
  }) : super(storage: AttachmentLocalStorage());

  final Uint8List bytes;
  final String remoteFileName;
  final String remoteMimeType;

  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String assetId, {
    String variant = 'original',
  }) async {
    await database.saveAttachment(
      id: assetId,
      fileName: remoteFileName,
      kind: 'file',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: remoteMimeType,
      byteSize: bytes.length,
      uploadState: 'synced',
    );
    return ResourceResolution.available(QuietPaperUri.asset(assetId), bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Cloud-only text attachment re-detects filename and format after resolveAsset',
      (tester) async {
    const attachmentId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final rawBytes = Uint8List.fromList(utf8.encode('Cloud-only note text'));
    final service = _CloudOnlyAttachmentService(
      database: db,
      keyManager: _StubKeyManager(),
      bytes: rawBytes,
      remoteFileName: 'cloud-notes.txt',
      remoteMimeType: 'text/plain',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          attachmentServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AttachmentViewerScreen(attachmentId: attachmentId),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Metadata was absent before resolveAsset(); the viewer must refresh it.
    expect(find.text('cloud-notes.txt'), findsOneWidget);
    expect(find.text('Plain Text • ${rawBytes.length} B'), findsOneWidget);
    expect(find.byType(PlainTextViewer), findsOneWidget);
    expect(find.textContaining('Cloud-only note text'), findsOneWidget);
  });
}
