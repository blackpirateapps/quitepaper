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

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    _scrollController = ScrollController();

    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onContentChanged);

    _titleFocusNode.addListener(_onFocusChanged);
    _contentFocusNode.addListener(_onFocusChanged);

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(editorProviderFamily(widget.note).notifier).saveNow();
    }
  }

  void _onFocusChanged() {
    if (!_titleFocusNode.hasFocus && !_contentFocusNode.hasFocus) {
      ref.read(editorProviderFamily(widget.note).notifier).saveNow();
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
    WidgetsBinding.instance.removeObserver(this);
    _titleController.removeListener(_onTitleChanged);
    _contentController.removeListener(_onContentChanged);
    _titleFocusNode.removeListener(_onFocusChanged);
    _contentFocusNode.removeListener(_onFocusChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
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
          editorNotifier.handleExitCleanup();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: QuietIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () {
              editorNotifier.handleExitCleanup();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            QuietIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More options',
              onPressed: () => _showOverflowMenu(context, note, editorNotifier),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxContentWidth,
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (editorState.isPreviewMode) ...[
                            // Rendered Markdown preview mode
                            if (note.title.trim().isNotEmpty) ...[
                              Text(
                                note.title,
                                style: AppTypography.editorTitle.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 24.0),
                            ],
                            if (note.tags.isNotEmpty) ...[
                              TagEditorBar(
                                tags: note.tags,
                                onAddTag: editorNotifier.addTag,
                                onRemoveTag: editorNotifier.removeTag,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            QuietMarkdownPreview(
                              markdownData: note.content,
                            ),
                          ] else ...[
                            // Document Title input
                            TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              cursorColor: colors.accent,
                              style: AppTypography.editorTitle.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: AppTypography.editorTitle.copyWith(
                                  color: colors.textTertiary.withValues(alpha: 0.4),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) {
                                _contentFocusNode.requestFocus();
                              },
                            ),
                            const SizedBox(height: 20.0),

                            // Tags bar (displayed seamlessly if tags exist)
                            if (note.tags.isNotEmpty) ...[
                              TagEditorBar(
                                tags: note.tags,
                                onAddTag: editorNotifier.addTag,
                                onRemoveTag: editorNotifier.removeTag,
                              ),
                              const SizedBox(height: 12.0),
                            ],

                            // Body markdown editor
                            TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              cursorColor: colors.accent,
                              style: AppTypography.editorBody.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Start writing...',
                                hintStyle: AppTypography.editorBody.copyWith(
                                  color: colors.textTertiary.withValues(alpha: 0.4),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            // Generous bottom scroll area for comfortable typing above keyboard
                            const SizedBox(height: 280),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating/Docked formatting toolbar (only in edit mode)
              if (!editorState.isPreviewMode)
                FormattingToolbar(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  onTagPressed: () {
                    final val = _contentController.value;
                    final text = val.text;
                    final sel = val.selection;
                    final start = sel.isValid ? sel.start : text.length;
                    final newText = text.replaceRange(start, start, '#');
                    _contentController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: start + 1),
                    );
                    if (!_contentFocusNode.hasFocus) {
                      _contentFocusNode.requestFocus();
                    }
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
    final isPreview = ref.read(editorProviderFamily(widget.note)).isPreviewMode;

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
                    isPreview ? Icons.edit_outlined : Icons.remove_red_eye_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    isPreview ? 'Switch to edit' : 'Markdown preview',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    notifier.togglePreviewMode();
                  },
                ),
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
                    Icons.tag_rounded,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Add tag',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    TagEditorBar.showAddTagDialog(context, notifier.addTag);
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
