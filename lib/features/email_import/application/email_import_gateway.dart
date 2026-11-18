import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/note_links/note_link_search_service.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../domain/email_message.dart';
import 'email_import_service.dart';
import 'email_input.dart';
import 'email_parser.dart';

final emailImportServiceProvider = Provider<EmailImportService>(
  (ref) => EmailImportService(
    database: ref.watch(databaseProvider),
    repository: ref.watch(notesRepositoryProvider),
    attachments: ref.watch(attachmentServiceProvider),
  ),
);
final emailImportGatewayProvider = Provider<EmailImportGateway>(
  (ref) => EmailImportGateway(ref.watch(emailImportServiceProvider)),
);

/// Injectable application boundary shared by preview, picker, drops and shares.
class EmailImportGateway {
  EmailImportGateway(this.service);
  final EmailImportService service;
  bool get isUnlocked => service.attachments.keyManager.isUnlocked;
  Future<void> initialize() => service.recoverInterruptedImports();
  Future<EmailMessage> parse(EmailInput input) async =>
      const EmailParser().parse(await input.read());
  Future<List<({String noteId, bool exact})>> duplicates(EmailMessage email) =>
      service.database.findEmailDuplicates(
        rawHash: email.rawHash,
        fingerprint: email.fingerprint,
        messageId: email.messageId,
      );
  Future<Note?> note(String id) => service.repository.getNoteById(id);
  Future<List<NoteLinkSearchResultItem>> search(String query) =>
      NoteLinkSearchService(service.database).searchNotes(query: query);
  Future<Note> save({
    required EmailMessage email,
    required EmailImportMode mode,
    required String title,
    required List<String> tags,
    Note? destination,
    required bool allowDuplicate,
    required bool Function() isCancelled,
  }) => service.save(
    email: email,
    mode: mode,
    title: title,
    tags: tags,
    destination: destination,
    allowDuplicate: allowDuplicate,
    isCancelled: isCancelled,
  );
}

/// Mutable owner allows lock/logout to release shared plaintext as well as views.
class EmailImportRequest {
  EmailImportRequest({
    List<EmailInput> inputs = const [],
    this.sharedContent,
    this.currentNoteId,
  }) : inputs = List.of(inputs);
  final List<EmailInput> inputs;
  EmailMessage? sharedContent;
  String? currentNoteId;
  final committedNoteIds = <String>{};
  void clear() {
    sharedContent = null;
    inputs.clear();
  }
}
