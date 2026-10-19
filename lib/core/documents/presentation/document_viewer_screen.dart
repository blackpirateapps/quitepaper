import 'dart:async';
import 'dart:io';
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
      _hasAnnotatedDerivative = annotatedBytes != null;
      _activePdfBytes = annotatedBytes ?? docInfo.pdfBytes;
      _pageCount = docInfo.pageCount > 0 ? docInfo.pageCount : 1;
      _selectedPageIndex = widget.initialPageIndex.clamp(0, _pageCount - 1);
      _isLoading = false;
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
  void dispose() {
    _pdfViewerController.dispose();
    _undoHistoryController.dispose();
    super.dispose();
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
    if (docInfo.ocrState == OcrProcessingState.skipped.identifier) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR is skipped for this large PDF to protect device memory.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (modalContext) => SafeArea(
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
                tooltip: 'OCR skipped for this large PDF',
                onPressed: null,
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
            key: ValueKey('pdf_${widget.documentId}_$_hasAnnotatedDerivative'),
            controller: _pdfViewerController,
            undoController: _undoHistoryController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableTextSelection: true,
            canShowTextSelectionMenu: true,
            enableDoubleTapZooming: true,
            canShowPaginationDialog: true,
            initialPageNumber: (widget.initialPageIndex >= 0 ? widget.initialPageIndex : 0) + 1,
            onDocumentLoaded: (details) {
              if (mounted) {
                setState(() {
                  _pageCount = details.document.pages.count;
                });
              }
            },
            onDocumentLoadFailed: (details) {
              debugPrint('[DocumentViewerScreen] SfPdfViewer load failed: ${details.error}');
            },
            onPageChanged: (details) {
              if (mounted) {
                setState(() {
                  _selectedPageIndex = details.newPageNumber - 1;
                });
              }
            },
            onAnnotationAdded: (_) => _onAnnotationMutated(),
            onAnnotationEdited: (_) => _onAnnotationMutated(),
            onAnnotationRemoved: (_) => _onAnnotationMutated(),
          ),
        ),
      ],
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
