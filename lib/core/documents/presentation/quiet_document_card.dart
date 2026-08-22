import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../uri/resource_resolver.dart';
import '../../../features/web_clipper/presentation/web_snapshot_viewer_screen.dart';
import '../document_models.dart';
import '../document_provider.dart';
import 'document_viewer_screen.dart';

/// Embedded interactive card widget for scanned Quiet Paper PDF documents (`qp://document/<UUID>`).
///
/// Displays a live first-page thumbnail preview, document metadata, E2EE badge,
/// direct tap to view full screen, and a direct download/save button to export to phone storage.
class QuietDocumentCard extends ConsumerStatefulWidget {
  const QuietDocumentCard({
    super.key,
    required this.documentId,
    required this.title,
    required this.uriString,
    this.onDocumentRenamed,
  });

  final String documentId;
  final String title;
  final String uriString;
  final void Function(String documentId, String newTitle)? onDocumentRenamed;

  @override
  ConsumerState<QuietDocumentCard> createState() => _QuietDocumentCardState();
}

class _QuietDocumentCardState extends ConsumerState<QuietDocumentCard> {
  ResourceResolution<ResolvedDocumentInfo>? _resolution;
  Uint8List? _firstPageThumbnail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocument();
    });
  }

  @override
  void didUpdateWidget(QuietDocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loadDocument();
    }
  }

  Future<void> _loadDocument() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final service = ref.read(documentServiceProvider);
    final res = await service.resolveDocument(widget.documentId);

    if (mounted) {
      setState(() {
        _resolution = res;
        _isLoading = false;
      });

      if (res.isAvailable && res.data != null) {
        _rasterizeFirstPage(res.data!.pdfBytes);
      }
    }
  }

  Future<void> _rasterizeFirstPage(Uint8List pdfBytes) async {
    try {
      await for (final page in Printing.raster(pdfBytes, pages: const [0], dpi: 72.0)) {
        final png = await page.toPng();
        if (mounted) {
          setState(() {
            _firstPageThumbnail = png;
          });
        }
        break;
      }
    } catch (e) {
      debugPrint('Unable to rasterize first page thumbnail: $e');
    }
  }

  Future<void> _saveToStorage() async {
    final docInfo = _resolution?.data;
    if (docInfo == null) return;

    try {
      final isWebSnapshot = docInfo.source == DocumentSource.webSnapshot.identifier ||
          docInfo.source == 'web_snapshot';
      final cleanTitle = docInfo.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final ext = isWebSnapshot ? 'html' : 'pdf';
      final fileName = '${cleanTitle.isEmpty ? (isWebSnapshot ? 'snapshot' : 'document') : cleanTitle}.$ext';

      // 1. Try file picker save dialog if available
      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: isWebSnapshot ? 'Save Web Snapshot' : 'Save PDF Document',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [ext],
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
              content: Text('${isWebSnapshot ? "Snapshot" : "Document"} saved: ${p.basename(selectedPath)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Direct Downloads directory fallback
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
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final docInfo = _resolution?.data;
    final isLocked = _resolution?.isLocked ?? false;
    final isError = _resolution != null && !_resolution!.isAvailable && !isLocked;

    final displayTitle = docInfo?.title ?? widget.title;

    String ocrStatusText = _formatByteSize(docInfo?.byteSize ?? 0);
    if (docInfo != null) {
      if (docInfo.ocrState == 'processing' || docInfo.ocrState == 'queued') {
        ocrStatusText = 'Processing text…';
      } else if (docInfo.ocrState == 'available') {
        ocrStatusText = 'Searchable';
      } else if (docInfo.ocrState == 'failed') {
        ocrStatusText = 'OCR unavailable';
      }
    }

    final pageCountText = docInfo != null
        ? '${docInfo.pageCount} ${docInfo.pageCount == 1 ? 'page' : 'pages'} • $ocrStatusText'
        : 'Encrypted PDF';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        elevation: 0,
        child: InkWell(
          onTap: () async {
            if (docInfo?.source == DocumentSource.webSnapshot.identifier) {
              await WebSnapshotViewerScreen.open(
                context,
                documentId: widget.documentId,
                title: displayTitle,
              );
              return;
            }

            final renamedTitle = await DocumentViewerScreen.open(
              context,
              documentId: widget.documentId,
              title: displayTitle,
              initialResolution: _resolution,
            );
            if (renamedTitle != null && renamedTitle.isNotEmpty && mounted) {
              _loadDocument();
              widget.onDocumentRenamed?.call(widget.documentId, renamedTitle);
            }
          },
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: colors.divider,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. First-Page Thumbnail / Preview Tile
                Container(
                  width: 54,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: colors.divider, width: 0.6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _buildThumbnail(colors, isLocked, isError),
                ),

                const SizedBox(width: AppSpacing.md),

                // 2. Title & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isLocked
                            ? 'Encrypted (Locked)'
                            : isError
                                ? (_resolution?.errorMessage ?? 'Unavailable')
                                : (docInfo?.source ==
                                        DocumentSource.webSnapshot.identifier
                                    ? 'Web Snapshot'
                                    : pageCountText),
                        style: TextStyle(
                          fontSize: 12,
                          color: isLocked
                              ? colors.accent
                              : isError
                                  ? Colors.redAccent
                                  : colors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.sm / 2),
                        ),
                        child: Text(
                          docInfo?.source ==
                                  DocumentSource.webSnapshot.identifier
                              ? 'WEB (QPD1)'
                              : 'PDF (QPD1)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Quick Action Button (Save / Download to storage)
                if (docInfo != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      size: 22,
                      color: colors.textSecondary,
                    ),
                    tooltip: docInfo.source == DocumentSource.webSnapshot.identifier
                        ? 'Save snapshot to storage'
                        : 'Save PDF to storage',
                    onPressed: _saveToStorage,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(AppColors colors, bool isLocked, bool isError) {
    if (_firstPageThumbnail != null) {
      return Image.memory(
        _firstPageThumbnail!,
        width: 54,
        height: 72,
        fit: BoxFit.cover,
      );
    }

    if (_isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
        ),
      );
    }

    if (isLocked) {
      return Icon(
        Icons.lock_outline,
        size: 24,
        color: colors.accent,
      );
    }

    if (isError) {
      return const Icon(
        Icons.error_outline,
        size: 24,
        color: Colors.redAccent,
      );
    }

    if (_resolution?.data?.source == DocumentSource.webSnapshot.identifier) {
      return Icon(
        Icons.language_rounded,
        size: 28,
        color: colors.accent,
      );
    }

    return Icon(
      Icons.picture_as_pdf_rounded,
      size: 28,
      color: colors.accent,
    );
  }

  String _formatByteSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
