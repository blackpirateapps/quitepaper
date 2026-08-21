import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../attachments/attachment_provider.dart';
import '../documents/document_provider.dart';
import 'web_clipper_service.dart';

final webClipperServiceProvider = Provider<WebClipperService>((ref) {
  final notesRepository = ref.watch(notesRepositoryProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);
  final documentService = ref.watch(documentServiceProvider);

  return WebClipperService(
    notesRepository: notesRepository,
    attachmentService: attachmentService,
    documentService: documentService,
  );
});
