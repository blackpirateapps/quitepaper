import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../ocr/ocr_models.dart';
import '../../ocr/ocr_provider.dart';
import '../../ocr/presentation/ocr_language_dialog.dart';
import '../../ocr/presentation/ocr_text_viewer_screen.dart';
import '../../uri/quiet_paper_uri.dart';
import '../../uri/resource_resolver.dart';
import '../../widgets/quiet_button.dart';
import '../../../features/web_clipper/presentation/web_snapshot_viewer_screen.dart';
import '../document_models.dart';
import '../document_provider.dart';

/// Dedicated full-screen viewer for scanned Quiet Paper PDF documents (`qp://document/<UUID>`).
///
/// Decrypts and renders actual visual PDF pages on-device, supports multi-page navigation,
/// zoom/pan, responsive phone & tablet layouts, and direct export/download to phone storage.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.documentId,
    this.title = 'Scanned Document',
    this.initialResolution,
    this.initialPageIndex = 0,
  });

  final String documentId;
  final String title;
  final ResourceResolution<ResolvedDocumentInfo>? initialResolution;
  final int initialPageIndex;

  static Future<String?> open(
    BuildContext context, {
    required String documentId,
    String title = 'Scanned Document',
    ResourceResolution<ResolvedDocumentInfo>? initialResolution,
    int initialPageIndex = 0,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentId: documentId,
          title: title,
          initialResolution: initialResolution,
          initialPageIndex: initialPageIndex,
        ),
      ),
    );
  }

  static Future<String?> openUri(
    BuildContext context, {
    required QuietPaperUri uri,
    String title = 'Scanned Document',
    int initialPageIndex = 0,
  }) {
    return open(
      context,
      documentId: uri.resourceId,
      title: title,
      initialPageIndex: initialPageIndex,
    );
  }

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  ResourceResolution<ResolvedDocumentInfo>? _resolution;
  final List<Uint8List> _renderedPages = [];
  bool _isLoading = true;
  bool _isRasterizing = false;
  int _selectedPageIndex = 0;
  String? _currentTitle;

  String get displayTitle => _currentTitle ?? _resolution?.data?.title ?? widget.title;

  @override
  void initState() {
    super.initState();
    _selectedPageIndex = widget.initialPageIndex >= 0 ? widget.initialPageIndex : 0;
    if (widget.initialResolution != null) {
      _resolution = widget.initialResolution;
      _isLoading = false;
      if (_resolution!.isAvailable && _resolution!.data != null) {
        if (_resolution!.data!.source == DocumentSource.webSnapshot.identifier ||
            _resolution!.data!.source == 'web_snapshot') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => WebSnapshotViewerScreen(
                    documentId: widget.documentId,
                    title: _resolution!.data!.title,
                  ),
                ),
              );
            }
          });
          return;
        }
        _selectedPageIndex = widget.initialPageIndex.clamp(
          0,
          (_resolution!.data!.pageCount > 0 ? _resolution!.data!.pageCount : 1) - 1,
        );
        _rasterizePages(_resolution!.data!.pdfBytes);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDocument();
      });
    }
  }

  Future<void> _loadDocument() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final service = ref.read(documentServiceProvider);
    final res = await service.resolveDocument(widget.documentId);
    if (mounted) {
      if (res.isAvailable && res.data != null &&
          (res.data!.source == DocumentSource.webSnapshot.identifier ||
              res.data!.source == 'web_snapshot')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WebSnapshotViewerScreen(
              documentId: widget.documentId,
              title: res.data!.title,
            ),
          ),
        );
        return;
      }

      final pageCount = res.data?.pageCount ?? 1;
      setState(() {
        _resolution = res;
        _isLoading = false;
        _selectedPageIndex = widget.initialPageIndex.clamp(0, pageCount > 0 ? pageCount - 1 : 0);
      });

      if (res.isAvailable && res.data != null) {
        _rasterizePages(res.data!.pdfBytes);
      }
    }
  }

  Future<void> _rasterizePages(Uint8List pdfBytes) async {
    if (_isRasterizing) return;
    _isRasterizing = true;
    _renderedPages.clear();

    try {
      await for (final page in Printing.raster(pdfBytes, dpi: 150.0)) {
        final png = await page.toPng();
        if (!mounted) break;
        setState(() {
          _renderedPages.add(png);
        });
      }
    } catch (e) {
      debugPrint('Error rasterizing PDF document pages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRasterizing = false;
        });
      }
    }
  }

  void _openOcrTextViewer() {
    final docInfo = _resolution?.data;
    OcrTextViewerScreen.open(
      context,
      documentId: widget.documentId,
      title: docInfo?.title ?? widget.title,
      pdfBytes: docInfo?.pdfBytes,
      source: DocumentSource.fromIdentifier(docInfo?.source),
    );
  }

  Future<void> _copyOcrText() async {
    final service = ref.read(documentProcessingServiceProvider);
    final copyText = await service.getDecryptedOcrFormattedCopyText(widget.documentId);
    if (copyText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No OCR text available to copy.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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

  Future<void> _regenerateOcr({OcrLanguage? language}) async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting OCR text recognition in background...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    final service = ref.read(documentProcessingServiceProvider);
    final targetLang = language ?? OcrLanguage.fromCode(docInfo.ocrLanguage);

    await service.regenerateOcr(
      documentId: widget.documentId,
      pdfBytes: docInfo.pdfBytes,
      source: DocumentSource.fromIdentifier(docInfo.source),
      language: targetLang,
    );
    await _loadDocument();
  }

  Future<void> _openLanguageDialog() async {
    final docInfo = _resolution?.data;
    final currentLang = OcrLanguage.fromCode(docInfo?.ocrLanguage);
    final chosenLang = await OcrLanguageDialog.show(
      context,
      initialLanguage: currentLang,
    );

    if (chosenLang != null && docInfo != null && mounted) {
      await _regenerateOcr(language: chosenLang);
    }
  }

  Future<void> _savePdfToStorage() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;

    try {
      final cleanTitle = docInfo.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${cleanTitle.isEmpty ? 'document' : cleanTitle}.pdf';

      // 1. Try native file picker save dialog if available
      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF to Storage',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: docInfo.pdfBytes,
        );
      } catch (e) {
        debugPrint('FilePicker saveFile fallback: $e');
      }

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final file = File(selectedPath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(docInfo.pdfBytes);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document saved: ${p.basename(selectedPath)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Direct Downloads folder fallback
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetFile = File(p.join(targetDir.path, fileName));
      await targetFile.writeAsBytes(docInfo.pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${targetDir.path}/$fileName'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              onPressed: _sharePdf,
            ),
          ),
        );
      }
    } catch (e) {
      await _sharePdf();
    }
  }

  Future<void> _sharePdf() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;
    final cleanTitle = docInfo.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final fileName = '${cleanTitle.isEmpty ? 'document' : cleanTitle}.pdf';
    await Printing.sharePdf(bytes: docInfo.pdfBytes, filename: fileName);
  }

  Future<void> _printPdf() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;
    await Printing.layoutPdf(
      name: docInfo.title,
      onLayout: (_) async => docInfo.pdfBytes,
    );
  }

  Future<void> _promptRenameDocument() async {
    final colors = context.appColors;
    final initialName = displayTitle;
    final controller = TextEditingController(text: initialName);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialName.length,
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
          title: Text(
            'Rename Document',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a new name for this document:',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Document Name',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (val) {
                  Navigator.of(dialogContext).pop(val.trim());
                },
              ),
            ],
          ),
          actions: [
            QuietButton(
              label: 'Cancel',
              variant: QuietButtonVariant.secondary,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            QuietButton(
              label: 'Rename',
              variant: QuietButtonVariant.primary,
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == initialName) {
      return;
    }

    try {
      final docService = ref.read(documentServiceProvider);
      await docService.renameDocument(
        documentId: widget.documentId,
        newTitle: newTitle,
        noteId: _resolution?.data?.noteId,
      );

      if (mounted) {
        setState(() {
          _currentTitle = newTitle;
          if (_resolution?.data != null) {
            _resolution = ResourceResolution.available(
              _resolution!.uri,
              _resolution!.data!.copyWith(title: newTitle),
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document renamed to "$newTitle"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final docInfo = _resolution?.data;

    final isOcrAvailable = docInfo?.ocrState == 'available';
    final isOcrProcessing = docInfo?.ocrState == 'processing' || docInfo?.ocrState == 'queued';
    final isOcrFailed = docInfo?.ocrState == 'failed';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_currentTitle);
        }
      },
      child: Scaffold(
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
                displayTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (docInfo != null)
                Row(
                  children: [
                    Text(
                      '${docInfo.pageCount} ${docInfo.pageCount == 1 ? 'page' : 'pages'} • ${_formatByteSize(docInfo.byteSize)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isOcrAvailable
                            ? Colors.green.withValues(alpha: 0.15)
                            : isOcrFailed
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOcrAvailable
                            ? 'Searchable (OCR)'
                            : docInfo.ocrState == 'processing'
                                ? 'Processing text…'
                                : docInfo.ocrState == 'queued'
                                    ? 'Preparing text…'
                                    : isOcrFailed
                                        ? 'OCR unavailable'
                                        : 'PDF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOcrAvailable
                              ? Colors.green
                              : isOcrFailed
                                  ? Colors.redAccent
                                  : colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Rename document',
              onPressed: _promptRenameDocument,
            ),
            if (isOcrAvailable)
              IconButton(
                icon: const Icon(Icons.article_outlined),
                tooltip: 'View OCR Text',
                onPressed: _openOcrTextViewer,
              )
            else if (isOcrProcessing)
              IconButton(
                icon: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
                tooltip: 'OCR is processing... Tap to restart',
                onPressed: _regenerateOcr,
              )
            else
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                tooltip: 'Run OCR',
                onPressed: _regenerateOcr,
              ),
            if (docInfo != null) ...[
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Save PDF to storage',
                onPressed: _savePdfToStorage,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share PDF',
                onPressed: _sharePdf,
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded),
                tooltip: 'Print PDF',
                onPressed: _printPdf,
              ),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Document options',
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _promptRenameDocument();
                    break;
                  case 'view_ocr':
                    _openOcrTextViewer();
                    break;
                  case 'copy_ocr':
                    _copyOcrText();
                    break;
                  case 'regenerate_ocr':
                    _regenerateOcr();
                    break;
                  case 'language':
                    _openLanguageDialog();
                    break;
                  case 'save':
                    _savePdfToStorage();
                    break;
                  case 'share':
                    _sharePdf();
                    break;
                  case 'print':
                    _printPdf();
                    break;
                  case 'reload':
                    _loadDocument();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Rename Document')),
                    ],
                  ),
                ),
                if (isOcrAvailable) ...[
                  const PopupMenuItem(
                    value: 'view_ocr',
                    child: Row(
                      children: [
                        Icon(Icons.article_outlined, size: 18),
                        SizedBox(width: 12),
                        Expanded(child: Text('View OCR Text')),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_ocr',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 18),
                        SizedBox(width: 12),
                        Expanded(child: Text('Copy OCR Text')),
                      ],
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: 'regenerate_ocr',
                  child: Row(
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Run / Regenerate OCR')),
                    ],
                  ),
                ),
                if (docInfo != null)
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
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Save PDF')),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Share PDF')),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Print PDF')),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Reload Document')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(colors, isTablet),
      ),
    );
  }

  Widget _buildBody(AppColors colors, bool isTablet) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Decrypting document...',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final res = _resolution;
    if (res == null || !res.isAvailable || res.data == null) {
      return _buildErrorState(colors, res);
    }

    final docInfo = res.data!;

    if (isTablet) {
      return _buildTabletLayout(colors, docInfo);
    }

    return _buildPhoneLayout(colors, docInfo);
  }

  Widget _buildPhoneLayout(AppColors colors, ResolvedDocumentInfo docInfo) {
    return Column(
      children: [
        // Main PDF Document Canvas
        Expanded(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildPageContent(colors, docInfo),
              ),
            ),
          ),
        ),

        // Bottom Page Indicator Pill
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.divider, width: 0.8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_selectedPageIndex + 1} of ${docInfo.pageCount}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: _selectedPageIndex > 0
                        ? () => setState(() => _selectedPageIndex--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: _selectedPageIndex < docInfo.pageCount - 1
                        ? () => setState(() => _selectedPageIndex++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(AppColors colors, ResolvedDocumentInfo docInfo) {
    return Row(
      children: [
        // Left Thumbnail Rail
        Container(
          width: 180,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(right: BorderSide(color: colors.divider, width: 0.8)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: docInfo.pageCount,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final isSelected = index == _selectedPageIndex;
              final hasRendered = index < _renderedPages.length;

              return GestureDetector(
                onTap: () => setState(() => _selectedPageIndex = index),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.divider,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: hasRendered
                      ? Image.memory(
                          _renderedPages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 36,
                              color: isSelected ? colors.accent : colors.textTertiary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Page ${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? colors.accent : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),

        // Right Main Viewer
        Expanded(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _buildPageContent(colors, docInfo),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageContent(AppColors colors, ResolvedDocumentInfo docInfo) {
    if (_selectedPageIndex < _renderedPages.length) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Image.memory(
          _renderedPages[_selectedPageIndex],
          fit: BoxFit.contain,
        ),
      );
    }

    if (_isRasterizing) {
      return AspectRatio(
        aspectRatio: 1 / 1.414,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Rendering page ${_selectedPageIndex + 1}...',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1 / 1.414, // Standard A4 Document aspect ratio
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: colors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              docInfo.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Page ${_selectedPageIndex + 1} of ${docInfo.pageCount}',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                'End-to-End Encrypted PDF (QPD1)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    AppColors colors,
    ResourceResolution<ResolvedDocumentInfo>? res,
  ) {
    final message = res?.errorMessage ?? 'Unable to load scanned document.';
    final isLocked = res?.isLocked ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? Icons.lock_outline : Icons.error_outline,
              size: 56,
              color: isLocked ? colors.accent : Colors.redAccent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isLocked ? 'Document Locked' : 'Document Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
