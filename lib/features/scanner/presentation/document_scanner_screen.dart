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
import '../domain/scanned_page.dart';
import 'widgets/page_adjustment_sheet.dart';

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
/// page reordering, retake/delete actions, OCR language selection, and instant PDF compilation.
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
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Detecting page & normalizing...';
    });

    try {
      final imageProcessor = ref.read(imageProcessorProvider);
      final normalized = await imageProcessor.normalizePage(rawBytes);

      final newPage = ScannedPage(
        id: _uuid.v4(),
        imageBytes: normalized.normalizedBytes,
        rawImageBytes: rawBytes,
        width: normalized.width,
        height: normalized.height,
        pageNumber: replaceIndex != null ? replaceIndex + 1 : _pages.length + 1,
        isNormalized: true,
      );

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
    } finally {
      if (mounted) {
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
      _processingStatus = 'Generating encrypted PDF document...';
    });

    try {
      final docService = ref.read(documentServiceProvider);
      final pdfGenerator = ref.read(pdfGeneratorProvider);

      // 1. Build canonical PDF bytes from all captured pages in sequence
      final pdfBytes = await pdfGenerator.generatePdf(_pages);

      // 2. Encrypt with Master Key, persist locally, and start background OCR
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
        child: Stack(
          children: [
            // 1. Main Viewport (Camera Preview or Fallback Capture Canvas)
            Positioned.fill(
              child: _buildCameraViewport(colors),
            ),

            // 2. Top Navigation Bar (Close, Title, Language Picker, Done Action)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(colors),
            ),

            // 3. Bottom Multi-Page Carousel & Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(colors),
            ),

            // 4. Processing Progress Overlay
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _processingStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColors colors) {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Document Scanner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _pages.isEmpty
                    ? 'Align page within frame'
                    : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'} scanned',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
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

  Widget _buildCameraViewport(AppColors colors) {
    if (_isCameraInitialized && _cameraController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CameraPreview(_cameraController!),
          ),
          // Boundary Detection Highlight Indicator
          _buildBoundaryIndicator(colors),
        ],
      );
    }

    // Fallback Mode Canvas (e.g. desktop/simulator or camera permission denied)
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
            onTap: () {
              setState(() => _selectedPageIndex = index);
              _openAdjustments(index);
            },
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
                    image: DecorationImage(
                      image: MemoryImage(page.imageBytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
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
}
