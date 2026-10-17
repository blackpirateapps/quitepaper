import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/attachments/text/attachment_text_decoder.dart';
import '../../../core/attachments/text/attachment_text_detector.dart';
import '../../../core/database/app_database.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/domain/note_version_model.dart';

enum InspectorType {
  none,
  versionHistory,
  attachmentDetails,
  attachmentFileInfo,
}

class ActiveInspectorState {
  const ActiveInspectorState({
    this.type = InspectorType.none,
    this.note,
    this.currentTitle,
    this.currentContent,
    this.currentTags,
    this.onRestoreVersion,
    this.attachmentId,
    this.initialEntity,
    this.onRenamed,
    this.onDeleted,
    this.fileInfoEntity,
    this.decodedResult,
    this.format = TextAttachmentFormat.plainText,
  });

  final InspectorType type;

  // Version history fields
  final Note? note;
  final String? currentTitle;
  final String? currentContent;
  final List<String>? currentTags;
  final Future<void> Function(NoteVersion version)? onRestoreVersion;

  // Attachment details fields
  final String? attachmentId;
  final AttachmentEntity? initialEntity;
  final void Function(String newName)? onRenamed;
  final VoidCallback? onDeleted;

  // Attachment file info fields
  final AttachmentEntity? fileInfoEntity;
  final DecodedTextResult? decodedResult;
  final TextAttachmentFormat format;

  bool get isOpen => type != InspectorType.none;

  static const none = ActiveInspectorState();
}

class ActiveInspectorNotifier extends Notifier<ActiveInspectorState> {
  @override
  ActiveInspectorState build() => ActiveInspectorState.none;

  void openVersionHistory({
    required Note note,
    required String currentTitle,
    required String currentContent,
    required List<String> currentTags,
    required Future<void> Function(NoteVersion version) onRestoreVersion,
  }) {
    state = ActiveInspectorState(
      type: InspectorType.versionHistory,
      note: note,
      currentTitle: currentTitle,
      currentContent: currentContent,
      currentTags: currentTags,
      onRestoreVersion: onRestoreVersion,
    );
  }

  void openAttachmentDetails({
    required String attachmentId,
    AttachmentEntity? initialEntity,
    void Function(String newName)? onRenamed,
    VoidCallback? onDeleted,
  }) {
    state = ActiveInspectorState(
      type: InspectorType.attachmentDetails,
      attachmentId: attachmentId,
      initialEntity: initialEntity,
      onRenamed: onRenamed,
      onDeleted: onDeleted,
    );
  }

  void openAttachmentFileInfo({
    required AttachmentEntity entity,
    DecodedTextResult? decodedResult,
    TextAttachmentFormat format = TextAttachmentFormat.plainText,
  }) {
    state = ActiveInspectorState(
      type: InspectorType.attachmentFileInfo,
      fileInfoEntity: entity,
      decodedResult: decodedResult,
      format: format,
    );
  }

  void close() {
    if (state.isOpen) {
      state = ActiveInspectorState.none;
    }
  }

  void toggleVersionHistory({
    required Note note,
    required String currentTitle,
    required String currentContent,
    required List<String> currentTags,
    required Future<void> Function(NoteVersion version) onRestoreVersion,
  }) {
    if (state.type == InspectorType.versionHistory && state.note?.id == note.id) {
      close();
    } else {
      openVersionHistory(
        note: note,
        currentTitle: currentTitle,
        currentContent: currentContent,
        currentTags: currentTags,
        onRestoreVersion: onRestoreVersion,
      );
    }
  }
}

final activeInspectorProvider =
    NotifierProvider<ActiveInspectorNotifier, ActiveInspectorState>(
  ActiveInspectorNotifier.new,
);
