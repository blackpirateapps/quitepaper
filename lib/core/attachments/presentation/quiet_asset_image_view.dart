import 'dart:convert';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../../features/notes/application/notes_provider.dart';
import '../../ocr/ocr_provider.dart';
import '../../sync/sync_provider.dart';
import '../../widgets/quiet_adaptive_modal.dart';
import '../attachment_provider.dart';
import '../../uri/quiet_paper_uri.dart';
import 'image_dimension_reader.dart';
import 'image_file_save.dart';
import 'image_layout_calculator.dart';
import 'image_viewer_modal.dart';
import 'viewer_image_item.dart';

/// Editorial image widget displaying an inline document image (`qp://asset/<UUID>` or direct URL).
///
/// Implements automatic responsive sizing (preserving aspect ratio, constraining tall images,
/// avoiding upscaling small images), horizontal centering, subtle corner rounding, captions,
/// accessibility semantics, calm error states with retry, and full-screen viewer entry.
class QuietAssetImageView extends ConsumerStatefulWidget {
  const QuietAssetImageView({
    super.key,
    this.assetId,
    this.url,
    this.altText,
    this.title,
    this.caption,
    this.noteId,
    this.variant = 'original',
    this.fit = BoxFit.contain,
    this.maxHeight,
    this.onInsertText,
    this.onAttachmentReplaced,
    this.galleryImages,
    this.imageIndex,
  }) : assert(assetId != null || url != null, 'Either assetId or url must be provided');

  final String? assetId;
  final String? url;
  final String? altText;
  final String? title;
  final String? caption;
  final String? noteId;
  final String variant;
  final BoxFit fit;
  final double? maxHeight;
  final void Function(String text)? onInsertText;
  final void Function(String oldAssetId, String newAssetId)? onAttachmentReplaced;
  final List<ViewerImageItem>? galleryImages;
  final int? imageIndex;

  @override
  ConsumerState<QuietAssetImageView> createState() => _QuietAssetImageViewState();
}

class _QuietAssetImageViewState extends ConsumerState<QuietAssetImageView>
    with AutomaticKeepAliveClientMixin {

  int _loadGeneration = 0;
  Uint8List? _imageBytes;
  Size? _intrinsicSize;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = 'Image unavailable';
  IconData _errorIcon = Icons.broken_image_outlined;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(QuietAssetImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.url != widget.url ||
        oldWidget.variant != widget.variant) {
      _loadImage();
    }
  }

  bool _isCurrentLoad(int generation) => mounted && generation == _loadGeneration;

  Future<void> _loadImage() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final assetId = widget.assetId;
    final url = widget.url;
    final variant = widget.variant;
    setState(() {
      _imageBytes = null;
      _intrinsicSize = null;
      _isLoading = true;
      _hasError = false;
    });

    try {
      Uint8List bytes;
      final effectiveAssetId = assetId?.isNotEmpty == true
          ? assetId! : QuietPaperUri.tryParse(url ?? '')?.resourceId;
      if (effectiveAssetId != null && effectiveAssetId.isNotEmpty) {
        final service = ref.read(attachmentServiceProvider);
        final result = await service.resolveAsset(effectiveAssetId, variant: variant);
        if (!_isCurrentLoad(generation)) return;
        if (!result.isAvailable || result.data == null) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = result.isLocked ? 'Encrypted image locked'
                : result.isCorrupted ? 'Image decryption failed'
                : result.isMissing ? 'Image not found' : 'Image unavailable';
            _errorIcon = result.isLocked ? Icons.lock_outline_rounded
                : result.isCorrupted ? Icons.error_outline_rounded
                : result.isMissing ? Icons.image_not_supported_outlined
                : Icons.broken_image_outlined;
          });
          return;
        }
        bytes = result.data!;
      } else if (url != null && url.startsWith('data:')) {
        final commaIdx = url.indexOf(',');
        if (commaIdx < 0) throw const FormatException('Invalid data URL');
        bytes = base64Decode(url.substring(commaIdx + 1).trim());
      } else {
        final rawUrl = url?.trim() ?? '';
        var uri = Uri.tryParse(rawUrl);
        if (uri == null || !uri.hasScheme) {
          uri = Uri.tryParse(Uri.encodeFull(rawUrl));
        }
        if (uri == null || !uri.hasScheme) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Invalid image URL';
            _errorIcon = Icons.link_off_rounded;
          });
          return;
        }
        final response = await http.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            if (uri.hasAuthority) 'Referer': '${uri.scheme}://${uri.authority}/',
            'Sec-Fetch-Dest': 'image',
            'Sec-Fetch-Mode': 'no-cors',
            'Sec-Fetch-Site': 'cross-site',
          },
        );
        if (!_isCurrentLoad(generation)) return;
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Failed to load image (${response.statusCode})';
            _errorIcon = Icons.cloud_off_outlined;
          });
          return;
        }
        bytes = response.bodyBytes;
      }
      if (!_isCurrentLoad(generation)) return;
      setState(() {
        _imageBytes = bytes;
        _intrinsicSize = ImageDimensionReader.extractDimensions(bytes);
        _isLoading = false;
        _hasError = false;
      });
      if (_intrinsicSize == null) _decodeIntrinsicSize(bytes, generation);
    } catch (_) {
      if (!_isCurrentLoad(generation)) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Unable to load image';
        _errorIcon = Icons.broken_image_outlined;
      });
    }
  }

  Future<void> _decodeIntrinsicSize(Uint8List bytes, int generation) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          if (!_isCurrentLoad(generation)) return;
          setState(() => _intrinsicSize = Size(
            frame.image.width.toDouble(), frame.image.height.toDouble()));
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // The layout calculator handles unknown dimensions.
    }
  }

  void _openFullscreenViewer() {
    final images = widget.galleryImages ?? [
      ViewerImageItem(
        assetId: widget.assetId,
        url: widget.url,
        altText: widget.altText,
        title: widget.title,
        caption: widget.caption,
        initialBytes: _imageBytes,
      ),
    ];

    final index = widget.imageIndex ??
        images.indexWhere((img) =>
            (widget.assetId != null && img.assetId == widget.assetId) ||
            (widget.url != null && img.url == widget.url));

    ImageViewerModal.openGallery(
      context,
      images: images,
      initialIndex: index >= 0 ? index : 0,
      noteId: widget.noteId,
      onInsertText: widget.onInsertText,
      onImageReplaced: widget.onAttachmentReplaced,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.appColors;

    final effectiveAlt = widget.altText?.trim().isNotEmpty == true &&
            widget.altText!.trim().toLowerCase() != 'image'
        ? widget.altText!.trim()
        : 'Image';

    final effectiveCaption = widget.caption?.trim().isNotEmpty == true
        ? widget.caption!.trim()
        : (widget.title?.trim().isNotEmpty == true
            ? widget.title!.trim()
            : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final maxAllowedHeight = widget.maxHeight ?? ImageLayoutCalculator.defaultMaxAllowedHeight;

          // 1. Loading State (Neutral paper placeholder, no blur-up)
          if (_isLoading) {
            final placeholderSize = ImageLayoutCalculator.calculateSize(
              intrinsicWidth: _intrinsicSize?.width,
              intrinsicHeight: _intrinsicSize?.height,
              availableContentWidth: availableWidth,
              maxAllowedHeight: maxAllowedHeight,
            );

            return Center(
              child: Container(
                width: placeholderSize.width,
                height: placeholderSize.height,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 16.0,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Loading image...',
                        style: AppTypography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // 2. Error Fallback with Retry
          if (_hasError || _imageBytes == null) {
            return Center(
              child: InkWell(
                onTap: _loadImage,
                borderRadius: AppRadii.borderMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_errorIcon, size: 16.0, color: colors.textTertiary),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          '$_errorMessage • Tap to retry',
                          style: AppTypography.caption.copyWith(color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // 3. Successfully Resolved Image
          final displaySize = ImageLayoutCalculator.calculateSize(
            intrinsicWidth: _intrinsicSize?.width,
            intrinsicHeight: _intrinsicSize?.height,
            availableContentWidth: availableWidth,
            maxAllowedHeight: maxAllowedHeight,
          );

          final imageWidget = Semantics(
            label: '$effectiveAlt, image. Double tap to open.',
            button: true,
            child: GestureDetector(
              onTap: _openFullscreenViewer,
              onLongPress: () => _showContextMenu(context, _imageBytes!),
              onSecondaryTap: () => _showContextMenu(context, _imageBytes!),
              child: SizedBox(
                width: displaySize.width,
                height: displaySize.height,
                child: ClipRRect(
                  borderRadius: AppRadii.borderMd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _imageBytes!,
                        width: displaySize.width,
                        height: displaySize.height,
                        fit: widget.fit,
                        semanticLabel: effectiveAlt,
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadii.borderMd,
                            border: Border.all(
                              color: colors.divider.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.center,
                child: imageWidget,
              ),
              if (effectiveCaption != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    effectiveCaption,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, Uint8List imageBytes) {
    final colors = context.appColors;

    QuietAdaptiveModal.show<void>(
      context: context,
      type: AdaptiveModalType.popover,
      maxWidth: 280,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AdaptiveSheetDragHandle(),
                ListTile(
                  leading: Icon(Icons.fullscreen_rounded, color: colors.accent),
                  title: const Text('View Full Image'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _openFullscreenViewer();
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
                  leading: Icon(Icons.share_rounded, color: colors.textPrimary),
                  title: const Text('Share Image'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _shareImage(imageBytes);
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

  Future<void> _shareImage(Uint8List imageBytes) async {
    try {
      if (widget.assetId != null && widget.assetId!.isNotEmpty) {
        final shareService = ref.read(attachmentShareServiceProvider);
        final success = await shareService.shareAttachment(widget.assetId!);
        if (success) return;
      }

      // Fallback share via temporary file
      final fileName = 'quietpaper_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final shareService = ref.read(attachmentShareServiceProvider);
      final tempFile = await shareService.tempStorage.createTemporaryDecryptedFile(
        attachmentId: widget.assetId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        rawFileName: fileName,
        plaintextBytes: imageBytes,
      );

      await shareService.shareFileDirectly(tempFile.path, fileName: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copyExtractedText() async {
    if (widget.assetId == null || widget.assetId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recognized text found in image'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(widget.assetId!);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final encryptedBytes = base64Decode(ocrPages.first.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: widget.assetId!,
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
    if (widget.onInsertText == null || widget.assetId == null || widget.assetId!.isEmpty) return;
    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(widget.assetId!);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final encryptedBytes = base64Decode(ocrPages.first.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: widget.assetId!,
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

      if (outputPath == null || outputPath.trim().isEmpty) return;
      await writePickedImageFile(outputPath, imageBytes);
      if (mounted) {
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
}
