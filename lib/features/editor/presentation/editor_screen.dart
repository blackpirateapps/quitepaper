import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/markdown/markdown_preview.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/domain/note_model.dart';
import '../application/editor_provider.dart';
import 'widgets/editor_stats_dialog.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/tag_editor_bar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.note,
    this.autoFocusBody = false,
  });

  final Note note;
  final bool autoFocusBody;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();

    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onContentChanged);

    if (widget.autoFocusBody) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.note.title.isEmpty) {
            _titleFocusNode.requestFocus();
          } else {
            _contentFocusNode.requestFocus();
          }
        }
      });
    }
  }

  void _onTitleChanged() {
    ref
        .read(editorProviderFamily(widget.note).notifier)
        .updateTitle(_titleController.text);
  }

  void _onContentChanged() {
    ref
        .read(editorProviderFamily(widget.note).notifier)
        .updateContent(_contentController.text);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProviderFamily(widget.note));
    final editorNotifier =
        ref.read(editorProviderFamily(widget.note).notifier);
    final colors = context.appColors;
    final note = editorState.note;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          editorNotifier.saveNow();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: QuietIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () {
              editorNotifier.saveNow();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            // Subtle autosave status indicator
            if (editorState.isSaving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Center(
                  child: Text(
                    'Saving...',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ),

            // Markdown preview toggle
            QuietIconButton(
              icon: editorState.isPreviewMode
                  ? Icons.edit_outlined
                  : Icons.remove_red_eye_outlined,
              tooltip: editorState.isPreviewMode
                  ? 'Switch to edit'
                  : 'Markdown preview',
              isActive: editorState.isPreviewMode,
              onPressed: editorNotifier.togglePreviewMode,
            ),

            // Pin / unpin action
            QuietIconButton(
              icon: note.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              tooltip: note.isPinned ? 'Unpin' : 'Pin',
              isActive: note.isPinned,
              onPressed: editorNotifier.togglePinned,
            ),

            // More options menu
            QuietIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More options',
              onPressed: () => _showOverflowMenu(context, note, editorNotifier),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxEditorWidth,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (editorState.isPreviewMode) ...[
                            // Rendered preview mode
                            if (note.title.trim().isNotEmpty) ...[
                              Text(
                                note.title,
                                style: AppTypography.editorTitle.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (note.tags.isNotEmpty) ...[
                              TagEditorBar(
                                tags: note.tags,
                                onAddTag: editorNotifier.addTag,
                                onRemoveTag: editorNotifier.removeTag,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            QuietMarkdownPreview(
                              markdownData: note.content,
                            ),
                          ] else ...[
                            // Title input
                            TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              style: AppTypography.editorTitle.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: AppTypography.editorTitle.copyWith(
                                  color: colors.textTertiary.withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _contentFocusNode.requestFocus();
                              },
                            ),
                            const SizedBox(height: AppSpacing.xs),

                            // Tags bar
                            TagEditorBar(
                              tags: note.tags,
                              onAddTag: editorNotifier.addTag,
                              onRemoveTag: editorNotifier.removeTag,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Body markdown editor
                            TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              style: AppTypography.editorBody.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Start writing...',
                                hintStyle: AppTypography.editorBody.copyWith(
                                  color: colors.textTertiary.withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 120),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Formatting Toolbar (only visible in edit mode)
              if (!editorState.isPreviewMode)
                FormattingToolbar(
                  controller: _contentController,
                  onTagPressed: () {
                    // Insert # at current selection
                    final val = _contentController.value;
                    final text = val.text;
                    final sel = val.selection;
                    final start = sel.isValid ? sel.start : text.length;
                    final newText = text.replaceRange(start, start, '#');
                    _contentController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: start + 1),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverflowMenu(
    BuildContext context,
    Note note,
    EditorNotifier notifier,
  ) {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    note.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    note.isPinned ? 'Unpin note' : 'Pin note',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    notifier.togglePinned();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Note details',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (_) => EditorStatsDialog(note: note),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.copy_rounded,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Copy markdown',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(
                      ClipboardData(
                        text: '${note.title}\n\n${note.content}'.trim(),
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    'Delete note',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await notifier.deleteNote();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Note deleted'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
