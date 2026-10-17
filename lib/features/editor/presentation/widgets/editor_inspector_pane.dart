import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/attachments/presentation/attachment_details_sheet.dart';
import '../../../../core/attachments/presentation/attachment_file_info_sheet.dart';
import '../active_inspector_provider.dart';
import 'version_history_sheet.dart';

/// Right-hand persistent/collapsible inspector pane docked beside the editor
/// on desktop widescreen displays (>= 1100dp).
class EditorInspectorPane extends ConsumerWidget {
  const EditorInspectorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final inspector = ref.watch(activeInspectorProvider);

    if (!inspector.isOpen) {
      return const SizedBox.shrink();
    }

    Widget content;
    switch (inspector.type) {
      case InspectorType.versionHistory:
        content = VersionHistorySheet(
          note: inspector.note!,
          currentTitle: inspector.currentTitle ?? '',
          currentContent: inspector.currentContent ?? '',
          currentTags: inspector.currentTags ?? const [],
          onRestoreVersion: inspector.onRestoreVersion ?? (_) async {},
          onClose: () => ref.read(activeInspectorProvider.notifier).close(),
        );
      case InspectorType.attachmentDetails:
        content = AttachmentDetailsSheet(
          attachmentId: inspector.attachmentId!,
          initialEntity: inspector.initialEntity,
          onRenamed: inspector.onRenamed,
          onDeleted: inspector.onDeleted,
          onClose: () => ref.read(activeInspectorProvider.notifier).close(),
        );
      case InspectorType.attachmentFileInfo:
        content = AttachmentFileInfoSheet(
          entity: inspector.fileInfoEntity!,
          decodedResult: inspector.decodedResult,
          format: inspector.format,
          onClose: () => ref.read(activeInspectorProvider.notifier).close(),
        );
      case InspectorType.none:
        content = const SizedBox.shrink();
    }

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(
            color: colors.divider.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: content,
    );
  }
}
