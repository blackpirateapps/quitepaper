import 'package:flutter/material.dart';
import '../../markdown/markdown_preview.dart';
import '../text/attachment_text_detector.dart';
import 'plain_text_viewer.dart';

/// Presentation mode for Markdown attachments.
enum MarkdownViewMode {
  rendered,
  source,
}

/// Read-only viewer for Markdown attachments supporting both Rendered (rich preview)
/// and Source (raw text with search, line numbers, and word wrap) presentation modes.
class MarkdownAttachmentViewer extends StatefulWidget {
  const MarkdownAttachmentViewer({
    super.key,
    required this.markdownData,
    required this.mode,
    this.searchQuery,
    this.currentMatchIndex = 0,
    this.onMatchesCountChanged,
    this.wordWrap,
    this.showLineNumbers,
    this.scrollController,
  });

  final String markdownData;
  final MarkdownViewMode mode;
  final String? searchQuery;
  final int currentMatchIndex;
  final ValueChanged<int>? onMatchesCountChanged;
  final bool? wordWrap;
  final bool? showLineNumbers;
  final ScrollController? scrollController;

  @override
  State<MarkdownAttachmentViewer> createState() => _MarkdownAttachmentViewerState();
}

class _MarkdownAttachmentViewerState extends State<MarkdownAttachmentViewer> {
  @override
  Widget build(BuildContext context) {
    if (widget.mode == MarkdownViewMode.rendered) {
      return QuietMarkdownPreview(
        markdownData: widget.markdownData,
        scrollController: widget.scrollController,
        selectable: true,
        searchQuery: widget.searchQuery,
        softLineBreak: true,
      );
    }

    return PlainTextViewer(
      text: widget.markdownData,
      format: TextAttachmentFormat.markdown,
      isMonospaced: false,
      showLineNumbers: widget.showLineNumbers ?? false,
      wordWrap: widget.wordWrap ?? true,
      searchQuery: widget.searchQuery,
      currentMatchIndex: widget.currentMatchIndex,
      onMatchesCountChanged: widget.onMatchesCountChanged,
      scrollController: widget.scrollController,
    );
  }
}
