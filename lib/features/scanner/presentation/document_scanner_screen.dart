import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/documents/document_models.dart';
import '../../../core/documents/document_provider.dart';
import '../../../core/ocr/ocr_models.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../application/scanner_performance_tracker.dart';
import '../domain/scanned_page.dart';
import 'widgets/page_adjustment_sheet.dart';
import 'widgets/scanner_preview_canvas.dart';

/// Result returned when a document scanning session successfully finishes.
class DocumentScanResult {
  const DocumentScanResult({
    required this.document,
    required this.markdownSnippet,
  });

  final DocumentEntity document;
  final String markdownSnippet;
}

/// Full-screen document scanning screen with multi-page support, automatic boundary detection,
/// non-destructive image adjustments (Crop, Rotate, Brightness, Contrast, Saturation, Grayscale),
/// stable page identity isolation, generation token async race protection, and separate
/// high-resolution PDF finalization pipeline.
class DocumentScannerScreen extends ConsumerStatefulWidget {
  const DocumentScannerScreen({
    super.key,
    this.noteId,
    this.initialTitle = 'Scanned Document',
  });

  final String? noteId;
  final String initialTitle;

  static Future<DocumentScanResult?> open(
    BuildContext context, {
    String? noteId,
    String initialTitle = 'Scanned Document',
  }) {
    return Navigator.of(context).push<DocumentScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DocumentScannerScreen(
          noteId: noteId,
          initialTitle: initialTitle,
        ),
      ),
    );
  }

  @override
  ConsumerState<DocumentScannerScreen> createState() =>
      _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends ConsumerState<DocumentScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraUnavailable = false;

  final List<ScannedPage> _pages = [];
  int _selectedPageIndex = 0;
  bool _isProcessing = false;
  String _processingStatus = '';
  OcrLanguage _selectedLanguage = OcrLanguage.english;

  final ScannerPerformanceTracker _performanceTracker = ScannerPerformanceTracker();
  static const _uuid = Uuid();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() => _isCameraUnavailable = true);
        }
        return;
      }

      final backCamera = _availableCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _isCameraUnavailable = false;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization fallback: $e');
      if (mounted) {
        setState(() => _isCameraUnavailable = true);
      }
    }
  }

  Future<void> _capturePage({int? replaceIndex}) async {
    if (_isProcessing) return;

    Uint8List? rawBytes;

    if (_isCameraInitialized && _cameraController != null) {
      try {
        final xFile = await _cameraController!.takePicture();
        rawBytes = await xFile.readAsBytes();
      } catch (e) {
        debugPrint('Camera takePicture error: $e');
      }
    }

    // Fallback: pick image from device if camera is not active or capture fails
    if (rawBytes == null) {
      await _importPageFromGallery(replaceIndex: replaceIndex);
      return;
    }

    await _processAndAddPage(rawBytes, replaceIndex: replaceIndex);
  }

  Future<void> _importPageFromGallery({int? replaceIndex}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
        allowMultiple: replaceIndex == null,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          Uint8List? bytes = file.bytes;
          if (bytes == null && file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }
          if (bytes != null) {
            await _processAndAddPage(bytes, replaceIndex: replaceIndex);
            if (replaceIndex != null) break;
          }
        }
      }
    } catch (e) {
      debugPrint('Gallery import error: $e');
    }
  }

  Future<void> _processAndAddPage(Uint8List rawBytes, {int? replaceIndex}) async {
    final generation = _performanceTracker.nextGeneration();
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Preparing document page...';
    });

    try {
      final imageProcessor = ref.read(imageProcessorProvider);
      final reps = await imageProcessor.createPageRepresentations(rawBytes);

      // Async Race Protection: Ensure this job is still the latest generation
      if (!_performanceTracker.isGenerationCurrent(generation)) {
        debugPrint('Discarded stale preview generation $generation');
        return;
      }

      stopwatch.stop();
      _performanceTracker.recordPreviewCreation(stopwatch.elapsedMilliseconds.toDouble());

      final newPage = ScannedPage(
        id: _uuid.v4(),
        imageBytes: reps.previewBytes,
        rawImageBytes: rawBytes,
        previewBytes: reps.previewBytes,
        thumbnailBytes: reps.thumbnailBytes,
        width: reps.width,
        height: reps.height,
        pageNumber: replaceIndex != null ? replaceIndex + 1 : _pages.length + 1,
        isNormalized: true,
      );

      if (mounted) {
        setState(() {
          if (replaceIndex != null && replaceIndex < _pages.length) {
            _pages[replaceIndex] = newPage;
            _selectedPageIndex = replaceIndex;
          } else {
            _pages.add(newPage);
            _selectedPageIndex = _pages.length - 1;
          }
          _reindexPages();
        });
      }
    } finally {
      if (mounted && _performanceTracker.isGenerationCurrent(generation)) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });
      }
    }
  }

  Future<void> _openAdjustments(int index) async {
    if (index < 0 || index >= _pages.length) return;

    final imageProcessor = ref.read(imageProcessorProvider);
    final updated = await PageAdjustmentSheet.show(
      context,
      page: _pages[index],
      imageProcessor: imageProcessor,
    );

    if (updated != null && mounted) {
      setState(() {
        _pages[index] = updated;
      });
    }
  }

  void _reindexPages() {
    for (var i = 0; i < _pages.length; i++) {
      _pages[i] = _pages[i].copyWith(pageNumber: i + 1);
    }
  }

  void _deletePage(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _pages.removeAt(index);
        _reindexPages();
        if (_selectedPageIndex >= _pages.length) {
          _selectedPageIndex = (_pages.length - 1).clamp(0, 9999);
        }
      });
    }
  }

  void _movePage(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= _pages.length ||
        toIndex < 0 ||
        toIndex >= _pages.length) {
      return;
    }
    setState(() {
      final item = _pages.removeAt(fromIndex);
      _pages.insert(toIndex, item);
      _reindexPages();
      _selectedPageIndex = toIndex;
    });
  }

  void _selectPage(int index) {
    if (index >= 0 && index < _pages.length) {
      final sw = Stopwatch()..start();
      setState(() => _selectedPageIndex = index);
      sw.stop();
      _performanceTracker.recordPageSwitch(sw.elapsedMilliseconds.toDouble());
    }
  }

  Future<void> _finishAndSaveDocument() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture at least one page before saving.'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Applying high-resolution adjustments...';
    });

    try {
      final imageProcessor = ref.read(imageProcessorProvider);
      final pdfGenerator = ref.read(pdfGeneratorProvider);
      final docService = ref.read(documentServiceProvider);

      final finalPages = <ScannedPage>[];
      final highResStopwatch = Stopwatch()..start();

      // 1. Process each page's high-resolution source off the UI isolate
      for (var i = 0; i < _pages.length; i++) {
        final page = _pages[i];
        if (mounted) {
          setState(() {
            _processingStatus = 'Processing page ${i + 1} of ${_pages.length}...';
          });
        }

        final result = await imageProcessor.processHighResolution(
          page.rawImageBytes,
          page.adjustments,
        );

        finalPages.add(
          page.copyWith(
            imageBytes: result.imageBytes,
            width: result.width,
            height: result.height,
          ),
        );
      }

      highResStopwatch.stop();
      _performanceTracker.recordHighResProcessing(
        highResStopwatch.elapsedMilliseconds.toDouble(),
      );

      // 2. Build canonical multi-page PDF from high-resolution pages
      if (mounted) {
        setState(() => _processingStatus = 'Building PDF document...');
      }

      final pdfStopwatch = Stopwatch()..start();
      final pdfBytes = await pdfGenerator.generatePdf(finalPages);
      pdfStopwatch.stop();
      _performanceTracker.recordPdfCompilation(
        pdfStopwatch.elapsedMilliseconds.toDouble(),
      );

      // 3. Encrypt with Master Key and persist locally
      if (mounted) {
        setState(() => _processingStatus = 'Encrypting & saving document...');
      }

      final result = await docService.createDocumentFromPdfBytes(
        pdfBytes: pdfBytes,
        pageCount: _pages.length,
        noteId: widget.noteId,
        title: widget.initialTitle,
        source: DocumentSource.scanner,
        language: _selectedLanguage,
      );

      if (mounted) {
        Navigator.of(context).pop(
          DocumentScanResult(
            document: result.document,
            markdownSnippet: result.markdownSnippet,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 700;

            return Stack(
              children: [
                if (isTablet)
                  _buildTabletLayout(colors)
                else
                  _buildPhoneLayout(colors),

                // Processing Progress Modal Overlay
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.8),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _processingStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(AppColors colors) {
    return Stack(
      children: [
        // 1. Center Viewport (Live Camera or Active Page Preview)
        Positioned.fill(
          child: _pages.isEmpty
              ? _buildCameraViewport(colors)
              : _buildActivePageCanvas(colors),
        ),

        // 2. Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(colors),
        ),

        // 3. Bottom Controls & Thumbnails
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(colors),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(AppColors colors) {
    return Row(
      children: [
        // Left Column: Dominant Preview Canvas / Camera Viewport
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: _pages.isEmpty
                    ? _buildCameraViewport(colors)
                    : _buildActivePageCanvas(colors),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(colors, isTablet: true),
              ),
            ],
          ),
        ),

        // Right Column: Side Control Pane
        Container(
          width: 340,
          color: colors.surface,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pages (${_pages.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pages.isNotEmpty ? _finishAndSaveDocument : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Save PDF'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _pages.isEmpty
                    ? Center(
                        child: Text(
                          'No pages scanned yet.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : _buildTabletThumbnailsList(colors),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined),
                      tooltip: 'Import from files',
                      onPressed: () => _importPageFromGallery(),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _capturePage(),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Add Page'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(AppColors colors, {bool isTablet = false}) {
    final pageIndicatorText = _pages.isEmpty
        ? 'Align page within frame'
        : '${_selectedPageIndex + 1} / ${_pages.length}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            tooltip: 'Cancel scan',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Document Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  pageIndicatorText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // OCR Language Picker
              PopupMenuButton<OcrLanguage>(
                icon: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
                tooltip: 'OCR Language (${_selectedLanguage.displayName})',
                initialValue: _selectedLanguage,
                onSelected: (lang) => setState(() => _selectedLanguage = lang),
                itemBuilder: (_) => OcrLanguage.values.map((l) {
                  return PopupMenuItem(
                    value: l,
                    child: Row(
                      children: [
                        if (l == _selectedLanguage)
                          Icon(Icons.check, size: 18, color: colors.accent)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(l.displayName),
                      ],
                    ),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: _pages.isNotEmpty ? _finishAndSaveDocument : null,
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  disabledForegroundColor: Colors.white24,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivePageCanvas(AppColors colors) {
    if (_selectedPageIndex >= _pages.length) return const SizedBox.shrink();
    final page = _pages[_selectedPageIndex];

    return Container(
      color: Colors.black,
      child: Center(
        child: ScannerPreviewCanvas(
          previewBytes: page.previewBytes,
          adjustments: page.adjustments,
          onAdjustmentsChanged: (updated) {
            setState(() {
              _pages[_selectedPageIndex] = page.copyWith(adjustments: updated);
            });
          },
        ),
      ),
    );
  }

  Widget _buildCameraViewport(AppColors colors) {
    if (_isCameraInitialized && _cameraController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CameraPreview(_cameraController!),
          ),
          _buildBoundaryIndicator(colors),
        ],
      );
    }

    // Fallback Canvas (Desktop/Simulator or camera permission denied)
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 72,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Document Capture Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isCameraUnavailable
                  ? 'Camera preview is unavailable on this device.\nYou can import photos or scans directly from your files.'
                  : 'Initializing camera...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => _importPageFromGallery(),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import Document Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundaryIndicator(AppColors colors) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 70),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.85 * _pulseAnimation.value),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(AppColors colors) {
    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Multi-Page Thumbnails Strip
          if (_pages.isNotEmpty) ...[
            _buildThumbnailStrip(colors),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Main Shutter and Import Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery / File Import Button
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 28),
                  tooltip: 'Import image from files',
                  onPressed: () => _importPageFromGallery(),
                ),

                // Shutter Capture Button
                GestureDetector(
                  onTap: () => _capturePage(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: colors.accent,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                  ),
                ),

                // Selected Page Delete / Retake / Adjust shortcut
                if (_pages.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                    tooltip: 'Page actions',
                    onSelected: (val) {
                      if (val == 'adjust') {
                        _openAdjustments(_selectedPageIndex);
                      } else if (val == 'retake') {
                        _capturePage(replaceIndex: _selectedPageIndex);
                      } else if (val == 'delete') {
                        _deletePage(_selectedPageIndex);
                      } else if (val == 'move_left') {
                        _movePage(_selectedPageIndex, _selectedPageIndex - 1);
                      } else if (val == 'move_right') {
                        _movePage(_selectedPageIndex, _selectedPageIndex + 1);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'adjust',
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Adjust / Crop Page'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'retake',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 8),
                            Text('Retake Page'),
                          ],
                        ),
                      ),
                      if (_selectedPageIndex > 0)
                        const PopupMenuItem(
                          value: 'move_left',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back, size: 18),
                              SizedBox(width: 8),
                              Text('Move Left'),
                            ],
                          ),
                        ),
                      if (_selectedPageIndex < _pages.length - 1)
                        const PopupMenuItem(
                          value: 'move_right',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_forward, size: 18),
                              SizedBox(width: 8),
                              Text('Move Right'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('Delete Page',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip(AppColors colors) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pages.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == _pages.length) {
            // "+" Add Page Slot
            return Center(
              child: InkWell(
                onTap: () => _capturePage(),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  width: 54,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            );
          }

          final page = _pages[index];
          final isSelected = index == _selectedPageIndex;

          return GestureDetector(
            onTap: () => _selectPage(index),
            child: Stack(
              children: [
                Container(
                  width: 54,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: isSelected ? colors.accent : Colors.white30,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm - 1),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(page.adjustments.toColorMatrix()),
                      child: Image.memory(
                        page.thumbnailBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${page.pageNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!page.adjustments.isNeutral)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.tune, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabletThumbnailsList(AppColors colors) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _pages.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final page = _pages[index];
        final isSelected = index == _selectedPageIndex;

        return InkWell(
          onTap: () => _selectPage(index),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected ? colors.accent.withValues(alpha: 0.12) : colors.surface,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: isSelected ? colors.accent : colors.divider,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(page.adjustments.toColorMatrix()),
                      child: Image.memory(
                        page.thumbnailBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page ${page.pageNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (!page.adjustments.isNeutral)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Adjusted',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Adjust page',
                  onPressed: () => _openAdjustments(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Delete page',
                  onPressed: () => _deletePage(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
