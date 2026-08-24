import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../documents/document_models.dart';
import '../ocr_models.dart';
import '../ocr_provider.dart';
import 'ocr_language_dialog.dart';

/// Dedicated full-screen viewer for recognized on-device OCR text organized by page.
///
/// Features memory-safe on-demand lazy page decryption with bounded LRU caching,
/// virtualized rendering, selectable text, page boundaries, copy all/selection,
/// language configuration, jump to page, and on-demand OCR regeneration.
class OcrTextViewerScreen extends ConsumerStatefulWidget {
  const OcrTextViewerScreen({
    super.key,
    required this.documentId,
    this.title = 'OCR Text',
    this.pdfBytes,
    this.source = DocumentSource.scanner,
  });

  final String documentId;
  final String title;
  final Uint8List? pdfBytes;
  final DocumentSource source;

  static Future<void> open(
    BuildContext context, {
    required String documentId,
    String title = 'OCR Text',
    Uint8List? pdfBytes,
    DocumentSource source = DocumentSource.scanner,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OcrTextViewerScreen(
          documentId: documentId,
          title: title,
          pdfBytes: pdfBytes,
          source: source,
        ),
      ),
    );
  }

  @override
  ConsumerState<OcrTextViewerScreen> createState() => _OcrTextViewerScreenState();
}

class _OcrTextViewerScreenState extends ConsumerState<OcrTextViewerScreen> {
  OcrDocumentMetadata? _metadata;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isCopyingAll = false;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  /// Memory-bounded LRU cache of decrypted pages (capacity: 25)
  final LinkedHashMap<int, OcrPage> _pageCache = LinkedHashMap<int, OcrPage>();
  static const int _maxCachedPages = 25;

  @override
  void initState() {
    super.initState();
    _loadOcrMetadata();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageCache.clear();
    super.dispose();
  }

  Future<void> _loadOcrMetadata() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pageCache.clear();
    });

    try {
      final processingService = ref.read(documentProcessingServiceProvider);
      final metadata = await processingService.getDocumentOcrMetadata(widget.documentId);

      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
          if (metadata == null || metadata.pageCount == 0) {
            _errorMessage = 'No OCR text available for this document.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load OCR document: $e';
        });
      }
    }
  }

  void _cachePage(int pageNumber, OcrPage page) {
    if (_pageCache.containsKey(pageNumber)) {
      _pageCache.remove(pageNumber);
    } else if (_pageCache.length >= _maxCachedPages) {
      _pageCache.remove(_pageCache.keys.first);
    }
    _pageCache[pageNumber] = page;
  }

  Future<void> _handleCopyAll() async {
    final meta = _metadata;
    if (meta == null || meta.pageCount == 0 || _isCopyingAll) return;

    setState(() => _isCopyingAll = true);

    try {
      final processingService = ref.read(documentProcessingServiceProvider);
      final copyText = await processingService.getDecryptedOcrFormattedCopyText(widget.documentId);

      if (copyText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: copyText));

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OCR text copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy OCR text: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCopyingAll = false);
      }
    }
  }

  Future<void> _handleCopyPage(OcrPage page) async {
    await Clipboard.setData(ClipboardData(text: page.plainText.trim()));

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Page ${page.pageNumber} text copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleOpenLanguageDialog() async {
    final newLanguage = await OcrLanguageDialog.show(
      context,
      initialLanguage: _metadata?.language,
    );

    if (newLanguage != null && mounted) {
      if (widget.pdfBytes != null) {
        await _handleRegenerateOcr(language: newLanguage);
      }
    }
  }

  Future<void> _handleJumpToPage() async {
    final meta = _metadata;
    if (meta == null || meta.pageCount <= 1) return;

    final controller = TextEditingController();
    final pageTarget = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Jump to Page',
            style: TextStyle(color: colors.textPrimary, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter page number (1 – ${meta.pageCount}):',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 42',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (val) {
                  final pageNum = int.tryParse(val);
                  if (pageNum != null && pageNum >= 1 && pageNum <= meta.pageCount) {
                    Navigator.of(ctx).pop(pageNum);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final pageNum = int.tryParse(controller.text);
                if (pageNum != null && pageNum >= 1 && pageNum <= meta.pageCount) {
                  Navigator.of(ctx).pop(pageNum);
                }
              },
              child: const Text('Jump'),
            ),
          ],
        );
      },
    );

    if (pageTarget != null && mounted) {
      final index = (pageTarget - 1).clamp(0, meta.pageCount - 1);
      final estimatedOffset = index * 180.0;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _handleRegenerateOcr({OcrLanguage? language}) async {
    if (widget.pdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document PDF required to regenerate OCR.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final lang = language ?? _metadata?.language ?? OcrLanguage.english;
      final service = ref.read(documentProcessingServiceProvider);

      await service.regenerateOcr(
        documentId: widget.documentId,
        pdfBytes: widget.pdfBytes!,
        source: widget.source,
        language: lang,
      );

      await _loadOcrMetadata();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR regenerated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate OCR: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final meta = _metadata;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (meta != null)
              Text(
                '${meta.pageCount} ${meta.pageCount == 1 ? 'page' : 'pages'} • OCR (${meta.language.displayName})',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          if (meta != null && meta.pageCount > 0)
            IconButton(
              icon: _isCopyingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.copy_rounded),
              tooltip: 'Copy all OCR text',
              onPressed: _isCopyingAll ? null : _handleCopyAll,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'OCR options',
            onSelected: (value) {
              switch (value) {
                case 'copy_all':
                  _handleCopyAll();
                  break;
                case 'jump_to_page':
                  _handleJumpToPage();
                  break;
                case 'language':
                  _handleOpenLanguageDialog();
                  break;
                case 'regenerate':
                  _handleRegenerateOcr();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (meta != null && meta.pageCount > 0)
                const PopupMenuItem(
                  value: 'copy_all',
                  child: Row(
                    children: [
                      Icon(Icons.content_copy_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Copy All Text')),
                    ],
                  ),
                ),
              if (meta != null && meta.pageCount > 1)
                const PopupMenuItem(
                  value: 'jump_to_page',
                  child: Row(
                    children: [
                      Icon(Icons.find_in_page_outlined, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Jump to Page')),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, size: 18),
                    SizedBox(width: 12),
                    Expanded(child: Text('OCR Language')),
                  ],
                ),
              ),
              if (widget.pdfBytes != null)
                const PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Regenerate OCR')),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(colors, isTablet),
    );
  }

  Widget _buildBody(AppColors colors, bool isTablet) {
    if (_isLoading || _isProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _isProcessing ? 'Processing OCR text…' : 'Loading OCR document…',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final meta = _metadata;
    if (meta == null || meta.pageCount == 0) {
      return _buildErrorState(colors);
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 720 : double.infinity,
        ),
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          itemCount: meta.pageCount,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
          itemBuilder: (context, index) {
            final pageNum = meta.pageNumbers.isNotEmpty
                ? meta.pageNumbers[index]
                : (index + 1);

            return _LazyOcrPageSection(
              key: ValueKey('ocr_page_${widget.documentId}_$pageNum'),
              documentId: widget.documentId,
              pageNumber: pageNum,
              colors: colors,
              cachedPage: _pageCache[pageNum],
              onPageLoaded: (page) => _cachePage(pageNum, page),
              onCopyPage: _handleCopyPage,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 56,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'OCR Text Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorMessage ?? 'No recognized OCR text is stored for this document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            if (widget.pdfBytes != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Generate OCR Text'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleRegenerateOcr(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LazyOcrPageSection extends ConsumerStatefulWidget {
  const _LazyOcrPageSection({
    super.key,
    required this.documentId,
    required this.pageNumber,
    required this.colors,
    this.cachedPage,
    required this.onPageLoaded,
    required this.onCopyPage,
  });

  final String documentId;
  final int pageNumber;
  final AppColors colors;
  final OcrPage? cachedPage;
  final ValueChanged<OcrPage> onPageLoaded;
  final ValueChanged<OcrPage> onCopyPage;

  @override
  ConsumerState<_LazyOcrPageSection> createState() => _LazyOcrPageSectionState();
}

class _LazyOcrPageSectionState extends ConsumerState<_LazyOcrPageSection> {
  OcrPage? _page;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.cachedPage != null) {
      _page = widget.cachedPage;
    } else {
      _loadPage();
    }
  }

  @override
  void didUpdateWidget(covariant _LazyOcrPageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId ||
        oldWidget.pageNumber != widget.pageNumber) {
      if (widget.cachedPage != null) {
        _page = widget.cachedPage;
      } else {
        _loadPage();
      }
    } else if (widget.cachedPage != null && _page == null) {
      _page = widget.cachedPage;
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final service = ref.read(documentProcessingServiceProvider);
      final page = await service.getDecryptedOcrPage(
        widget.documentId,
        widget.pageNumber,
        shallow: true,
      );

      if (mounted) {
        setState(() {
          _page = page;
          _isLoading = false;
          _hasError = (page == null);
        });
        if (page != null) {
          widget.onPageLoaded(page);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final page = _page;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: colors.divider,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      'Page ${widget.pageNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (page != null)
                    Text(
                      page.source == OcrSource.embeddedPdfText
                          ? 'PDF Text Layer'
                          : 'On-Device OCR',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
              if (page != null && page.plainText.trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy page text',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: colors.textSecondary,
                  onPressed: () => widget.onCopyPage(page),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Body Text or Loading / Error State
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Decrypting page ${widget.pageNumber}…',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else if (_hasError || page == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: colors.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    'Unable to decrypt page ${widget.pageNumber}.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else if (page.plainText.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No text recognized on this page.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: colors.textTertiary,
                ),
              ),
            )
          else
            SelectableText(
              page.plainText.trim(),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colors.textPrimary,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
        ],
      ),
    );
  }
}
