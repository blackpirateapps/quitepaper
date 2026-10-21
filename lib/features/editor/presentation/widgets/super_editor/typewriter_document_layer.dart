import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A [SuperEditorLayerBuilder] that tracks the active caret position in SuperEditor
/// and notifies the typewriter scrolling coordinator.
class TypewriterDocumentLayerBuilder implements SuperEditorLayerBuilder {
  const TypewriterDocumentLayerBuilder({
    required this.onCaretGlobalPosition,
  });

  final ValueChanged<Offset> onCaretGlobalPosition;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    return TypewriterDocumentLayer(
      composer: editContext.composer,
      documentLayoutResolver: () => editContext.documentLayout,
      onCaretGlobalPosition: onCaretGlobalPosition,
    );
  }
}

/// Overlay layer that computes the active caret's global screen coordinate from
/// SuperEditor's [DocumentLayout].
class TypewriterDocumentLayer extends DocumentLayoutLayerStatefulWidget {
  const TypewriterDocumentLayer({
    super.key,
    required this.composer,
    required this.documentLayoutResolver,
    required this.onCaretGlobalPosition,
  });

  final DocumentComposer composer;
  final DocumentLayout Function() documentLayoutResolver;
  final ValueChanged<Offset> onCaretGlobalPosition;

  @override
  DocumentLayoutLayerState<TypewriterDocumentLayer, Rect?> createState() =>
      _TypewriterDocumentLayerState();
}

class _TypewriterDocumentLayerState
    extends DocumentLayoutLayerState<TypewriterDocumentLayer, Rect?> {
  @override
  void initState() {
    super.initState();
    widget.composer.selectionNotifier.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(TypewriterDocumentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_onSelectionChanged);
      widget.composer.selectionNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {});
  }

  @override
  Rect? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final selection = widget.composer.selection;
    if (selection == null) return null;

    final caretEdge = documentLayout.getEdgeForPosition(selection.extent);
    if (caretEdge == null) return null;

    final renderObj = context.findRenderObject();
    if (renderObj is RenderBox && renderObj.hasSize) {
      final globalPos = renderObj.localToGlobal(caretEdge.center);
      widget.onCaretGlobalPosition(globalPos);
    }

    return caretEdge;
  }

  @override
  Widget doBuild(BuildContext context, Rect? layoutData) {
    return const SizedBox();
  }
}
