import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
import '../../widgets/quiet_adaptive_modal.dart';
import '../../../features/web_clipper/presentation/web_snapshot_viewer_screen.dart';
import '../document_models.dart';
import '../document_provider.dart';
import '../document_service.dart';

/// Dedicated full-screen viewer for scanned Quiet Paper PDF documents (`qp://document/<UUID>`).
///
/// Decrypts and renders actual visual PDF pages on-device using Syncfusion PDF Viewer,
/// supports native vector text selection, copying, zooming, multi-page continuous navigation,
/// built-in PDF annotations (Highlight, Underline, Strikethrough, Squiggly, Sticky Notes),
/// and non-destructive encrypted storage (preserving original clean PDF).
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
  late final PdfViewerController _pdfViewerController;
  late final UndoHistoryController _undoHistoryController;
  GlobalKey<SfPdfViewerState> _pdfViewerStateKey = GlobalKey<SfPdfViewerState>();
  OverlayEntry? _selectionOverlayEntry;

  // In-document text search state
  bool _isSearching = false;
  String _searchQuery = '';
  PdfTextSearchResult? _searchResult;

  Uint8List? _activePdfBytes;
  bool _isLoading = true;
  bool _hasAnnotatedDerivative = false;
  bool _isDirty = false;
  bool _isSavingAnnotations = false;
  PdfAnnotationMode _activeAnnotationMode = PdfAnnotationMode.none;
  int _selectedPageIndex = 0;
  int _pageCount = 1;
  String? _currentTitle;

  String get displayTitle =>
      _currentTitle ?? _resolution?.data?.title ?? widget.title;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _undoHistoryController = UndoHistoryController();
    _selectedPageIndex = widget.initialPageIndex >= 0
        ? widget.initialPageIndex
        : 0;

    if (widget.initialResolution != null) {
      _resolution = widget.initialResolution;
      _isLoading = false;
      if (_resolution!.isAvailable && _resolution!.data != null) {
        if (_isWebSnapshotDoc(_resolution!.data!)) {
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
        _initDocumentBytes(_resolution!.data!);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDocument();
      });
    }
  }

  bool _isWebSnapshotDoc(ResolvedDocumentInfo docInfo) {
    return DocumentService.isHtmlDocumentPayload(
      bytes: docInfo.pdfBytes,
      title: docInfo.title.isNotEmpty ? docInfo.title : widget.title,
      source: docInfo.source,
    );
  }

  Future<void> _initDocumentBytes(ResolvedDocumentInfo docInfo) async {
    final docService = ref.read(documentServiceProvider);
    final annotatedBytes = await docService.resolveAnnotatedBytes(widget.documentId);
    if (!mounted) return;

    setState(() {
      _pdfViewerStateKey = GlobalKey<SfPdfViewerState>();
      _hasAnnotatedDerivative = annotatedBytes != null;
      _activePdfBytes = annotatedBytes ?? docInfo.pdfBytes;
      _pageCount = docInfo.pageCount > 0 ? docInfo.pageCount : 1;
      _selectedPageIndex = widget.initialPageIndex.clamp(0, _pageCount - 1);
      _isLoading = false;
      _hideFloatingSelectionMenu();
    });
  }

  Future<void> _loadDocument() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final service = ref.read(documentServiceProvider);
    final res = await service.resolveDocument(widget.documentId);
    if (!mounted) return;

    if (res.isAvailable && res.data != null && _isWebSnapshotDoc(res.data!)) {
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

    _resolution = res;
    if (res.isAvailable && res.data != null) {
      await _initDocumentBytes(res.data!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void deactivate() {
    _hideFloatingSelectionMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    _hideFloatingSelectionMenu();
    _searchResult?.removeListener(_onSearchResultUpdated);
    _pdfViewerController.dispose();
    _undoHistoryController.dispose();
    super.dispose();
  }

  void _handleTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    if (!mounted) return;
    if (details.selectedText == null || details.selectedText!.trim().isEmpty) {
      _hideFloatingSelectionMenu();
    } else {
      _showFloatingSelectionMenu(details);
    }
  }

  void _clearSelectionState() {
    _hideFloatingSelectionMenu();
    _pdfViewerController.clearSelection();
  }

  void _applyTextMarkup(PdfAnnotationMode mode) {
    final lines = _pdfViewerStateKey.currentState?.getSelectedTextLines() ?? [];
    _clearSelectionState();
    if (lines.isEmpty) return;

    Annotation annotation;
    switch (mode) {
      case PdfAnnotationMode.highlight:
        annotation = HighlightAnnotation(textBoundsCollection: lines);
        break;
      case PdfAnnotationMode.underline:
        annotation = UnderlineAnnotation(textBoundsCollection: lines);
        break;
      case PdfAnnotationMode.strikethrough:
        annotation = StrikethroughAnnotation(textBoundsCollection: lines);
        break;
      case PdfAnnotationMode.squiggly:
        annotation = SquigglyAnnotation(textBoundsCollection: lines);
        break;
      default:
        return;
    }
    _pdfViewerController.addAnnotation(annotation);
    _onAnnotationMutated();
  }

  Future<void> _promptAddStickyNoteForSelection(
    List<PdfTextLine> lines,
    String selectedText,
  ) async {
    final colors = context.appColors;
    final textController = TextEditingController();

    final noteText = await QuietAdaptiveModal.show<String>(
      context: context,
      type: AdaptiveModalType.dialog,
      maxWidth: 420,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colors.divider, width: 0.8),
        ),
        title: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: colors.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Add Note to Selection',
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border(left: BorderSide(color: colors.accent, width: 3)),
                ),
                child: Text(
                  selectedText.length > 120
                      ? '${selectedText.substring(0, 120)}…'
                      : selectedText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write a note or annotation…',
                hintStyle: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
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
                contentPadding: const EdgeInsets.all(AppSpacing.sm),
              ),
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
            label: 'Save Note',
            variant: QuietButtonVariant.primary,
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text.trim()),
          ),
        ],
      ),
    );

    if (noteText == null || noteText.isEmpty) return;

    final pageNumber = lines.isNotEmpty
        ? lines.first.pageNumber
        : _pdfViewerController.pageNumber;
    final position = lines.isNotEmpty
        ? Offset(lines.last.bounds.right + 4, lines.last.bounds.top)
        : const Offset(72, 72);

    final annotation = StickyNoteAnnotation(
      pageNumber: pageNumber,
      text: noteText,
      position: position,
      icon: PdfStickyNoteIcon.note,
    );
    _pdfViewerController.addAnnotation(annotation);
    _onAnnotationMutated();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note added to document'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _activateDocumentSearch(String query) {
    _searchResult?.removeListener(_onSearchResultUpdated);
    _searchResult?.clear();

    final result = _pdfViewerController.searchText(query);
    result.addListener(_onSearchResultUpdated);

    setState(() {
      _isSearching = true;
      _searchQuery = query;
      _searchResult = result;
    });
  }

  void _onSearchResultUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _closeSearch() {
    _searchResult?.removeListener(_onSearchResultUpdated);
    _searchResult?.clear();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _searchResult = null;
      });
    }
  }

  Future<void> _showSearchPrompt() async {
    final colors = context.appColors;
    final controller = TextEditingController(text: _searchQuery);

    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: colors.divider, width: 0.8),
          ),
          title: Text(
            'Search in Document',
            style: AppTypography.headline.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search term…',
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
            onSubmitted: (val) => Navigator.of(dialogContext).pop(val.trim()),
          ),
          actions: [
            QuietButton(
              label: 'Cancel',
              variant: QuietButtonVariant.secondary,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            QuietButton(
              label: 'Search',
              variant: QuietButtonVariant.primary,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    if (query != null && query.isNotEmpty) {
      _activateDocumentSearch(query);
    }
  }

  void _setAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      _activeAnnotationMode = mode;
      _pdfViewerController.annotationMode = mode;
    });
  }

  void _onAnnotationMutated() {
    if (!mounted) return;
    setState(() {
      _isDirty = true;
    });
  }

  /// Automatically persists annotated PDF bytes back to encrypted storage if modified.
  Future<void> _autoSaveIfDirty() async {
    if (!_isDirty || _isSavingAnnotations) return;
    _isSavingAnnotations = true;
    try {
      final savedList = await _pdfViewerController.saveDocument();
      final savedBytes = Uint8List.fromList(savedList);
      final docService = ref.read(documentServiceProvider);
      await docService.saveAnnotatedDocument(
        documentId: widget.documentId,
        annotatedPdfBytes: savedBytes,
      );
      _hasAnnotatedDerivative = true;
      _isDirty = false;
      _activePdfBytes = savedBytes;
    } catch (e) {
      debugPrint('[DocumentViewerScreen] Auto-save annotations failed: $e');
    } finally {
      _isSavingAnnotations = false;
    }
  }

  /// Explicitly persists annotations with user feedback.
  Future<void> _manualSaveAnnotations() async {
    if (_isSavingAnnotations) return;
    _isSavingAnnotations = true;
    try {
      final savedList = await _pdfViewerController.saveDocument();
      final savedBytes = Uint8List.fromList(savedList);
      final docService = ref.read(documentServiceProvider);
      await docService.saveAnnotatedDocument(
        documentId: widget.documentId,
        annotatedPdfBytes: savedBytes,
      );
      if (mounted) {
        setState(() {
          _hasAnnotatedDerivative = true;
          _isDirty = false;
          _activePdfBytes = savedBytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Annotations saved successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save annotations: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isSavingAnnotations = false;
    }
  }

  /// Reverts annotations by deleting the annotated derivative layer
  /// and reloading the pristine original PDF.
  Future<void> _revertToOriginal() async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        title: Text(
          'Revert to Original Document?',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove all added annotations and restore the original clean document. This cannot be undone.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          QuietButton(
            label: 'Cancel',
            variant: QuietButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          QuietButton(
            label: 'Revert',
            variant: QuietButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final docService = ref.read(documentServiceProvider);
    await docService.revertToOriginalDocument(widget.documentId);

    if (mounted) {
      final pristineBytes = _resolution?.data?.pdfBytes;
      setState(() {
        _isDirty = false;
        _hasAnnotatedDerivative = false;
        _setAnnotationMode(PdfAnnotationMode.none);
        _activePdfBytes = pristineBytes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reverted to original clean document'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    final copyText = await service.getDecryptedOcrFormattedCopyText(
      widget.documentId,
    );
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

  /// Resolves export bytes: either current annotated document or pristine original.
  Future<Uint8List> _resolveExportBytes(
    ResolvedDocumentInfo docInfo, {
    bool forceOriginal = false,
  }) async {
    if (forceOriginal) {
      return docInfo.pdfBytes;
    }

    if (_isDirty) {
      try {
        final savedList = await _pdfViewerController.saveDocument();
        final savedBytes = Uint8List.fromList(savedList);
        final docService = ref.read(documentServiceProvider);
        await docService.saveAnnotatedDocument(
          documentId: widget.documentId,
          annotatedPdfBytes: savedBytes,
        );
        _hasAnnotatedDerivative = true;
        _isDirty = false;
        _activePdfBytes = savedBytes;
        return savedBytes;
      } catch (e) {
        debugPrint('[DocumentViewerScreen] Failed to save annotations for export: $e');
      }
    }

    if (_activePdfBytes != null) {
      return _activePdfBytes!;
    }
    return docInfo.pdfBytes;
  }

  Future<void> _savePdfToStorage() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;

    bool exportAnnotated = _hasAnnotatedDerivative || _isDirty;
    if (exportAnnotated) {
      final choice = await _pickExportVariant(isShare: false);
      if (choice == null) return;
      exportAnnotated = choice;
    }

    try {
      final bytes = await _resolveExportBytes(docInfo, forceOriginal: !exportAnnotated);
      final cleanTitle = docInfo.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final base = cleanTitle.isEmpty ? 'document' : cleanTitle;
      final fileName = exportAnnotated ? '$base-annotated.pdf' : '$base.pdf';

      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF to Storage',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: bytes,
        );
      } catch (e) {
        debugPrint('FilePicker saveFile fallback: $e');
      }

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final file = File(selectedPath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
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

      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetFile = File(p.join(targetDir.path, fileName));
      await targetFile.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${targetDir.path}/$fileName'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Share', onPressed: _sharePdf),
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

    bool exportAnnotated = _hasAnnotatedDerivative || _isDirty;
    if (exportAnnotated) {
      final choice = await _pickExportVariant(isShare: true);
      if (choice == null) return;
      exportAnnotated = choice;
    }

    final bytes = await _resolveExportBytes(docInfo, forceOriginal: !exportAnnotated);
    final cleanTitle = docInfo.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final base = cleanTitle.isEmpty ? 'document' : cleanTitle;
    final fileName = exportAnnotated ? '$base-annotated.pdf' : '$base.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<bool?> _pickExportVariant({required bool isShare}) {
    final colors = context.appColors;
    final action = isShare ? 'Share' : 'Save';
    return QuietAdaptiveModal.show<bool>(
      context: context,
      type: AdaptiveModalType.popover,
      maxWidth: 360,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AdaptiveSheetDragHandle(),
            ListTile(
              leading: Icon(Icons.edit_note_rounded, color: colors.accent),
              title: Text('$action with annotations'),
              subtitle: const Text('Includes all highlights and markings'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                color: colors.textSecondary,
              ),
              title: Text('$action original clean document'),
              subtitle: const Text('Pristine unannotated PDF'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _printPdf() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;
    final bytes = await _resolveExportBytes(docInfo);
    await Printing.layoutPdf(name: docInfo.title, onLayout: (_) async => bytes);
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
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
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
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
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

  void _showAnnotationToolsModal() {
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (modalContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Center(child: AdaptiveSheetDragHandle()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Text(
                'Annotation Tools',
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.highlight, color: Colors.amber),
              title: const Text('Highlight Text'),
              subtitle: const Text('Click and drag over text to highlight'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.highlight
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.highlight);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_underlined, color: Colors.blue),
              title: const Text('Underline Text'),
              subtitle: const Text('Underline key words and phrases'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.underline
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.underline);
              },
            ),
            ListTile(
              leading: const Icon(Icons.strikethrough_s, color: Colors.redAccent),
              title: const Text('Strikethrough'),
              subtitle: const Text('Cross out text'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.strikethrough
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.strikethrough);
              },
            ),
            ListTile(
              leading: const Icon(Icons.waves, color: Colors.orange),
              title: const Text('Squiggly Underline'),
              subtitle: const Text('Wavy underline for grammar or review'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.squiggly
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.squiggly);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined, color: Colors.purple),
              title: const Text('Sticky Note / Comment'),
              subtitle: const Text('Tap anywhere on the page to pin a comment'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.stickyNote
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.stickyNote);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.pan_tool_outlined, color: colors.textSecondary),
              title: const Text('Navigate / Select Mode'),
              subtitle: const Text('Normal reading, panning, and selection'),
              trailing: _activeAnnotationMode == PdfAnnotationMode.none
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                Navigator.of(modalContext).pop();
                _setAnnotationMode(PdfAnnotationMode.none);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final docInfo = _resolution?.data;

    final isOcrAvailable = docInfo?.ocrState == 'available';
    final isOcrProcessing =
        docInfo?.ocrState == 'processing' || docInfo?.ocrState == 'queued';
    final isOcrFailed = docInfo?.ocrState == 'failed';
    final isOcrSkipped = docInfo?.ocrState == 'skipped';

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _autoSaveIfDirty();
          if (context.mounted) {
            Navigator.of(context).pop(_currentTitle);
          }
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Page ${_selectedPageIndex + 1} of ${docInfo.pageCount} (${docInfo.pageCount} ${docInfo.pageCount == 1 ? 'page' : 'pages'}) • ${_formatByteSize(docInfo.byteSize)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
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
                              : isOcrSkipped
                              ? 'OCR skipped (large PDF)'
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
                      if (_hasAnnotatedDerivative) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Annotated',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            if (_isDirty)
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save Annotations',
                color: colors.accent,
                onPressed: _manualSaveAnnotations,
              ),
            IconButton(
              icon: Icon(
                _activeAnnotationMode != PdfAnnotationMode.none
                    ? Icons.edit_note_rounded
                    : Icons.edit_note_outlined,
              ),
              color: _activeAnnotationMode != PdfAnnotationMode.none
                  ? colors.accent
                  : null,
              tooltip: 'Annotation Tools',
              onPressed: _showAnnotationToolsModal,
            ),
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
            else if (isOcrSkipped)
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                tooltip: 'Run OCR (adaptive resolution)',
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
                  case 'search':
                    _showSearchPrompt();
                    break;
                  case 'save_annotations':
                    _manualSaveAnnotations();
                    break;
                  case 'revert_original':
                    _revertToOriginal();
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
                const PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18),
                      SizedBox(width: 12),
                      Expanded(child: Text('Search in Document')),
                    ],
                  ),
                ),
                if (_hasAnnotatedDerivative || _isDirty) ...[
                  const PopupMenuItem(
                    value: 'save_annotations',
                    child: Row(
                      children: [
                        Icon(Icons.save_outlined, size: 18),
                        SizedBox(width: 12),
                        Expanded(child: Text('Save Annotations')),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'revert_original',
                    child: Row(
                      children: [
                        Icon(Icons.restore_outlined, size: 18),
                        SizedBox(width: 12),
                        Expanded(child: Text('Revert to Original Document')),
                      ],
                    ),
                  ),
                ],
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
                const PopupMenuDivider(),
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
        body: _buildBody(colors),
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
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

    if (_activePdfBytes == null || _activePdfBytes!.isEmpty) {
      return _buildErrorState(colors, res);
    }

    return Column(
      children: [
        if (_isSearching && _searchResult != null) _buildSearchBar(colors),
        if (_activeAnnotationMode != PdfAnnotationMode.none)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            color: colors.accent.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(
                  _getAnnotationIcon(_activeAnnotationMode),
                  size: 16,
                  color: colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_getAnnotationModeName(_activeAnnotationMode)} Mode: Select text or tap on page',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  tooltip: 'Undo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _undoHistoryController.undo();
                    _onAnnotationMutated();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  tooltip: 'Redo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _undoHistoryController.redo();
                    _onAnnotationMutated();
                  },
                ),
                TextButton(
                  onPressed: () => _setAnnotationMode(PdfAnnotationMode.none),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.accent,
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        Expanded(
          child: SfPdfViewer.memory(
            _activePdfBytes!,
            key: _pdfViewerStateKey,
            controller: _pdfViewerController,
            undoController: _undoHistoryController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableTextSelection: true,
            canShowTextSelectionMenu: false,
            enableDoubleTapZooming: true,
            canShowPaginationDialog: true,
            currentSearchTextHighlightColor:
                colors.accent.withValues(alpha: 0.6),
            otherSearchTextHighlightColor:
                colors.accent.withValues(alpha: 0.25),
            initialPageNumber: (widget.initialPageIndex >= 0
                    ? widget.initialPageIndex
                    : 0) +
                1,
            onDocumentLoaded: (details) {
              if (mounted) {
                setState(() {
                  _pageCount = details.document.pages.count;
                });
              }
            },
            onDocumentLoadFailed: (details) {
              debugPrint(
                  '[DocumentViewerScreen] SfPdfViewer load failed: ${details.error}');
            },
            onPageChanged: (details) {
              if (mounted) {
                setState(() {
                  _selectedPageIndex = details.newPageNumber - 1;
                });
              }
            },
            onTextSelectionChanged: _handleTextSelectionChanged,
            onAnnotationAdded: (_) => _onAnnotationMutated(),
            onAnnotationEdited: (_) => _onAnnotationMutated(),
            onAnnotationRemoved: (_) => _onAnnotationMutated(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(AppColors colors) {
    final result = _searchResult;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search: "$_searchQuery"',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (result != null)
            Text(
              result.totalInstanceCount > 0
                  ? '${result.currentInstanceIndex} of ${result.totalInstanceCount}'
                  : (result.isSearchCompleted ? '0 results' : 'Searching…'),
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
            onPressed: (result != null && result.hasResult)
                ? () => result.previousInstance()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
            onPressed: (result != null && result.hasResult)
                ? () => result.nextInstance()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close search',
            visualDensity: VisualDensity.compact,
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  void _showFloatingSelectionMenu(PdfTextSelectionChangedDetails details) {
    _hideFloatingSelectionMenu();

    final region = details.globalSelectedRegion;
    final selectedText = details.selectedText;
    if (region == null || selectedText == null || selectedText.trim().isEmpty) {
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const double menuHeight = 44.0;
    final double maxMenuWidth = math.min(540.0, screenSize.width - 24.0);

    // Determine vertical position: prefer above, fallback to below
    double top = region.top - menuHeight - 10.0;
    if (top < mediaQuery.padding.top + kToolbarHeight) {
      top = region.bottom + 10.0;
    }
    if (top + menuHeight > screenSize.height - mediaQuery.padding.bottom - 10.0) {
      top = math.max(10.0, screenSize.height - menuHeight - mediaQuery.padding.bottom - 10.0);
    }

    // Determine horizontal position: center on selected text, clamp within screen
    double left = region.center.dx - (maxMenuWidth / 2);
    left = left.clamp(12.0, math.max(12.0, screenSize.width - maxMenuWidth - 12.0));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;

    _selectionOverlayEntry = OverlayEntry(
      maintainState: true,
      builder: (overlayContext) {
        return Positioned(
          top: top,
          left: left,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: menuHeight,
              constraints: BoxConstraints(maxWidth: maxMenuWidth),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: colors.divider, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSelectionActionItem(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      colors: colors,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: selectedText));
                        _clearSelectionState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Text copied to clipboard'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    _buildMenuDivider(colors),
                    _buildSelectionActionItem(
                      icon: Icons.border_color_rounded,
                      label: 'Highlight',
                      iconColor: const Color(0xFFE5A000),
                      colors: colors,
                      onTap: () => _applyTextMarkup(PdfAnnotationMode.highlight),
                    ),
                    _buildSelectionActionItem(
                      icon: Icons.format_underlined_rounded,
                      label: 'Underline',
                      colors: colors,
                      onTap: () => _applyTextMarkup(PdfAnnotationMode.underline),
                    ),
                    _buildSelectionActionItem(
                      icon: Icons.format_strikethrough_rounded,
                      label: 'Strike',
                      colors: colors,
                      onTap: () =>
                          _applyTextMarkup(PdfAnnotationMode.strikethrough),
                    ),
                    _buildSelectionActionItem(
                      icon: Icons.waves_rounded,
                      label: 'Squiggly',
                      colors: colors,
                      onTap: () => _applyTextMarkup(PdfAnnotationMode.squiggly),
                    ),
                    _buildMenuDivider(colors),
                    _buildSelectionActionItem(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'Note',
                      iconColor: colors.accent,
                      colors: colors,
                      onTap: () {
                        final lines =
                            _pdfViewerStateKey.currentState?.getSelectedTextLines() ??
                                [];
                        _clearSelectionState();
                        _promptAddStickyNoteForSelection(lines, selectedText);
                      },
                    ),
                    _buildMenuDivider(colors),
                    _buildSelectionActionItem(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      colors: colors,
                      onTap: () {
                        final query = selectedText.trim();
                        _clearSelectionState();
                        if (query.isNotEmpty) {
                          _activateDocumentSearch(query);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_selectionOverlayEntry!);
  }

  void _hideFloatingSelectionMenu() {
    if (_selectionOverlayEntry != null) {
      _selectionOverlayEntry!.remove();
      _selectionOverlayEntry!.dispose();
      _selectionOverlayEntry = null;
    }
  }

  Widget _buildMenuDivider(AppColors colors) {
    return Container(
      width: 0.8,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.divider,
    );
  }

  Widget _buildSelectionActionItem({
    required IconData icon,
    required String label,
    required AppColors colors,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: iconColor ?? colors.textPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAnnotationIcon(PdfAnnotationMode mode) {
    switch (mode) {
      case PdfAnnotationMode.highlight:
        return Icons.highlight;
      case PdfAnnotationMode.underline:
        return Icons.format_underlined;
      case PdfAnnotationMode.strikethrough:
        return Icons.strikethrough_s;
      case PdfAnnotationMode.squiggly:
        return Icons.waves;
      case PdfAnnotationMode.stickyNote:
        return Icons.sticky_note_2_outlined;
      case PdfAnnotationMode.none:
        return Icons.pan_tool_outlined;
    }
  }

  String _getAnnotationModeName(PdfAnnotationMode mode) {
    switch (mode) {
      case PdfAnnotationMode.highlight:
        return 'Highlight';
      case PdfAnnotationMode.underline:
        return 'Underline';
      case PdfAnnotationMode.strikethrough:
        return 'Strikethrough';
      case PdfAnnotationMode.squiggly:
        return 'Squiggly';
      case PdfAnnotationMode.stickyNote:
        return 'Sticky Note';
      case PdfAnnotationMode.none:
        return 'Navigate';
    }
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
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
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
