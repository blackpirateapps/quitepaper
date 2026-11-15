import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/presentation/quiet_asset_image_view.dart';
import '../../../../core/documents/document_provider.dart';
import '../../../../core/documents/document_service.dart';
import '../../../../core/markdown/markdown_preview.dart';
import '../../../../core/uri/resource_resolver.dart';
import '../../domain/search_result.dart';

/// Reading surface without editor controllers, autosave, or mutation callbacks.
class SearchResultPreview extends StatelessWidget {
  const SearchResultPreview({
    super.key,
    required this.result,
    required this.query,
    required this.onOpen,
    required this.onEdit,
  });

  final SearchResultItem result;
  final String query;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final note = result is NoteSearchMatch ? result as NoteSearchMatch : null;
    final document = result is DocumentSearchMatch
        ? result as DocumentSearchMatch
        : null;
    final title = note?.note.displayTitle ?? document!.displayTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Preview',
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open'),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: note != null
              ? note.note.isPasswordProtected
                    ? const Center(child: Text('Open this note to unlock it.'))
                    : QuietMarkdownPreview(
                        key: ValueKey('preview-note-${note.note.id}'),
                        markdownData: note.note.content,
                        title: title,
                        tags: note.note.tags,
                        searchQuery: query,
                        interactiveChecklists: false,
                        padding: const EdgeInsets.all(24),
                      )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (document!.parentNoteTitle?.isNotEmpty ?? false)
                            Text(
                              'In: ${document.parentNoteTitle}',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          if (document.matchedPageNumber > 0)
                            Text(
                              'Page ${document.matchedPageNumber}',
                              style: TextStyle(color: colors.textTertiary),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: document.isAttachment
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  IgnorePointer(
                                    child: QuietAssetImageView(
                                      assetId: document.id,
                                      altText: title,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SelectableText(document.snippet),
                                ],
                              ),
                            )
                          : _DocumentPreview(
                              key: ValueKey(
                                'preview-document-${document.id}-${document.matchedPageNumber}',
                              ),
                              match: document,
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DocumentPreview extends ConsumerStatefulWidget {
  const _DocumentPreview({super.key, required this.match});
  final DocumentSearchMatch match;

  @override
  ConsumerState<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends ConsumerState<_DocumentPreview> {
  late final Future<ResourceResolution<ResolvedDocumentInfo>> _document;

  @override
  void initState() {
    super.initState();
    _document = ref
        .read(documentServiceProvider)
        .resolveDocument(widget.match.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResourceResolution<ResolvedDocumentInfo>>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final resolution = snapshot.data;
        final info = resolution?.data;
        if (resolution?.isAvailable == true &&
            info != null &&
            !DocumentService.isHtmlDocumentPayload(
              bytes: info.pdfBytes,
              title: info.title,
              source: info.source,
            )) {
          return SfPdfViewer.memory(
            info.pdfBytes,
            initialPageNumber: widget.match.matchedPageNumber > 0
                ? widget.match.matchedPageNumber.clamp(
                    1,
                    info.pageCount > 0 ? info.pageCount : 1,
                  )
                : 1,
            canShowTextSelectionMenu: false,
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolution?.isLocked == true
                    ? 'Open this document to unlock it.'
                    : info != null
                    ? 'Open to view the web snapshot.'
                    : 'Document preview unavailable. Open to try again.',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SelectableText(widget.match.snippet),
            ],
          ),
        );
      },
    );
  }
}
