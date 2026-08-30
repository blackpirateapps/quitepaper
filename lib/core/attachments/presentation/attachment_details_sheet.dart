import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../database/app_database.dart';
import '../attachment_capability_resolver.dart';
import '../attachment_icon_resolver.dart';
import '../attachment_models.dart';
import '../attachment_open_service.dart';
import '../attachment_provider.dart';
import '../attachment_type_resolver.dart';
import 'attachment_viewer_screen.dart';

/// Modal bottom sheet displaying detailed metadata and actions for an attachment.
class AttachmentDetailsSheet extends ConsumerStatefulWidget {
  const AttachmentDetailsSheet({
    super.key,
    required this.attachmentId,
    required this.initialEntity,
    this.onRenamed,
    this.onDeleted,
  });

  final String attachmentId;
  final AttachmentEntity? initialEntity;
  final void Function(String newName)? onRenamed;
  final VoidCallback? onDeleted;

  static Future<void> show(
    BuildContext context, {
    required String attachmentId,
    AttachmentEntity? initialEntity,
    void Function(String newName)? onRenamed,
    VoidCallback? onDeleted,
  }) {
    final colors = context.appColors;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) => AttachmentDetailsSheet(
        attachmentId: attachmentId,
        initialEntity: initialEntity,
        onRenamed: onRenamed,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  ConsumerState<AttachmentDetailsSheet> createState() => _AttachmentDetailsSheetState();
}

class _AttachmentDetailsSheetState extends ConsumerState<AttachmentDetailsSheet> {
  AttachmentEntity? _entity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _entity = widget.initialEntity;
    _refreshEntity();
  }

  Future<void> _refreshEntity() async {
    final service = ref.read(attachmentServiceProvider);
    final fresh = await service.database.getAttachment(widget.attachmentId);
    if (fresh != null && mounted) {
      setState(() => _entity = fresh);
    }
  }

  Future<void> _handlePreview() async {
    Navigator.of(context).pop();
    await AttachmentViewerScreen.open(
      context,
      attachmentId: widget.attachmentId,
      initialEntity: _entity,
    );
  }

  Future<void> _handleOpen() async {
    Navigator.of(context).pop();
    final openService = ref.read(attachmentOpenServiceProvider);
    final res = await openService.openAttachment(
      widget.attachmentId,
      fallbackFileName: _entity?.fileName,
    );
    if (res.status != AttachmentOpenStatus.opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Could not open file'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    Navigator.of(context).pop();
    final shareService = ref.read(attachmentShareServiceProvider);
    final success = await shareService.shareAttachment(
      widget.attachmentId,
      fallbackFileName: _entity?.fileName,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share attachment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSaveAs() async {
    final service = ref.read(attachmentServiceProvider);
    final resolution = await service.resolveAsset(widget.attachmentId);
    if (!resolution.isAvailable || resolution.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolution.errorMessage ?? 'Attachment bytes unavailable'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final rawName = _entity?.fileName ?? 'attachment_${widget.attachmentId}';
    final sanitizedName = AttachmentTypeResolver.sanitizeFileName(rawName);
    final ext = AttachmentTypeResolver.inferExtension(sanitizedName);

    try {
      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Attachment',
          fileName: sanitizedName,
          type: ext.isNotEmpty ? FileType.custom : FileType.any,
          allowedExtensions: ext.isNotEmpty ? [ext] : null,
          bytes: resolution.data!,
        );
      } catch (e) {
        debugPrint('FilePicker saveFile fallback: $e');
      }

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final f = File(selectedPath);
        if (!await f.exists() || (await f.length()) == 0) {
          await f.writeAsBytes(resolution.data!, flush: true);
        }
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${p.basename(selectedPath)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Fallback: Downloads folder
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetFile = File(p.join(targetDir.path, sanitizedName));
      await targetFile.writeAsBytes(resolution.data!, flush: true);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${targetFile.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRename() async {
    final colors = context.appColors;
    final currentName = _entity?.fileName ?? 'attachment';
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(
          'Rename Attachment',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new filename',
            hintStyle: TextStyle(color: colors.textTertiary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(dialogCtx).pop(val);
              }
            },
            child: Text('Rename', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      setState(() => _isLoading = true);
      final service = ref.read(attachmentServiceProvider);
      await service.renameAttachment(widget.attachmentId, newName);
      await _refreshEntity();
      widget.onRenamed?.call(newName);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleDelete() async {
    final colors = context.appColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(
          'Delete Attachment',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove this attachment from the note?',
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = ref.read(attachmentServiceProvider);
      await service.deleteAttachment(widget.attachmentId);
      widget.onDeleted?.call();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entity = _entity;
    final fileName = entity?.fileName ?? 'attachment';
    final mimeType = entity?.mimeType ?? 'application/octet-stream';
    final typeLabel = AttachmentTypeResolver.resolveDisplayName(mimeType: mimeType, fileName: fileName);
    final byteSize = entity?.byteSize ?? 0;
    final sizeLabel = _formatBytes(byteSize);
    final icon = AttachmentIconResolver.resolveIcon(mimeType: mimeType, fileName: fileName, kind: entity?.kind);
    final iconTint = AttachmentIconResolver.resolveIconTint(mimeType: mimeType, fileName: fileName, colors: colors, kind: entity?.kind);

    final createdAtStr = entity != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(entity.createdAt.toLocal())
        : 'Unknown';

    final shaPrefix = entity?.sha256.isNotEmpty == true
        ? '${entity!.sha256.substring(0, 12)}…'
        : 'Not computed';

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with file icon and filename
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconTint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconTint, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: AppTypography.headline.copyWith(color: colors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$typeLabel • $sizeLabel',
                          style: AppTypography.caption.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.sm),

              // 2. Metadata Section
              _MetadataRow(label: 'Type', value: typeLabel),
              _MetadataRow(label: 'Size', value: sizeLabel),
              _MetadataRow(label: 'Added', value: createdAtStr),
              _MetadataRow(label: 'SHA-256', value: shaPrefix),
              _MetadataRow(
                label: 'Status',
                value: entity?.uploadState == 'synced'
                    ? 'Synced (Encrypted)'
                    : (entity?.uploadState == 'uploading' ? 'Uploading…' : 'Local Only'),
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.xs),

              // 3. Actions List
              if (AttachmentCapabilityResolver.supports(
                capability: AttachmentCapability.preview,
                mimeType: mimeType,
                fileName: fileName,
                kind: entity?.kind ?? AttachmentKind.file,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_outlined, color: colors.textPrimary, size: 20),
                  title: Text('Preview attachment', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                  onTap: _isLoading ? null : _handlePreview,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.open_in_new_rounded, color: colors.textPrimary, size: 20),
                title: Text('Open with external app', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                onTap: _isLoading ? null : _handleOpen,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.share_outlined, color: colors.textPrimary, size: 20),
                title: Text('Share attachment', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                onTap: _isLoading ? null : _handleShare,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_rounded, color: colors.textPrimary, size: 20),
                title: Text('Save to storage', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                onTap: _isLoading ? null : _handleSaveAs,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.drive_file_rename_outline_rounded, color: colors.textPrimary, size: 20),
                title: Text('Rename', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                onTap: _isLoading ? null : _handleRename,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                title: Text('Remove from note', style: AppTypography.bodyMedium.copyWith(color: Colors.redAccent)),
                onTap: _isLoading ? null : _handleDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
