import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import '../../../application/quiet_super_editor_controller.dart';
import '../link_enhance_button.dart';

/// A [SuperEditorLayerBuilder] that places interactive [LinkEnhanceButton]s
/// adjacent to hyperlinks within SuperEditor.
class LinkEnhanceDocumentLayerBuilder implements SuperEditorLayerBuilder {
  const LinkEnhanceDocumentLayerBuilder({
    this.controller,
    this.readOnly = false,
  });

  final QuietSuperEditorController? controller;
  final bool readOnly;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    if (readOnly) return const ContentLayerProxyWidget(child: SizedBox());

    return LinkEnhanceDocumentLayer(
      document: editContext.document,
      documentLayoutResolver: () => editContext.documentLayout,
      controller: controller,
    );
  }
}

/// Document overlay layer widget rendering link enhancement sparkle buttons
/// positioned at the trailing edge of web links in SuperEditor.
class LinkEnhanceDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const LinkEnhanceDocumentLayer({
    super.key,
    required this.document,
    required this.documentLayoutResolver,
    this.controller,
  });

  final Document document;
  final DocumentLayout Function() documentLayoutResolver;
  final QuietSuperEditorController? controller;

  @override
  DocumentLayoutLayerState<LinkEnhanceDocumentLayer, List<({String url, Rect rect})>>
      createState() => _LinkEnhanceDocumentLayerState();
}

class _LinkEnhanceDocumentLayerState extends DocumentLayoutLayerState<
    LinkEnhanceDocumentLayer, List<({String url, Rect rect})>> {
  @override
  void initState() {
    super.initState();
    widget.document.addListener(_onDocumentChange);
  }

  @override
  void didUpdateWidget(LinkEnhanceDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChange);
    super.dispose();
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    setState(() {});
  }

  @override
  List<({String url, Rect rect})> computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final results = <({String url, Rect rect})>[];

    for (final node in widget.document) {
      if (node is! TextNode) continue;
      final text = node.text;
      final spans = text.getAttributionSpansByFilter((a) => a is LinkAttribution);
      for (final span in spans) {
        final linkAttr = span.attribution as LinkAttribution;
        final urlString = linkAttr.plainTextUri;
        if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
          continue;
        }

        final endOffset = (span.end).clamp(0, text.length);
        final pos = DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: endOffset),
        );

        final edge = documentLayout.getEdgeForPosition(pos);
        if (edge != null) {
          results.add((url: urlString, rect: edge));
        }
      }
    }

    return results;
  }

  @override
  Widget doBuild(BuildContext context, List<({String url, Rect rect})>? data) {
    if (data == null || data.isEmpty) {
      return const SizedBox();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final item in data)
          Positioned(
            left: item.rect.right + 2.0,
            top: item.rect.top,
            child: LinkEnhanceButton(
              url: item.url,
              onEnhanced: (newTitle) async {
                widget.controller?.replaceLinkDisplayText(item.url, newTitle, force: true);
              },
            ),
          ),
      ],
    );
  }
}
