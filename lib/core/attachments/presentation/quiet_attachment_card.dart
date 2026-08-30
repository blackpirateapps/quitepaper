import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../database/app_database.dart';
import '../attachment_icon_resolver.dart';
import '../attachment_models.dart';
import '../attachment_open_service.dart';
import '../attachment_provider.dart';
import '../attachment_type_resolver.dart';
import '../attachment_capability_resolver.dart';
import 'attachment_details_sheet.dart';
import 'attachment_viewer_screen.dart';

/// Embedded interactive card widget for Quiet Paper generic file attachments (`qp://asset/<UUID>`).
///
/// Displays a file-type icon badge, filename, human-readable file type, formatted size,
/// E2EE badge, and provides direct tap to open with external applications or inspect details.
class QuietAttachmentCard extends ConsumerStatefulWidget {
  const QuietAttachmentCard({
    super.key,
    required this.attachmentId,
    required this.title,
    required this.uriString,
    this.initialEntity,
    this.onAttachmentRenamed,
    this.onAttachmentDeleted,
  });

  final String attachmentId;
  final String title;
  final String uriString;
  final AttachmentEntity? initialEntity;
  final void Function(String attachmentId, String newTitle)? onAttachmentRenamed;
  final void Function(String attachmentId)? onAttachmentDeleted;

  @override
  ConsumerState<QuietAttachmentCard> createState() => _QuietAttachmentCardState();
}

class _QuietAttachmentCardState extends ConsumerState<QuietAttachmentCard> {
  AttachmentEntity? _entity;

  @override
  void initState() {
    super.initState();
    _entity = widget.initialEntity;
    if (_entity == null) {
      _loadAttachment();
    }
  }

  @override
  void didUpdateWidget(QuietAttachmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) {
      _loadAttachment();
    }
  }

  Future<void> _loadAttachment() async {
    final service = ref.read(attachmentServiceProvider);
    final entity = await service.database.getAttachment(widget.attachmentId);

    if (mounted) {
      setState(() {
        _entity = entity;
      });
    }
  }

  Future<void> _handleCardTap() async {
    final fileName = _entity?.fileName ?? widget.title;
    final mimeType = _entity?.mimeType ?? AttachmentTypeResolver.inferMimeType(fileName);
    final canPreview = AttachmentCapabilityResolver.supports(
      capability: AttachmentCapability.preview,
      mimeType: mimeType,
      fileName: fileName,
      kind: _entity?.kind ?? AttachmentKind.file,
    );

    if (canPreview) {
      await AttachmentViewerScreen.open(
        context,
        attachmentId: widget.attachmentId,
        initialEntity: _entity,
      );
      return;
    }

    final openService = ref.read(attachmentOpenServiceProvider);
    final res = await openService.openAttachment(
      widget.attachmentId,
      fallbackFileName: _entity?.fileName ?? widget.title,
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

  void _showDetails() {
    AttachmentDetailsSheet.show(
      context,
      attachmentId: widget.attachmentId,
      initialEntity: _entity,
      onRenamed: (newName) {
        _loadAttachment();
        widget.onAttachmentRenamed?.call(widget.attachmentId, newName);
      },
      onDeleted: () {
        widget.onAttachmentDeleted?.call(widget.attachmentId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entity = _entity;
    final rawName = entity?.fileName ?? widget.title;
    final displayTitle = rawName.isNotEmpty ? rawName : 'Attachment';
    final mimeType = entity?.mimeType ?? AttachmentTypeResolver.inferMimeType(displayTitle);
    final typeLabel = AttachmentTypeResolver.resolveDisplayName(mimeType: mimeType, fileName: displayTitle);
    final byteSize = entity?.byteSize ?? 0;
    final sizeLabel = _formatBytes(byteSize);
    final icon = AttachmentIconResolver.resolveIcon(mimeType: mimeType, fileName: displayTitle, kind: entity?.kind);
    final iconTint = AttachmentIconResolver.resolveIconTint(mimeType: mimeType, fileName: displayTitle, colors: colors, kind: entity?.kind);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 0,
        child: InkWell(
          onTap: _handleCardTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: colors.divider,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. File Type Icon Tile
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconTint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: iconTint.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconTint,
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // 2. Title & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: displayTitle,
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$typeLabel • $sizeLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.sm / 2),
                        ),
                        child: Text(
                          'ENC (QPA1)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. More Action Button (Details Sheet)
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  tooltip: 'Attachment options',
                  onPressed: _showDetails,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
