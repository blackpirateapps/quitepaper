import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_icon_resolver.dart';
import '../../../../core/attachments/attachment_open_service.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/attachments/attachment_type_resolver.dart';
import '../../../../core/attachments/presentation/attachment_viewer_screen.dart';
import '../../../../core/attachments/presentation/image_viewer_modal.dart';
import '../../../../core/attachments/text/attachment_text_detector.dart';
import '../../../../core/documents/document_provider.dart';
import '../../../../core/documents/presentation/document_viewer_screen.dart';
import '../../../../core/storage/storage_asset_models.dart';
import '../../../../core/storage/storage_management_service.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../../../core/widgets/quiet_icon_button.dart';

/// Modal detailing a merged Storage & Assets item, with explicit preview/open,
/// export, and permanent-deletion actions.
class StorageAssetDetailsSheet extends ConsumerStatefulWidget {
  const StorageAssetDetailsSheet({
    super.key,
    required this.item,
  });

  final StorageAssetItem item;

  static Future<void> show(
    BuildContext context, {
    required StorageAssetItem item,
  }) {
    return QuietAdaptiveModal.show(
      context: context,
      type: AdaptiveModalType.dialog,
      showCloseButton: false,
      maxWidth: 480,
      builder: (_) => StorageAssetDetailsSheet(item: item),
    );
  }

  @override
  ConsumerState<StorageAssetDetailsSheet> createState() =>
      _StorageAssetDetailsSheetState();
}

class _StorageAssetDetailsSheetState
    extends ConsumerState<StorageAssetDetailsSheet> {
  late StorageAssetItem _item;
  bool _isBusy = false;
  String? _busyLabel;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _refreshItem() async {
    final local = await ref
        .read(storageManagementServiceProvider)
        .getLocalStorageAssets();
    final match = local.all
        .where((entry) => entry.id == _item.id && entry.type == _item.type)
        .firstOrNull;
    if (match != null && mounted) {
      setState(() {
        _item = match.copyWith(isOrphaned: _item.isOrphaned);
      });
    }
  }

  void _invalidateAssets() {
    ref.invalidate(localStorageAssetsProvider);
    ref.invalidate(cloudStorageResourcesProvider);
    ref.invalidate(storageProfileProvider);
  }

  void _closeSheet() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  TextAttachmentFormat get _textFormat => AttachmentTextDetector.detectFormat(
        fileName: _item.fileName,
        bytes: Uint8List(0),
        mimeType: _item.mimeType,
      );

  bool get _isImage =>
      _item.isAttachment &&
      (_item.kind == 'image' ||
          AttachmentTypeResolver.isImageMime(_item.mimeType));

  bool get _isText =>
      _item.isAttachment &&
      !_isImage &&
      !AttachmentTypeResolver.isPdfMime(_item.mimeType) &&
      AttachmentTextDetector.isTextFormat(_textFormat);

  bool get _hasInAppPreview => _item.isDocument || _isImage || _isText;

  Future<void> _handlePreview() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_item.isDocument) {
      _closeSheet();
      await DocumentViewerScreen.open(
        navigator.context,
        documentId: _item.id,
        title: _item.title,
      );
      return;
    }

    if (_isImage) {
      _closeSheet();
      await ImageViewerModal.open(
        navigator.context,
        assetId: _item.id,
        altText: _item.title,
      );
      return;
    }

    if (_isText) {
      _closeSheet();
      await AttachmentViewerScreen.open(
        navigator.context,
        attachmentId: _item.id,
        initialEntity: _item.attachmentEntity,
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('No in-app preview available. Use Open With… instead.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDownloadToDevice() async {
    setState(() {
      _isBusy = true;
      _busyLabel = 'Downloading encrypted asset…';
    });

    try {
      bool available = false;
      if (_item.isDocument) {
        final resolution =
            await ref.read(documentServiceProvider).resolveDocument(_item.id);
        available = resolution.isAvailable;
      } else {
        final resolution = await ref
            .read(attachmentServiceProvider)
            .resolveAsset(_item.id);
        available = resolution.isAvailable;
      }

      if (!available) {
        throw StateError('Could not download asset from cloud.');
      }

      await _refreshItem();
      _invalidateAssets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded to this device'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<Uint8List?> _resolveBytesForExport() async {
    if (_item.isDocument) {
      final resolution =
          await ref.read(documentServiceProvider).resolveDocument(_item.id);
      return resolution.data?.pdfBytes;
    }
    final resolution =
        await ref.read(attachmentServiceProvider).resolveAsset(_item.id);
    return resolution.data;
  }

  Future<void> _handleSaveToStorage() async {
    setState(() {
      _isBusy = true;
      _busyLabel = 'Preparing file…';
    });

    try {
      final bytes = await _resolveBytesForExport();
      if (bytes == null) {
        throw StateError('Asset bytes unavailable.');
      }

      var rawName = _item.fileName;
      if (_item.isDocument && !rawName.toLowerCase().endsWith('.pdf')) {
        rawName = '$rawName.pdf';
      }
      final sanitizedName = AttachmentTypeResolver.sanitizeFileName(rawName);
      final ext = AttachmentTypeResolver.inferExtension(sanitizedName);

      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Asset',
          fileName: sanitizedName,
          type: ext.isNotEmpty ? FileType.custom : FileType.any,
          allowedExtensions: ext.isNotEmpty ? [ext] : null,
          bytes: bytes,
        );
      } catch (error) {
        debugPrint('FilePicker saveFile fallback: $error');
      }

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final file = File(selectedPath);
        if (!await file.exists() || (await file.length()) == 0) {
          await file.writeAsBytes(bytes, flush: true);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${p.basename(selectedPath)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();
      final targetFile = File(p.join(targetDir.path, sanitizedName));
      await targetFile.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${targetFile.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _handleOpenExternally() async {
    final service = ref.read(attachmentOpenServiceProvider);
    final result = await service.openAttachment(
      _item.id,
      fallbackFileName: _item.fileName,
    );
    if (result.status != AttachmentOpenStatus.opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not open file'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    final service = ref.read(attachmentShareServiceProvider);
    final success = await service.shareAttachment(
      _item.id,
      fallbackFileName: _item.fileName,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share asset'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRename() async {
    final colors = context.appColors;
    final controller = TextEditingController(text: _item.fileName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
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
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogCtx).pop(value);
              }
            },
            child: Text(
              'Rename',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName == null ||
        newName.isEmpty ||
        newName == _item.fileName ||
        !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
      _busyLabel = 'Renaming…';
    });
    try {
      await ref
          .read(attachmentServiceProvider)
          .renameAttachment(_item.id, newName);
      if (mounted) {
        setState(() {
          _item = _item.copyWith(title: newName, fileName: newName);
        });
      }
      _invalidateAssets();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rename failed: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final colors = context.appColors;
    final location = _locationLabel;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(
          'Delete Orphaned Asset',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          _item.existsLocally && _item.existsInCloud
              ? 'Permanently delete this asset from cloud and local storage ($location)? This action cannot be undone.'
              : _item.existsLocally
                  ? 'Permanently delete this asset from this device? This action cannot be undone.'
                  : 'Permanently delete this asset from cloud storage? This action cannot be undone.',
          style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final service = ref.read(storageManagementServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isBusy = true;
      _busyLabel = 'Deleting…';
    });

    try {
      await service.deleteOrphanedAsset(_item);
      _invalidateAssets();
      if (mounted) {
        _closeSheet();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Asset permanently deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      if (_item.existsLocally && _item.existsInCloud) {
        final deviceOnly = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            title: Text(
              'Cloud Unavailable',
              style: AppTypography.headline.copyWith(color: colors.error),
            ),
            content: Text(
              'The asset could not be deleted from the cloud ($error).\n\n'
              'Remove it from this device only? The encrypted cloud copy will '
              'remain orphaned and can be cleaned up later.',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(
                  'Remove from device',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        if (deviceOnly == true) {
          try {
            await service.deleteOrphanedAsset(_item, removeFromDeviceOnly: true);
            _invalidateAssets();
            if (mounted) {
              _closeSheet();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Removed from this device'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (localError) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to delete asset: $localError'),
                  backgroundColor: colors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete asset: $error'),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyLabel = null;
        });
      }
    }
  }

  String get _locationLabel {
    if (_item.existsLocally && _item.existsInCloud) {
      return 'On device + cloud';
    }
    if (_item.existsLocally) return 'On device only';
    return 'Cloud only';
  }

  String get _typeLabel {
    if (_item.isDocument) return 'PDF Document';
    return AttachmentTypeResolver.resolveDisplayName(
      mimeType: _item.mimeType,
      fileName: _item.fileName,
    );
  }

  IconData get _icon {
    if (_item.isDocument) return Icons.picture_as_pdf_rounded;
    return AttachmentIconResolver.resolveIcon(
      mimeType: _item.mimeType,
      fileName: _item.fileName,
      kind: _item.kind,
    );
  }

  Color _iconTint(AppColors colors) {
    if (_item.isDocument) return const Color(0xFFD9534F);
    return AttachmentIconResolver.resolveIconTint(
      mimeType: _item.mimeType,
      fileName: _item.fileName,
      colors: colors,
      kind: _item.kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = PlatformLayoutHelper.isDesktop(context);

    final iconTint = _iconTint(colors);
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final sha256 = _item.attachmentEntity?.sha256 ??
        _item.documentEntity?.sha256 ??
        '';
    final shaPrefix = sha256.isNotEmpty
        ? (sha256.length > 16 ? '${sha256.substring(0, 16)}…' : sha256)
        : 'Not available';
    final canExternalOpen = _item.isAttachment;
    final canShare = _item.isAttachment;

    final content = SafeArea(
      top: false,
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
              if (!isDesktop) const AdaptiveSheetDragHandle(),

              // Header
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
                    child: Icon(_icon, color: iconTint, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            Text(
                              '$_typeLabel • ${_formatBytes(_item.byteSize)}',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            _StorageStatusBadge(state: _item.syncState),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop)
                    QuietIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: _closeSheet,
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.sm),

              _MetadataRow(label: 'Location', value: _locationLabel),
              _MetadataRow(label: 'Type', value: _typeLabel),
              _MetadataRow(
                label: 'Added',
                value: dateFormat.format(_item.createdAt.toLocal()),
              ),
              _MetadataRow(
                label: 'Updated',
                value: dateFormat.format(_item.updatedAt.toLocal()),
              ),
              if (_item.parentNoteTitle != null &&
                  _item.parentNoteTitle!.trim().isNotEmpty)
                _MetadataRow(
                  label: 'Parent note',
                  value: _item.parentNoteTitle!,
                ),
              if (_item.isOrphaned)
                _MetadataRow(
                  label: 'Orphan status',
                  value: _item.isEligibleForDeletion
                      ? 'Eligible for destruction'
                      : 'In 14-day safety grace period',
                ),
              _MetadataRow(label: 'SHA-256', value: shaPrefix),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.xs),

              if (_hasInAppPreview)
                _ActionTile(
                  icon: Icons.visibility_outlined,
                  label: _item.isDocument ? 'Preview document' : 'Preview',
                  onTap: _isBusy ? null : _handlePreview,
                ),
              if (_item.isAttachment && !_hasInAppPreview)
                _ActionTile(
                  icon: Icons.open_in_new_rounded,
                  label: 'Open with external app',
                  onTap: _isBusy ? null : _handleOpenExternally,
                ),
              if (!_item.existsLocally)
                _ActionTile(
                  icon: Icons.cloud_download_outlined,
                  label: 'Download to device',
                  onTap: _isBusy ? null : _handleDownloadToDevice,
                ),
              if (canExternalOpen && _hasInAppPreview)
                _ActionTile(
                  icon: Icons.open_in_new_rounded,
                  label: 'Open with external app',
                  onTap: _isBusy ? null : _handleOpenExternally,
                ),
              if (canShare)
                _ActionTile(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: _isBusy ? null : _handleShare,
                ),
              _ActionTile(
                icon: Icons.download_rounded,
                label: 'Save to storage',
                onTap: _isBusy ? null : _handleSaveToStorage,
              ),
              if (_item.isAttachment && _item.existsLocally)
                _ActionTile(
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Rename',
                  onTap: _isBusy ? null : _handleRename,
                ),
              if (_item.isOrphaned)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete permanently',
                  color: colors.error,
                  onTap: _isBusy ? null : _handleDelete,
                ),

              if (_isBusy) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _busyLabel ?? 'Working…',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );

    if (!isDesktop) {
      return Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return content;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StorageStatusBadge extends StatelessWidget {
  const _StorageStatusBadge({required this.state});

  final StorageAssetSyncState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final Color color;
    switch (state) {
      case StorageAssetSyncState.synced:
        color = colors.success;
        break;
      case StorageAssetSyncState.localOnly:
        color = colors.textTertiary;
        break;
      case StorageAssetSyncState.cloudOnly:
        color = colors.info;
        break;
      case StorageAssetSyncState.pending:
        color = colors.warning;
        break;
      case StorageAssetSyncState.failed:
        color = colors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        state.label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 4.5),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveColor = color ?? colors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(icon, color: effectiveColor, size: 20),
      title: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(color: effectiveColor),
      ),
      onTap: onTap,
    );
  }
}
