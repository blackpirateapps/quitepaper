import 'package:flutter/material.dart';
import '../../application/rich_document_controller.dart';
import 'block_editor_surface.dart';

/// Complete editorial block writing surface for Quiet Paper's Visual mode.
///
/// Dispatches rendering and interaction to [BlockEditorSurface], where each
/// structural block is an autonomous, independent Flutter component wrapped
/// in quiet gutter affordances.
class RichEditorSurface extends StatelessWidget {
  const RichEditorSurface({
    super.key,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.hintText = 'Start writing...',
    this.searchQuery,
    this.noteId,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onKeyEvent,
  });

  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String hintText;
  final String? searchQuery;
  final String? noteId;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return BlockEditorSurface(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      hintText: hintText,
      searchQuery: searchQuery,
      noteId: noteId,
      onActiveTargetChanged: onActiveTargetChanged,
      onChanged: onChanged,
      onKeyEvent: onKeyEvent,
    );
  }
}
