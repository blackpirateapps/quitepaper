import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_attachment_card.dart';
import 'package:quitepaper/core/audio/application/audio_transcript_markdown_helper.dart';
import 'package:quitepaper/core/documents/presentation/quiet_document_card.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

/// A block [DocumentNode] that embeds a Quiet Paper document or generic file
/// attachment as a rich card inside SuperEditor.
///
/// Unlike [ImageNode] (which is reserved for `![alt](url)` image syntax), this
/// node represents a *link-form* reference — `[name](qp://document/<UUID>)` or
/// `[name](qp://asset/<UUID>)` — and always serializes back to that exact link
/// form (see [QuietAttachmentNodeSerializer]). That keeps the persisted
/// Markdown byte-compatible with the Markdown preview, cloud sync, and the
/// other editor surfaces.
@immutable
class QuietAttachmentNode extends BlockNode {
  QuietAttachmentNode({
    required this.id,
    required this.uri,
    required this.displayText,
    this.transcript,
    this.transcriptLanguage,
    this.isTranscriptEdited = false,
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution('quietAttachment')});
  }

  @override
  final String id;

  /// The canonical `qp://document/<UUID>` or `qp://asset/<UUID>` URI.
  final String uri;

  /// The Markdown link display text (e.g. the document title or file name).
  final String displayText;

  /// Associated transcript text if this is a voice recording.
  final String? transcript;

  /// Language code of the recognized transcript (e.g. 'en').
  final String? transcriptLanguage;

  /// Whether the transcript was modified manually by the user.
  final bool isTranscriptEdited;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception(
        'QuietAttachmentNode can only copy content from a UpstreamDownstreamNodeSelection.',
      );
    }
    return !selection.isCollapsed
        ? AudioTranscriptMarkdownHelper.serializeAudioMarkdown(
            displayText: displayText,
            uri: uri,
            transcript: transcript,
            language: transcriptLanguage,
            isEdited: isTranscriptEdited,
          )
        : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is QuietAttachmentNode &&
        uri == other.uri &&
        displayText == other.displayText &&
        transcript == other.transcript &&
        transcriptLanguage == other.transcriptLanguage &&
        isTranscriptEdited == other.isTranscriptEdited;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      transcript: transcript,
      transcriptLanguage: transcriptLanguage,
      isTranscriptEdited: isTranscriptEdited,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      transcript: transcript,
      transcriptLanguage: transcriptLanguage,
      isTranscriptEdited: isTranscriptEdited,
      metadata: newMetadata,
    );
  }

  QuietAttachmentNode copy() {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      transcript: transcript,
      transcriptLanguage: transcriptLanguage,
      isTranscriptEdited: isTranscriptEdited,
      metadata: Map.from(metadata),
    );
  }

  QuietAttachmentNode copyWith({
    String? id,
    String? uri,
    String? displayText,
    String? transcript,
    String? transcriptLanguage,
    bool? isTranscriptEdited,
    bool clearTranscript = false,
    Map<String, dynamic>? metadata,
  }) {
    return QuietAttachmentNode(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      displayText: displayText ?? this.displayText,
      transcript: clearTranscript ? null : (transcript ?? this.transcript),
      transcriptLanguage:
          clearTranscript ? null : (transcriptLanguage ?? this.transcriptLanguage),
      isTranscriptEdited:
          clearTranscript ? false : (isTranscriptEdited ?? this.isTranscriptEdited),
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietAttachmentNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri &&
          displayText == other.displayText &&
          transcript == other.transcript &&
          transcriptLanguage == other.transcriptLanguage &&
          isTranscriptEdited == other.isTranscriptEdited;

  @override
  int get hashCode => Object.hash(
        id,
        uri,
        displayText,
        transcript,
        transcriptLanguage,
        isTranscriptEdited,
      );
}

/// Block type ids that must never be promoted to an attachment card even when
/// their text happens to be a single link (headings, quotes, code blocks).
const Set<String> _nonPromotableBlockTypes = {
  'header1',
  'header2',
  'header3',
  'header4',
  'header5',
  'header6',
  'blockquote',
  'code',
};

/// Returns the sole whole-paragraph `qp://document|asset` link in [node], or
/// `null` if [node] is not a plain paragraph consisting of exactly one such
/// link. Used to decide whether a deserialized paragraph should become an
/// embedded attachment card.
({String uri, String text})? _soleQuietLinkOf(ParagraphNode node) {
  final blockType = node.getMetadataValue(NodeMetadata.blockType);
  if (blockType is NamedAttribution && _nonPromotableBlockTypes.contains(blockType.id)) {
    return null;
  }

  final plain = node.text.toPlainText();
  if (plain.trim().isEmpty) return null;

  final spans = node.text.getAttributionSpansByFilter((a) => a is LinkAttribution);
  if (spans.length != 1) return null;

  final span = spans.first;
  // The link must cover the whole paragraph (end offset is inclusive).
  if (span.start != 0 || span.end != plain.length - 1) return null;

  final link = span.attribution as LinkAttribution;
  final qp = QuietPaperUri.tryParse(link.plainTextUri);
  if (qp == null || !(qp.isDocument || qp.isAsset)) return null;

  return (uri: link.plainTextUri, text: plain);
}

/// Walks [document] and replaces every paragraph that is exactly a single
/// `[name](qp://document|asset/<UUID>)` link with a [QuietAttachmentNode], so
/// link-form documents and generic files render as embedded cards instead of
/// inline hyperlinks. Also absorbs any companion transcript blockquote directly
/// following an audio recording card.
void promoteQuietAttachmentNodes(MutableDocument document) {
  final promotions = <({
    String paragraphId,
    String uri,
    String text,
    String? transcript,
    String? transcriptLanguage,
    bool isTranscriptEdited,
    List<String> absorbedNodeIds,
  })>[];

  final nodes = document.toList();
  for (int i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is! ParagraphNode) continue;
    final link = _soleQuietLinkOf(node);
    if (link == null) continue;

    final qp = QuietPaperUri.tryParse(link.uri);
    final hasTranscriptParam = qp != null &&
        (qp.parameters['transcript'] == '1' || qp.parameters['transcript'] == 'true');

    String? transcript;
    String? transcriptLanguage = qp?.parameters['lang'];
    bool isTranscriptEdited =
        qp?.parameters['edited'] == '1' || qp?.parameters['edited'] == 'true';
    final absorbedNodeIds = <String>[];

    if (hasTranscriptParam) {
      final transcriptParts = <String>[];
      int j = i + 1;
      while (j < nodes.length) {
        final nextNode = nodes[j];
        if (nextNode is ParagraphNode) {
          final blockType = nextNode.getMetadataValue(NodeMetadata.blockType);
          final isBlockquote = blockType is NamedAttribution && blockType.id == 'blockquote';
          if (isBlockquote) {
            transcriptParts.add(nextNode.text.toPlainText());
            absorbedNodeIds.add(nextNode.id);
            j++;
            continue;
          }
        }
        break;
      }
      if (transcriptParts.isNotEmpty) {
        transcript = transcriptParts.join('\n\n');
      }
    }

    final cleanUri = (qp != null)
        ? QuietPaperUri(resourceType: qp.resourceType, resourceId: qp.resourceId).toUriString()
        : link.uri;

    promotions.add((
      paragraphId: node.id,
      uri: cleanUri,
      text: link.text,
      transcript: transcript,
      transcriptLanguage: transcriptLanguage,
      isTranscriptEdited: isTranscriptEdited,
      absorbedNodeIds: absorbedNodeIds,
    ));
  }

  for (final promo in promotions) {
    document.replaceNodeById(
      promo.paragraphId,
      QuietAttachmentNode(
        id: promo.paragraphId,
        uri: promo.uri,
        displayText: promo.text,
        transcript: promo.transcript,
        transcriptLanguage: promo.transcriptLanguage,
        isTranscriptEdited: promo.isTranscriptEdited,
      ),
    );
    for (final absorbedId in promo.absorbedNodeIds) {
      document.deleteNode(absorbedId);
    }
  }
}

/// [ComponentBuilder] that renders [QuietAttachmentNode]s as embedded document
/// or file cards with a "remove from note" affordance.
class QuietAttachmentComponentBuilder implements ComponentBuilder {
  QuietAttachmentComponentBuilder({
    required this.editor,
    this.noteId,
    this.showRemove = true,
  });

  final Editor editor;
  final String? noteId;
  final bool showRemove;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! QuietAttachmentNode) {
      return null;
    }

    return QuietAttachmentComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      uri: node.uri,
      displayText: node.displayText,
      transcript: node.transcript,
      transcriptLanguage: node.transcriptLanguage,
      isTranscriptEdited: node.isTranscriptEdited,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! QuietAttachmentComponentViewModel) {
      return null;
    }

    final node = editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! QuietAttachmentNode) {
      return null;
    }

    return QuietAttachmentComponent(
      key: ValueKey('quiet_attachment_${componentViewModel.nodeId}'),
      componentKey: componentContext.componentKey,
      node: node,
      editor: editor,
      noteId: noteId,
      showRemove: showRemove,
    );
  }
}

/// View model backing a [QuietAttachmentComponent].
class QuietAttachmentComponentViewModel extends SingleColumnLayoutComponentViewModel {
  QuietAttachmentComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.uri,
    required this.displayText,
    this.transcript,
    this.transcriptLanguage,
    this.isTranscriptEdited = false,
  });

  String uri;
  String displayText;
  String? transcript;
  String? transcriptLanguage;
  bool isTranscriptEdited;

  @override
  QuietAttachmentComponentViewModel copy() {
    return QuietAttachmentComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      uri: uri,
      displayText: displayText,
      transcript: transcript,
      transcriptLanguage: transcriptLanguage,
      isTranscriptEdited: isTranscriptEdited,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietAttachmentComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          uri == other.uri &&
          displayText == other.displayText &&
          transcript == other.transcript &&
          transcriptLanguage == other.transcriptLanguage &&
          isTranscriptEdited == other.isTranscriptEdited;

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        nodeId,
        uri,
        displayText,
        transcript,
        transcriptLanguage,
        isTranscriptEdited,
      );
}

/// A document component that renders a [QuietAttachmentNode] as an embedded
/// [QuietDocumentCard] or [QuietAttachmentCard]. Tapping the card opens it
/// (handled by the cards themselves); a small corner control removes the block
/// from the note.
class QuietAttachmentComponent extends ConsumerWidget {
  const QuietAttachmentComponent({
    super.key,
    required this.componentKey,
    required this.node,
    required this.editor,
    this.noteId,
    this.showRemove = true,
  });

  final GlobalKey componentKey;
  final QuietAttachmentNode node;
  final Editor editor;
  final String? noteId;
  final bool showRemove;

  void _remove(WidgetRef ref) {
    editor.execute([DeleteNodeRequest(nodeId: node.id)]);
    final qp = QuietPaperUri.tryParse(node.uri);
    if (qp != null && qp.isAsset) {
      try {
        ref.read(attachmentServiceProvider).deleteAttachment(qp.resourceId);
      } catch (e) {
        debugPrint('[QuietAttachmentComponent] Failed to delete attachment ${qp.resourceId}: $e');
      }
    }
  }

  void _insertTranscriptAfterCard(String transcriptText) {
    final doc = editor.document;
    final index = doc.getNodeIndexById(node.id);
    final newNodeId = 'transcript_${DateTime.now().microsecondsSinceEpoch}';
    final paragraphNode = ParagraphNode(
      id: newNodeId,
      text: AttributedText(transcriptText),
    );

    if (index != -1 && index < doc.nodeCount - 1) {
      final nextNode = doc.getNodeAt(index + 1);
      if (nextNode != null) {
        editor.execute([
          InsertNodeBeforeNodeRequest(
            existingNodeId: nextNode.id,
            newNode: paragraphNode,
          ),
        ]);
        return;
      }
    }
    editor.execute([
      InsertNodeAfterNodeRequest(
        existingNodeId: node.id,
        newNode: paragraphNode,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final qp = QuietPaperUri.tryParse(node.uri);

    final Widget card;
    if (qp != null && qp.isDocument) {
      card = QuietDocumentCard(
        documentId: qp.resourceId,
        title: node.displayText,
        uriString: node.uri,
      );
    } else if (qp != null && qp.isAsset) {
      card = QuietAttachmentCard(
        attachmentId: qp.resourceId,
        title: node.displayText,
        uriString: node.uri,
        initialTranscript: node.transcript,
        initialTranscriptLanguage: node.transcriptLanguage,
        initialIsTranscriptEdited: node.isTranscriptEdited,
        onTranscriptChanged: (newTranscript, isEdited) {
          editor.execute([
            ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: node.copyWith(
                transcript: newTranscript,
                isTranscriptEdited: isEdited,
              ),
            ),
          ]);
        },
        onInsertTranscript: _insertTranscriptAfterCard,
        onAttachmentRenamed: (id, newTitle) {
          editor.execute([
            ReplaceNodeRequest(
              existingNodeId: node.id,
              newNode: node.copyWith(
                displayText: newTitle,
              ),
            ),
          ]);
        },
        onAttachmentDeleted: (id) {
          _remove(ref);
        },
      );
    } else {
      card = _FallbackAttachmentCard(displayText: node.displayText, uri: node.uri);
    }

    return BoxComponent(
      key: componentKey,
      child: Stack(
        children: [
          card,
          if (showRemove)
            Positioned(
              top: 2,
              right: 4,
              child: Tooltip(
                message: 'Remove from note',
                child: Material(
                  color: colors.surface,
                  shape: CircleBorder(side: BorderSide(color: colors.divider, width: 0.8)),
                  elevation: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _remove(ref),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(PhosphorIconsRegular.x, size: 13, color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Minimal fallback card shown when a [QuietAttachmentNode]'s URI can't be
/// resolved to a known resource type.
class _FallbackAttachmentCard extends StatelessWidget {
  const _FallbackAttachmentCard({required this.displayText, required this.uri});

  final String displayText;
  final String uri;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.paperclip, size: 20, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayText.isNotEmpty ? displayText : uri,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Serializes a [QuietAttachmentNode] back to its canonical Markdown link form
/// (`[name](qp://...)`), guaranteeing a blank line before any following node so
/// the block round-trips cleanly through [deserializeMarkdownToDocument].
class QuietAttachmentNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<QuietAttachmentNode> {
  const QuietAttachmentNodeSerializer();

  @override
  String doSerialization(
    Document document,
    QuietAttachmentNode node, {
    NodeSelection? selection,
  }) {
    final buffer = StringBuffer();
    final serialized = AudioTranscriptMarkdownHelper.serializeAudioMarkdown(
      displayText: node.displayText,
      uri: node.uri,
      transcript: node.transcript,
      language: node.transcriptLanguage,
      isEdited: node.isTranscriptEdited,
    );
    buffer.write(serialized);

    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }
}
