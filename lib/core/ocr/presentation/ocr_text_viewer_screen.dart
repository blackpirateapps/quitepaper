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
/// Features selectable text, page boundaries, copy all/selection, language configuration,
/// and on-demand OCR regeneration.
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
  OcrDocument? _ocrDocument;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOcrDocument();
  }

  Future<void> _loadOcrDocument() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final processingService = ref.read(documentProcessingServiceProvider);
      final doc = await processingService.getDecryptedOcrDocument(widget.documentId);

      if (mounted) {
        setState(() {
          _ocrDocument = doc;
          _isLoading = false;
          if (doc == null) {
            _errorMessage = 'No OCR text available for this document.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to decrypt OCR text: $e';
        });
      }
    }
  }

  Future<void> _handleCopyAll() async {
    final doc = _ocrDocument;
    if (doc == null || doc.pages.isEmpty) return;

    final copyText = doc.formattedCopyText;
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
      initialLanguage: _ocrDocument?.language,
    );

    if (newLanguage != null && mounted) {
      if (widget.pdfBytes != null) {
        await _handleRegenerateOcr(language: newLanguage);
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
      final lang = language ?? _ocrDocument?.language ?? OcrLanguage.english;
      final service = ref.read(documentProcessingServiceProvider);

      await service.regenerateOcr(
        documentId: widget.documentId,
        pdfBytes: widget.pdfBytes!,
        source: widget.source,
        language: lang,
      );

      await _loadOcrDocument();

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
    final doc = _ocrDocument;
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
            if (doc != null)
              Text(
                '${doc.pages.length} ${doc.pages.length == 1 ? 'page' : 'pages'} • OCR (${doc.language.displayName})',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          if (doc != null && doc.pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy all OCR text',
              onPressed: _handleCopyAll,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'OCR options',
            onSelected: (value) {
              switch (value) {
                case 'copy_all':
                  _handleCopyAll();
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
              if (doc != null && doc.pages.isNotEmpty)
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
              _isProcessing ? 'Processing OCR text…' : 'Decrypting OCR text…',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final doc = _ocrDocument;
    if (doc == null || doc.pages.isEmpty) {
      return _buildErrorState(colors);
    }

    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 720 : double.infinity,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            itemCount: doc.pages.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
            itemBuilder: (context, index) {
              final page = doc.pages[index];
              return _buildPageSection(colors, page);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageSection(AppColors colors, OcrPage page) {
    final isTextEmpty = page.plainText.trim().isEmpty;

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
          // Page Header with divider
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
                      'Page ${page.pageNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'Copy page text',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: colors.textSecondary,
                onPressed: () => _handleCopyPage(page),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Page Body Text
          if (isTextEmpty)
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
