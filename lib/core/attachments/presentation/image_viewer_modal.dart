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
import '../../database/app_database.dart';
import '../../ocr/ocr_models.dart';
import '../../ocr/ocr_provider.dart';
import '../../ocr/presentation/ocr_language_dialog.dart';
import '../../sync/sync_provider.dart';
import '../attachment_provider.dart';
import 'image_dimension_reader.dart';
import 'viewer_image_item.dart';

/// Immersive editorial image viewer supporting single images and multi-image document galleries.
///
/// Features:
/// - Fit-to-screen initial display with high-resolution rendering.
/// - Smooth pinch-to-zoom (`InteractiveViewer`, 1.0x to 5.0x).
/// - Double-tap zoom (toggles between 1.0x fit and 2.5x detail zoom at tap position).
/// - Panning while zoomed without page-switch collisions.
/// - Multi-image gallery navigation (`PageView`, arrow buttons, keyboard shortcuts).
/// - Clean image counter (e.g. `2 / 5`, shown only when multiple images exist).
/// - Live Text bounding box overlay rendered at 60/120 FPS via a single-pass `CustomPainter`.
/// - Multi-word range selection (tap, sweep-drag, double-tap line, scope expansions).
/// - Actions: "Copy All Text", "Insert Text into Note", "Copy Image", "Save Image", "Share Image", manual OCR re-run.
/// - Light Paper and Dark Paper theme integration.
/// - Seamless non-destructive exit returning to exact document scroll position.
class ImageViewerModal extends ConsumerStatefulWidget {
  ImageViewerModal({
    super.key,
    List<ViewerImageItem>? images,
    String? assetId,
    String? altText,
    Uint8List? initialImageBytes,
    this.initialIndex = 0,
    this.onInsertText,
  })  : assert(images != null || assetId != null, 'Either images or assetId must be provided'),
        images = images != null && images.isNotEmpty
            ? List.unmodifiable(images)
            : [
                ViewerImageItem(
                  assetId: assetId,
                  altText: altText,
                  initialBytes: initialImageBytes,
                ),
              ],
        assetId = assetId ?? (images != null && images.isNotEmpty ? (images[0].assetId ?? '') : ''),
        altText = altText ?? (images != null && images.isNotEmpty ? images[0].altText : null),
        initialImageBytes = initialImageBytes ?? (images != null && images.isNotEmpty ? images[0].initialBytes : null);

  final List<ViewerImageItem> images;
  final int initialIndex;
  final void Function(String text)? onInsertText;

  // Backwards-compatible fields for single-item queries
  final String assetId;
  final String? altText;
  final Uint8List? initialImageBytes;

  /// Opens viewer for a single asset.
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

  /// Opens viewer for a multi-image gallery.
  static Future<void> openGallery(
    BuildContext context, {
    required List<ViewerImageItem> images,
    int initialIndex = 0,
    void Function(String text)? onInsertText,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ImageViewerModal(
          images: images,
          initialIndex: initialIndex,
          onInsertText: onInsertText,
        ),
      ),
    );
  }

  @override
  ConsumerState<ImageViewerModal> createState() => _ImageViewerModalState();
}

class _ImageViewerModalState extends ConsumerState<ImageViewerModal> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isCurrentPageZoomed = false;

  final Map<int, GlobalKey<_ViewerImagePageState>> _pageKeys = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  _ViewerImagePageState? get _activePageState => _pageKeys[_currentIndex]?.currentState;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentItem = widget.images[_currentIndex];
    final totalImages = widget.images.length;
    final hasMultiple = totalImages > 1;

    final activeState = _activePageState;
    final hasOcr = activeState?.hasOcr ?? false;
    final isProcessing = activeState?.isProcessing ?? false;
    final showLiveText = activeState?.showLiveText ?? true;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                  currentItem.displayTitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMultiple) ...[
                      Text(
                        '${_currentIndex + 1} / $totalImages',
                        style: AppTypography.caption.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    _buildOcrStatusBadge(colors, hasOcr, isProcessing),
                  ],
                ),
              ],
            ),
            actions: [
              if (hasMultiple) ...[
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: _currentIndex > 0 ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.3),
                  ),
                  tooltip: 'Previous Image',
                  onPressed: _currentIndex > 0 ? _goToPrevious : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _currentIndex < totalImages - 1
                        ? colors.textPrimary
                        : colors.textTertiary.withValues(alpha: 0.3),
                  ),
                  tooltip: 'Next Image',
                  onPressed: _currentIndex < totalImages - 1 ? _goToNext : null,
                ),
              ],
              if (hasOcr)
                IconButton(
                  icon: Icon(
                    showLiveText ? Icons.text_fields_rounded : Icons.text_fields_outlined,
                    color: showLiveText ? colors.accent : colors.textSecondary,
                  ),
                  tooltip: showLiveText ? 'Hide Live Text' : 'Show Live Text',
                  onPressed: () {
                    activeState?.toggleLiveText();
                    setState(() {});
                  },
                ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: colors.textPrimary),
                tooltip: 'Share Image',
                onPressed: () => activeState?.handleShareImage(),
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
                      activeState?.copyAllText();
                      break;
                    case 'insert_text':
                      activeState?.handleInsertIntoNote();
                      break;
                    case 'copy_image':
                      activeState?.handleCopyImage();
                      break;
                    case 'save_image':
                      activeState?.handleSaveImage();
                      break;
                    case 'share_image':
                      activeState?.handleShareImage();
                      break;
                    case 'retry_ocr':
                      activeState?.handleRetryOcr();
                      break;
                    case 'ocr_language':
                      OcrLanguageDialog.show(context);
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
                    value: 'copy_image',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Copy Image'),
                      ],
                    ),
                  ),
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
                  PopupMenuItem(
                    value: 'share_image',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Share Image'),
                      ],
                    ),
                  ),
                  if (currentItem.isAsset) ...[
                    const PopupMenuDivider(),
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
                  ],
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalImages,
              physics: _isCurrentPageZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _isCurrentPageZoomed = false;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.images[index];
                final key = _pageKeys.putIfAbsent(index, () => GlobalKey<_ViewerImagePageState>());

                return _ViewerImagePage(
                  key: key,
                  item: item,
                  onInsertText: widget.onInsertText,
                  onZoomChanged: (isZoomed) {
                    if (index == _currentIndex && _isCurrentPageZoomed != isZoomed) {
                      setState(() {
                        _isCurrentPageZoomed = isZoomed;
                      });
                    }
                  },
                  onOcrStateChanged: () {
                    if (index == _currentIndex) {
                      setState(() {});
                    }
                  },
                );
              },
            ),
          ),
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
}

class _ViewerImagePage extends ConsumerStatefulWidget {
  const _ViewerImagePage({
    super.key,
    required this.item,
    this.onInsertText,
    required this.onZoomChanged,
    required this.onOcrStateChanged,
  });

  final ViewerImageItem item;
  final void Function(String text)? onInsertText;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onOcrStateChanged;

  @override
  ConsumerState<_ViewerImagePage> createState() => _ViewerImagePageState();
}

class _ViewerImagePageState extends ConsumerState<_ViewerImagePage> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  Uint8List? _imageBytes;
  Size? _imageDimensions;
  AttachmentEntity? _attachment;
  OcrDocument? _ocrDocument;
  bool _isLoading = true;
  bool _isOcrLoading = true;
  bool _showLiveText = true;

  _OcrTextSelection _selection = const _OcrTextSelection.empty();

  bool get hasOcr =>
      _ocrDocument != null &&
      _ocrDocument!.pages.isNotEmpty &&
      _ocrDocument!.pages.first.plainText.trim().isNotEmpty;

  bool get isProcessing =>
      _attachment?.ocrState == 'processing' ||
      _attachment?.ocrState == 'queued' ||
      _isOcrLoading;

  bool get showLiveText => _showLiveText;

  void toggleLiveText() {
    setState(() {
      _showLiveText = !_showLiveText;
      if (!_showLiveText) {
        _selection = _selection.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);
    _imageBytes = widget.item.initialBytes;
    if (_imageBytes != null) {
      _resolveImageDimensions(_imageBytes!);
    }
    _loadImageAndOcr();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final isZoomed = (scale - 1.0).abs() > 0.05;
    widget.onZoomChanged(isZoomed);
  }

  void _resolveImageDimensions(Uint8List bytes) {
    final dims = ImageDimensionReader.extractDimensions(bytes);
    if (dims != null) {
      _imageDimensions = dims;
      return;
    }
    ui.instantiateImageCodec(bytes).then((codec) {
      return codec.getNextFrame();
    }).then((frame) {
      if (mounted) {
        setState(() {
          _imageDimensions = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
        });
      }
    }).catchError((_) {});
  }

  Future<void> _loadImageAndOcr() async {
    if (!mounted) return;
    setState(() => _isLoading = _imageBytes == null);

    // 1. Resolve encrypted attachment
    if (widget.item.isAsset) {
      final assetId = widget.item.assetId!;
      final db = ref.read(databaseProvider);
      final att = await db.getAttachment(assetId);
      if (mounted) {
        setState(() => _attachment = att);
      }

      if (_imageBytes == null) {
        final service = ref.read(attachmentServiceProvider);
        final res = await service.resolveAsset(assetId);
        if (mounted && res.isAvailable && res.data != null) {
          _resolveImageDimensions(res.data!);
          setState(() {
            _imageBytes = res.data;
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      await _loadOcrDocument(assetId);
    }
    // 2. Resolve network image URL
    else if (widget.item.isNetwork) {
      if (_imageBytes == null) {
        try {
          final res = await http.get(Uri.parse(widget.item.url!));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            _resolveImageDimensions(res.bodyBytes);
            if (mounted) {
              setState(() {
                _imageBytes = res.bodyBytes;
                _isLoading = false;
                _isOcrLoading = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isOcrLoading = false;
              });
            }
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isOcrLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOcrLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOcrLoading = false;
        });
      }
    }

    widget.onOcrStateChanged();
  }

  Future<void> _loadOcrDocument(String assetId) async {
    if (!mounted) return;
    setState(() => _isOcrLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final keyManager = ref.read(keyManagerProvider);
      final ocrPages = await db.getAttachmentOcrPages(assetId);

      if (ocrPages.isNotEmpty && keyManager.isUnlocked) {
        final masterKey = keyManager.getMasterKey();
        final crypto = ref.read(ocrCryptoProvider);
        final firstPage = ocrPages.first;

        final encryptedBytes = base64Decode(firstPage.encryptedPayload);
        final doc = await crypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: assetId,
        );

        if (mounted) {
          setState(() {
            _ocrDocument = doc;
            _isOcrLoading = false;
            if (doc.pages.isNotEmpty) {
              _selection = _OcrTextSelection(page: doc.pages.first);
            }
          });
          widget.onOcrStateChanged();
          return;
        }
      }
    } catch (e) {
      debugPrint('[ImageViewerModal] Error loading OCR document: $e');
    }

    if (mounted) {
      setState(() => _isOcrLoading = false);
      widget.onOcrStateChanged();
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

  Future<void> copyAllText() async {
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

  void handleInsertIntoNote({String? overrideText}) {
    final text = overrideText ?? _ocrDocument?.fullPlainText ?? '';
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
      copyAllText();
    }
  }

  Future<void> handleCopyImage() async {
    if (_imageBytes == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: widget.item.displayTitle));
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> handleSaveImage() async {
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

  Future<void> handleShareImage() async {
    if (_imageBytes == null) return;

    try {
      if (widget.item.isAsset) {
        final shareService = ref.read(attachmentShareServiceProvider);
        final success = await shareService.shareAttachment(widget.item.assetId!);
        if (success) return;
      }

      final shareService = ref.read(attachmentShareServiceProvider);
      await shareService.shareImageBytes(_imageBytes!);
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

  Future<void> handleRetryOcr() async {
    if (_imageBytes == null || !widget.item.isAsset) return;

    final assetId = widget.item.assetId!;
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
      await service.regenerateOcr(assetId, language: prefLang);
      await _loadOcrDocument(assetId);
      final db = ref.read(databaseProvider);
      final updatedAtt = await db.getAttachment(assetId);
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

    return Column(
      children: [
        Expanded(
          child: _buildImageCanvas(colors),
        ),
        if (_selection.isNotEmpty)
          _buildSelectedTextCallout(colors)
        else if (hasOcr || _imageBytes != null)
          _buildBottomActionBar(colors),
      ],
    );
  }

  Widget _buildImageCanvas(AppColors colors) {
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
              final rawSize = _imageDimensions ??
                  (page != null && page.width > 0 && page.height > 0
                      ? Size(page.width.toDouble(), page.height.toDouble())
                      : Size(constraints.maxWidth, constraints.maxHeight));

              final fittedSizes = applyBoxFit(
                BoxFit.contain,
                rawSize,
                Size(constraints.maxWidth, constraints.maxHeight),
              );

              final fittedWidth = fittedSizes.destination.width;
              final fittedHeight = fittedSizes.destination.height;

              return SizedBox(
                width: fittedWidth,
                height: fittedHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      _imageBytes!,
                      fit: BoxFit.fill,
                    ),
                    if (_showLiveText && page != null && page.blocks.isNotEmpty)
                      RepaintBoundary(
                        child: _LiveTextLayer(
                          page: page,
                          selection: _selection,
                          fittedSize: Size(fittedWidth, fittedHeight),
                          accentColor: colors.accent,
                          onSelectionChanged: (newSelection) {
                            setState(() => _selection = newSelection);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTextCallout(AppColors colors) {
    final selectedText = _selection.text;
    final wordCount = _selection.wordCount;
    final canExpandLine = _selection.activeLine != null &&
        _selection.selectedWords.length < _selection.activeLine!.words.length;
    final canExpandBlock = _selection.activeBlock != null &&
        _selection.selectedWords.length <
            _selection.activeBlock!.lines.fold<int>(
              0,
              (sum, l) => sum + l.words.length,
            );

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
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedText,
                  style: AppTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '$wordCount ${wordCount == 1 ? 'word' : 'words'}',
                  style: AppTypography.caption.copyWith(
                    color: colors.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: colors.textTertiary),
                tooltip: 'Clear selection',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  setState(() {
                    _selection = _selection.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CalloutButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
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
                _CalloutButton(
                  icon: Icons.post_add_rounded,
                  label: 'Insert',
                  onPressed: () {
                    handleInsertIntoNote(overrideText: selectedText);
                  },
                ),
              if (canExpandLine)
                _CalloutButton(
                  icon: Icons.view_headline_rounded,
                  label: 'Line',
                  onPressed: () {
                    if (_selection.activeLine != null) {
                      setState(() {
                        _selection = _selection.selectLine(_selection.activeLine!);
                      });
                    }
                  },
                ),
              if (canExpandBlock)
                _CalloutButton(
                  icon: Icons.notes_rounded,
                  label: 'Block',
                  onPressed: () {
                    if (_selection.activeBlock != null) {
                      setState(() {
                        _selection = _selection.selectBlock(_selection.activeBlock!);
                      });
                    }
                  },
                ),
              _CalloutButton(
                icon: Icons.select_all_rounded,
                label: 'Select All',
                onPressed: () {
                  setState(() {
                    _selection = _selection.selectAll();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(AppColors colors) {
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
              onPressed: copyAllText,
            ),
            if (widget.onInsertText != null)
              _ActionButton(
                icon: Icons.post_add_rounded,
                label: 'Insert into Note',
                onPressed: () => handleInsertIntoNote(),
              ),
          ],
          _ActionButton(
            icon: Icons.download_rounded,
            label: 'Save Image',
            onPressed: handleSaveImage,
          ),
        ],
      ),
    );
  }
}

class _CalloutButton extends StatelessWidget {
  const _CalloutButton({
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

    return OutlinedButton.icon(
      icon: Icon(icon, size: 14, color: colors.accent),
      label: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: colors.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      onPressed: onPressed,
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

/// Selection model holding contiguous selected words in reading order across an OCR page.
@immutable
class _OcrTextSelection {
  const _OcrTextSelection({
    required this.page,
    this.selectedWords = const [],
    this.activeBlock,
    this.activeLine,
  });

  const _OcrTextSelection.empty()
      : page = const OcrPage(
          pageNumber: 1,
          plainText: '',
          width: 0,
          height: 0,
        ),
        selectedWords = const [],
        activeBlock = null,
        activeLine = null;

  final OcrPage page;
  final List<OcrWord> selectedWords;
  final OcrBlock? activeBlock;
  final OcrLine? activeLine;

  bool get isEmpty => selectedWords.isEmpty;
  bool get isNotEmpty => selectedWords.isNotEmpty;
  int get wordCount => selectedWords.length;

  String get text => selectedWords.map((w) => w.text).join(' ').trim();

  bool containsWord(OcrWord word) => selectedWords.contains(word);

  List<OcrWord> get allWords {
    final list = <OcrWord>[];
    for (final block in page.blocks) {
      for (final line in block.lines) {
        list.addAll(line.words);
      }
    }
    return list;
  }

  _OcrTextSelection selectWord(OcrWord word) {
    OcrBlock? foundBlock;
    OcrLine? foundLine;
    for (final block in page.blocks) {
      for (final line in block.lines) {
        if (line.words.contains(word)) {
          foundBlock = block;
          foundLine = line;
          break;
        }
      }
      if (foundBlock != null) break;
    }
    return _OcrTextSelection(
      page: page,
      selectedWords: [word],
      activeBlock: foundBlock,
      activeLine: foundLine,
    );
  }

  _OcrTextSelection selectRange(OcrWord startWord, OcrWord endWord) {
    final words = allWords;
    final startIndex = words.indexOf(startWord);
    final endIndex = words.indexOf(endWord);

    if (startIndex == -1 || endIndex == -1) {
      return selectWord(endWord);
    }

    final from = startIndex <= endIndex ? startIndex : endIndex;
    final to = startIndex <= endIndex ? endIndex : startIndex;

    final range = words.sublist(from, to + 1);

    OcrBlock? foundBlock;
    OcrLine? foundLine;
    for (final block in page.blocks) {
      for (final line in block.lines) {
        if (line.words.contains(endWord)) {
          foundBlock = block;
          foundLine = line;
          break;
        }
      }
      if (foundBlock != null) break;
    }

    return _OcrTextSelection(
      page: page,
      selectedWords: List.unmodifiable(range),
      activeBlock: foundBlock,
      activeLine: foundLine,
    );
  }

  _OcrTextSelection selectLine(OcrLine line) {
    OcrBlock? foundBlock;
    for (final block in page.blocks) {
      if (block.lines.contains(line)) {
        foundBlock = block;
        break;
      }
    }
    return _OcrTextSelection(
      page: page,
      selectedWords: List.unmodifiable(line.words),
      activeBlock: foundBlock,
      activeLine: line,
    );
  }

  _OcrTextSelection selectBlock(OcrBlock block) {
    final blockWords = <OcrWord>[];
    for (final line in block.lines) {
      blockWords.addAll(line.words);
    }
    return _OcrTextSelection(
      page: page,
      selectedWords: List.unmodifiable(blockWords),
      activeBlock: block,
      activeLine: block.lines.isNotEmpty ? block.lines.first : null,
    );
  }

  _OcrTextSelection selectAll() {
    return _OcrTextSelection(
      page: page,
      selectedWords: List.unmodifiable(allWords),
      activeBlock: page.blocks.isNotEmpty ? page.blocks.first : null,
      activeLine: page.blocks.isNotEmpty && page.blocks.first.lines.isNotEmpty
          ? page.blocks.first.lines.first
          : null,
    );
  }

  _OcrTextSelection clear() {
    return _OcrTextSelection(page: page);
  }
}

/// Gesture detector and custom-paint layer over the image.
class _LiveTextLayer extends StatefulWidget {
  const _LiveTextLayer({
    required this.page,
    required this.selection,
    required this.fittedSize,
    required this.accentColor,
    required this.onSelectionChanged,
  });

  final OcrPage page;
  final _OcrTextSelection selection;
  final Size fittedSize;
  final Color accentColor;
  final ValueChanged<_OcrTextSelection> onSelectionChanged;

  @override
  State<_LiveTextLayer> createState() => _LiveTextLayerState();
}

class _LiveTextLayerState extends State<_LiveTextLayer> {
  OcrWord? _dragStartWord;
  OcrWord? _lastSelectedEndWord;
  int _lastTapTime = 0;
  Offset _lastTapPos = Offset.zero;

  Rect _getWordRect(OcrWord word, Size size) {
    return Rect.fromLTWH(
      word.bounds.x * size.width,
      word.bounds.y * size.height,
      (word.bounds.width * size.width).clamp(6.0, size.width),
      (word.bounds.height * size.height).clamp(6.0, size.height),
    );
  }

  OcrWord? _findWordAt(Offset localPosition, Size size) {
    const touchMargin = 4.0;
    for (final block in widget.page.blocks) {
      for (final line in block.lines) {
        for (final word in line.words) {
          final rect = _getWordRect(word, size).inflate(touchMargin);
          if (rect.contains(localPosition)) {
            return word;
          }
        }
      }
    }
    return null;
  }

  OcrLine? _findLineAt(Offset localPosition, Size size) {
    const touchMargin = 6.0;
    for (final block in widget.page.blocks) {
      for (final line in block.lines) {
        final lineRect = Rect.fromLTWH(
          line.bounds.x * size.width,
          line.bounds.y * size.height,
          (line.bounds.width * size.width).clamp(10.0, size.width),
          (line.bounds.height * size.height).clamp(10.0, size.height),
        ).inflate(touchMargin);
        if (lineRect.contains(localPosition)) {
          return line;
        }
      }
    }
    return null;
  }

  OcrWord? _findNearestWord(Offset localPosition, Size size) {
    final direct = _findWordAt(localPosition, size);
    if (direct != null) return direct;

    for (final block in widget.page.blocks) {
      for (final line in block.lines) {
        final lineTop = line.bounds.y * size.height - 14.0;
        final lineBottom = (line.bounds.y + line.bounds.height) * size.height + 14.0;
        if (localPosition.dy >= lineTop && localPosition.dy <= lineBottom) {
          OcrWord? closestOnLine;
          double closestHorizDist = double.infinity;
          for (final word in line.words) {
            final wordRect = _getWordRect(word, size);
            final wordMidX = wordRect.center.dx;
            final dist = (wordMidX - localPosition.dx).abs();
            if (dist < closestHorizDist) {
              closestHorizDist = dist;
              closestOnLine = word;
            }
          }
          if (closestOnLine != null) return closestOnLine;
        }
      }
    }

    OcrWord? bestWord;
    double bestDist = double.infinity;
    for (final block in widget.page.blocks) {
      for (final line in block.lines) {
        for (final word in line.words) {
          final rect = _getWordRect(word, size);
          final dist = (rect.center - localPosition).distance;
          if (dist < bestDist) {
            bestDist = dist;
            bestWord = word;
          }
        }
      }
    }
    return bestWord;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.fittedSize;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final pos = event.localPosition;
        final isDoubleTap = (now - _lastTapTime < 300) && (pos - _lastTapPos).distance < 24.0;
        _lastTapTime = now;
        _lastTapPos = pos;

        if (isDoubleTap) {
          final line = _findLineAt(pos, size);
          if (line != null) {
            widget.onSelectionChanged(widget.selection.selectLine(line));
            _dragStartWord = null;
            _lastSelectedEndWord = null;
            return;
          }
        }

        final hitWord = _findWordAt(pos, size);
        if (hitWord != null) {
          _dragStartWord = hitWord;
          _lastSelectedEndWord = hitWord;
          widget.onSelectionChanged(widget.selection.selectWord(hitWord));
        } else {
          _dragStartWord = null;
          _lastSelectedEndWord = null;
        }
      },
      onPointerMove: (event) {
        if (_dragStartWord != null) {
          final currentWord = _findNearestWord(event.localPosition, size);
          if (currentWord != null && currentWord != _lastSelectedEndWord) {
            _lastSelectedEndWord = currentWord;
            widget.onSelectionChanged(
              widget.selection.selectRange(_dragStartWord!, currentWord),
            );
          }
        }
      },
      onPointerUp: (event) {
        if (_dragStartWord == null && _lastSelectedEndWord == null) {
          widget.onSelectionChanged(widget.selection.clear());
        }
        _dragStartWord = null;
        _lastSelectedEndWord = null;
      },
      child: CustomPaint(
        size: size,
        painter: _LiveTextPainter(
          page: widget.page,
          selection: widget.selection,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }
}

/// Ultra high-performance single-pass hardware-accelerated painter for OCR bounding boxes.
class _LiveTextPainter extends CustomPainter {
  _LiveTextPainter({
    required this.page,
    required this.selection,
    required this.accentColor,
  })  : _ambientFillPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
        _ambientBorderPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
        _selectedFillPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.38)
          ..style = PaintingStyle.fill,
        _selectedBorderPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

  final OcrPage page;
  final _OcrTextSelection selection;
  final Color accentColor;

  final Paint _ambientFillPaint;
  final Paint _ambientBorderPaint;
  final Paint _selectedFillPaint;
  final Paint _selectedBorderPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (page.blocks.isEmpty) return;

    for (final block in page.blocks) {
      for (final line in block.lines) {
        for (final word in line.words) {
          final isSelected = selection.containsWord(word);
          final rect = Rect.fromLTWH(
            word.bounds.x * size.width,
            word.bounds.y * size.height,
            (word.bounds.width * size.width).clamp(6.0, size.width),
            (word.bounds.height * size.height).clamp(6.0, size.height),
          );
          final rrect = RRect.fromRectAndRadius(
            rect,
            const Radius.circular(2.5),
          );

          if (isSelected) {
            canvas.drawRRect(rrect, _selectedFillPaint);
            canvas.drawRRect(rrect, _selectedBorderPaint);
          } else {
            canvas.drawRRect(rrect, _ambientFillPaint);
            canvas.drawRRect(rrect, _ambientBorderPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiveTextPainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.selection != selection ||
        oldDelegate.accentColor != accentColor;
  }
}
