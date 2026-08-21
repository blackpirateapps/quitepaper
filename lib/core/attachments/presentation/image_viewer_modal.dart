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
import '../../database/app_database.dart';
import '../../ocr/ocr_models.dart';
import '../../ocr/ocr_provider.dart';
import '../../ocr/presentation/ocr_language_dialog.dart';
import '../../sync/sync_provider.dart';
import '../attachment_provider.dart';

/// Immersive editorial image viewer for encrypted Quiet Paper assets (`qp://asset/<UUID>`).
///
/// Supports high-resolution pinch-to-zoom (`InteractiveViewer`), double-tap zoom,
/// Live Text bounding box overlay, on-device OCR text selection, "Copy All Text",
/// "Insert Text into Note", image download/export, and manual OCR regeneration.
class ImageViewerModal extends ConsumerStatefulWidget {
  const ImageViewerModal({
    super.key,
    required this.assetId,
    this.altText,
    this.initialImageBytes,
    this.onInsertText,
  });

  final String assetId;
  final String? altText;
  final Uint8List? initialImageBytes;
  final void Function(String text)? onInsertText;

  static Future<void> open(
    BuildContext context, {
    required String assetId,
    String? altText,
    Uint8List? initialImageBytes,
    void Function(String text)? onInsertText,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ImageViewerModal(
          assetId: assetId,
          altText: altText,
          initialImageBytes: initialImageBytes,
          onInsertText: onInsertText,
        ),
      ),
    );
  }

  @override
  ConsumerState<ImageViewerModal> createState() => _ImageViewerModalState();
}

class _ImageViewerModalState extends ConsumerState<ImageViewerModal> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  Uint8List? _imageBytes;
  AttachmentEntity? _attachment;
  OcrDocument? _ocrDocument;
  bool _isLoading = true;
  bool _isOcrLoading = true;
  bool _showLiveText = true;
  OcrWord? _selectedWord;
  OcrLine? _selectedLine;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
    _loadImageAndOcr();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImageAndOcr() async {
    if (!mounted) return;
    setState(() => _isLoading = _imageBytes == null);

    final db = ref.read(databaseProvider);
    final att = await db.getAttachment(widget.assetId);
    if (mounted) {
      setState(() => _attachment = att);
    }

    // 1. Resolve image bytes if not passed initially
    if (_imageBytes == null) {
      final service = ref.read(attachmentServiceProvider);
      final res = await service.resolveAsset(widget.assetId);
      if (mounted && res.isAvailable && res.data != null) {
        setState(() {
          _imageBytes = res.data;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    // 2. Load and decrypt OCR dataset
    await _loadOcrDocument();
  }

  Future<void> _loadOcrDocument() async {
    if (!mounted) return;
    setState(() => _isOcrLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(widget.assetId);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final firstPage = ocrPages.first;

        final encryptedBytes = base64Decode(firstPage.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: widget.assetId,
        );

        if (mounted) {
          setState(() {
            _ocrDocument = doc;
            _isOcrLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[ImageViewerModal] Error loading OCR document: $e');
    }

    if (mounted) {
      setState(() => _isOcrLoading = false);
    }
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, 2.5)
        ..setEntry(1, 1, 2.5)
        ..setTranslationRaw(-position.dx * 1.5, -position.dy * 1.5, 0.0);
      _transformationController.value = matrix;
    }
  }

  Future<void> _copyAllText() async {
    final text = _ocrDocument?.fullPlainText ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recognized text found in image'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
  }

  void _handleInsertIntoNote() {
    final text = _ocrDocument?.fullPlainText ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recognized text available to insert'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.onInsertText != null) {
      widget.onInsertText!(text);
      Navigator.of(context).pop();
    } else {
      _copyAllText();
    }
  }

  Future<void> _handleSaveImage() async {
    if (_imageBytes == null) return;

    try {
      final mime = _attachment?.mimeType ?? 'image/png';
      final ext = mime.contains('jpeg') || mime.contains('jpg')
          ? 'jpg'
          : mime.contains('webp')
              ? 'webp'
              : 'png';
      final fileName = 'quietpaper_image_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image',
        fileName: fileName,
        type: FileType.image,
        bytes: _imageBytes,
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

  Future<void> _handleRetryOcr() async {
    if (_imageBytes == null) return;

    final service = ref.read(attachmentServiceProvider);
    final prefLang = ref.read(ocrLanguagePreferenceProvider);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Re-running image OCR...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() => _isOcrLoading = true);

    try {
      await service.regenerateOcr(widget.assetId, language: prefLang);
      await _loadOcrDocument();
      final db = ref.read(databaseProvider);
      final updatedAtt = await db.getAttachment(widget.assetId);
      if (mounted) {
        setState(() => _attachment = updatedAtt);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image OCR completed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOcrLoading = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = widget.altText?.isNotEmpty == true
        ? widget.altText!
        : 'Image';

    final hasOcr = _ocrDocument != null &&
        _ocrDocument!.pages.isNotEmpty &&
        _ocrDocument!.pages.first.plainText.trim().isNotEmpty;
    final isProcessing = _attachment?.ocrState == 'processing' ||
        _attachment?.ocrState == 'queued' ||
        _isOcrLoading;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            _buildOcrStatusBadge(colors, hasOcr, isProcessing),
          ],
        ),
        actions: [
          if (hasOcr)
            IconButton(
              icon: Icon(
                _showLiveText
                    ? Icons.text_fields_rounded
                    : Icons.text_fields_outlined,
                color: _showLiveText ? colors.accent : colors.textSecondary,
              ),
              tooltip: _showLiveText ? 'Hide Live Text' : 'Show Live Text',
              onPressed: () {
                setState(() {
                  _showLiveText = !_showLiveText;
                  _selectedWord = null;
                  _selectedLine = null;
                });
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
            color: colors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.borderMd,
            ),
            onSelected: (val) {
              switch (val) {
                case 'copy_text':
                  _copyAllText();
                  break;
                case 'insert_text':
                  _handleInsertIntoNote();
                  break;
                case 'retry_ocr':
                  _handleRetryOcr();
                  break;
                case 'ocr_language':
                  OcrLanguageDialog.show(context);
                  break;
                case 'save_image':
                  _handleSaveImage();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (hasOcr) ...[
                PopupMenuItem(
                  value: 'copy_text',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Copy All Text'),
                    ],
                  ),
                ),
                if (widget.onInsertText != null)
                  PopupMenuItem(
                    value: 'insert_text',
                    child: Row(
                      children: [
                        Icon(Icons.post_add_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Insert into Note'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'retry_ocr',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Re-run OCR'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ocr_language',
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('OCR Language'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'save_image',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Save Image'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildImageCanvas(colors, hasOcr),
            ),
            if (_selectedWord != null || _selectedLine != null)
              _buildSelectedTextCallout(colors)
            else if (hasOcr || _imageBytes != null)
              _buildBottomActionBar(colors, hasOcr),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrStatusBadge(
    AppColors colors,
    bool hasOcr,
    bool isProcessing,
  ) {
    if (isProcessing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Processing text…',
            style: AppTypography.caption.copyWith(
              color: colors.accent,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    if (hasOcr) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 11, color: colors.accent),
          const SizedBox(width: 3),
          Text(
            'Searchable (OCR)',
            style: AppTypography.caption.copyWith(
              color: colors.accent,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Text(
      'OCR unavailable',
      style: AppTypography.caption.copyWith(
        color: colors.textTertiary,
        fontSize: 11,
      ),
    );
  }

  Widget _buildImageCanvas(AppColors colors, bool hasOcr) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.accent),
      );
    }

    if (_imageBytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 48, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Image unavailable',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final page = hasOcr ? _ocrDocument!.pages.first : null;

    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                  ),
                  if (_showLiveText && page != null && page.blocks.isNotEmpty)
                    Positioned.fill(
                      child: _LiveTextOverlay(
                        page: page,
                        selectedWord: _selectedWord,
                        selectedLine: _selectedLine,
                        onWordTapped: (w) {
                          setState(() {
                            _selectedWord = w;
                            _selectedLine = null;
                          });
                        },
                        onLineTapped: (l) {
                          setState(() {
                            _selectedLine = l;
                            _selectedWord = null;
                          });
                        },
                        onClearSelection: () {
                          setState(() {
                            _selectedWord = null;
                            _selectedLine = null;
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTextCallout(AppColors colors) {
    final selectedText = _selectedWord?.text ?? _selectedLine?.text ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.accent.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedText,
              style: AppTypography.body.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: colors.accent),
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: selectedText));
              if (mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "$selectedText"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          if (widget.onInsertText != null)
            IconButton(
              icon: Icon(Icons.post_add_rounded, size: 20, color: colors.accent),
              tooltip: 'Insert into note',
              onPressed: () {
                widget.onInsertText!(selectedText);
                Navigator.of(context).pop();
              },
            ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: colors.textTertiary),
            tooltip: 'Clear',
            onPressed: () {
              setState(() {
                _selectedWord = null;
                _selectedLine = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(AppColors colors, bool hasOcr) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (hasOcr) ...[
            _ActionButton(
              icon: Icons.copy_rounded,
              label: 'Copy All Text',
              onPressed: _copyAllText,
            ),
            if (widget.onInsertText != null)
              _ActionButton(
                icon: Icons.post_add_rounded,
                label: 'Insert into Note',
                onPressed: _handleInsertIntoNote,
              ),
          ],
          _ActionButton(
            icon: Icons.download_rounded,
            label: 'Save Image',
            onPressed: _handleSaveImage,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextButton.icon(
      icon: Icon(icon, size: 16, color: colors.accent),
      label: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      onPressed: onPressed,
    );
  }
}

/// Custom painter / overlay rendering highlight boxes over recognized OCR words.
class _LiveTextOverlay extends StatelessWidget {
  const _LiveTextOverlay({
    required this.page,
    this.selectedWord,
    this.selectedLine,
    required this.onWordTapped,
    required this.onLineTapped,
    required this.onClearSelection,
  });

  final OcrPage page;
  final OcrWord? selectedWord;
  final OcrLine? selectedLine;
  final ValueChanged<OcrWord> onWordTapped;
  final ValueChanged<OcrLine> onLineTapped;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final wordWidgets = <Widget>[];

        for (final block in page.blocks) {
          for (final line in block.lines) {
            for (final word in line.words) {
              final isSelected = selectedWord == word;
              final rect = word.bounds;

              final left = rect.x * w;
              final top = rect.y * h;
              final width = rect.width * w;
              final height = rect.height * h;

              wordWidgets.add(
                Positioned(
                  left: left,
                  top: top,
                  width: width > 8 ? width : 8,
                  height: height > 8 ? height : 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onWordTapped(word),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.35)
                            : colors.accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isSelected
                              ? colors.accent
                              : colors.accent.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onClearSelection,
              child: const SizedBox.expand(),
            ),
            ...wordWidgets,
          ],
        );
      },
    );
  }
}
