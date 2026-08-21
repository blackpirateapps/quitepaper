import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../../features/notes/application/notes_provider.dart';
import '../../ocr/ocr_provider.dart';
import '../../sync/sync_provider.dart';
import '../../uri/resource_resolver.dart';
import '../attachment_provider.dart';
import 'image_viewer_modal.dart';

/// Editorial image widget displaying an encrypted Quiet Paper asset (`qp://asset/<UUID>`)
/// resolved asynchronously from local encrypted storage or Cloudinary.
class QuietAssetImageView extends ConsumerStatefulWidget {
  const QuietAssetImageView({
    super.key,
    required this.assetId,
    this.altText,
    this.title,
    this.variant = 'original',
    this.fit = BoxFit.contain,
    this.maxHeight,
    this.onInsertText,
  });

  final String assetId;
  final String? altText;
  final String? title;
  final String variant;
  final BoxFit fit;
  final double? maxHeight;
  final void Function(String text)? onInsertText;

  @override
  ConsumerState<QuietAssetImageView> createState() => _QuietAssetImageViewState();
}

class _QuietAssetImageViewState extends ConsumerState<QuietAssetImageView> {
  ResourceResolution<Uint8List>? _resolution;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(QuietAssetImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId || oldWidget.variant != widget.variant) {
      _loadAsset();
    }
  }

  Future<void> _loadAsset() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final service = ref.read(attachmentServiceProvider);
    final result = await service.resolveAsset(widget.assetId, variant: widget.variant);

    if (mounted) {
      setState(() {
        _resolution = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoading) {
      return _buildPlaceholder(
        colors: colors,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14.0,
              height: 14.0,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              widget.altText?.isNotEmpty == true ? widget.altText! : 'Loading image...',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final res = _resolution;
    if (res == null || !res.isAvailable || res.data == null) {
      String message = 'Image unavailable';
      IconData icon = Icons.broken_image_outlined;

      if (res?.isLocked == true) {
        message = 'Encrypted image locked';
        icon = Icons.lock_outline_rounded;
      } else if (res?.isCorrupted == true) {
        message = 'Image decryption failed';
        icon = Icons.error_outline_rounded;
      } else if (res?.isMissing == true) {
        message = 'Image not found';
        icon = Icons.image_not_supported_outlined;
      }

      return _buildPlaceholder(
        colors: colors,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.0, color: colors.textTertiary),
            const SizedBox(width: 8.0),
            Flexible(
              child: Text(
                widget.altText?.isNotEmpty == true
                    ? '${widget.altText} ($message)'
                    : message,
                style: AppTypography.caption.copyWith(color: colors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Successfully decrypted image bytes
    final imageWidget = ClipRRect(
      borderRadius: AppRadii.borderMd,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.6),
            width: 0.8,
          ),
          borderRadius: AppRadii.borderMd,
        ),
        child: GestureDetector(
          onTap: () {
            ImageViewerModal.open(
              context,
              assetId: widget.assetId,
              altText: widget.altText,
              initialImageBytes: res.data,
              onInsertText: widget.onInsertText,
            );
          },
          onLongPress: () {
            _showContextMenu(context, res.data!);
          },
          child: Image.memory(
            res.data!,
            fit: widget.fit,
            semanticLabel: widget.altText,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxHeight ?? 480.0,
            ),
            child: imageWidget,
          ),
          if (widget.altText != null &&
              widget.altText!.trim().isNotEmpty &&
              widget.altText!.trim().toLowerCase() != 'image') ...[
            const SizedBox(height: 4.0),
            Text(
              widget.altText!.trim(),
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Uint8List imageBytes) {
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.fullscreen_rounded, color: colors.accent),
                  title: const Text('View Full Image'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    ImageViewerModal.open(
                      context,
                      assetId: widget.assetId,
                      altText: widget.altText,
                      initialImageBytes: imageBytes,
                      onInsertText: widget.onInsertText,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: colors.textPrimary),
                  title: const Text('Copy Extracted Text'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _copyExtractedText();
                  },
                ),
                if (widget.onInsertText != null)
                  ListTile(
                    leading: Icon(Icons.post_add_rounded, color: colors.textPrimary),
                    title: const Text('Insert Text into Note'),
                    onTap: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await _insertExtractedText();
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.download_rounded, color: colors.textPrimary),
                  title: const Text('Save Image to Device'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _saveImageToDevice(imageBytes);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyExtractedText() async {
    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(widget.assetId);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final encryptedBytes = base64Decode(ocrPages.first.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: widget.assetId,
        );

        final text = doc.fullPlainText.trim();
        if (text.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: text));
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${text.length} characters to clipboard'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recognized text found in image'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy text: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _insertExtractedText() async {
    if (widget.onInsertText == null) return;
    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(widget.assetId);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final encryptedBytes = base64Decode(ocrPages.first.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: widget.assetId,
        );

        final text = doc.fullPlainText.trim();
        if (text.isNotEmpty) {
          widget.onInsertText!(text);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recognized text available to insert'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to insert text: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveImageToDevice(Uint8List imageBytes) async {
    try {
      final fileName = 'quietpaper_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image',
        fileName: fileName,
        type: FileType.image,
        bytes: imageBytes,
      );

      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPlaceholder({required AppColors colors, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
