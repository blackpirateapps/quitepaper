import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/markdown/markdown_preview.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../application/editor_provider.dart';
import '../application/markdown_editing_controller.dart';
import 'widgets/editor_stats_dialog.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/markdown_editor.dart';
import 'widgets/tag_editor_bar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.note,
    this.autoFocusBody = false,
    this.initialPreviewMode = false,
    this.onClose,
  });

  final Note note;
  final bool autoFocusBody;
  final bool initialPreviewMode;
  final VoidCallback? onClose;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final MarkdownEditingController _contentController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  late final ScrollController _scrollController;

  bool _isTitleManuallySet = false;
  String _lastAutoDerivedTitle = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isTitleManuallySet = widget.note.title.trim().isNotEmpty;
    _lastAutoDerivedTitle = widget.note.title.isEmpty
        ? Note.deriveTitle(widget.note.content)
        : '';
    final initialTitle = widget.note.title.isNotEmpty
        ? widget.note.title
        : _lastAutoDerivedTitle;

    _titleController = TextEditingController(text: initialTitle);
    _contentController = MarkdownEditingController(text: widget.note.content);
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
          if (_titleController.text.isEmpty) {
            _titleFocusNode.requestFocus();
          } else {
            _contentFocusNode.requestFocus();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _isTitleManuallySet = widget.note.title.trim().isNotEmpty;
      _lastAutoDerivedTitle = widget.note.title.isEmpty
          ? Note.deriveTitle(widget.note.content)
          : '';
      final newTitle = widget.note.title.isNotEmpty
          ? widget.note.title
          : _lastAutoDerivedTitle;

      _titleController.text = newTitle;
      _contentController.text = widget.note.content;
      if (widget.autoFocusBody) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (_titleController.text.isEmpty) {
              _titleFocusNode.requestFocus();
            } else {
              _contentFocusNode.requestFocus();
            }
          }
        });
      }
    }
  }

  EditorParams get _editorParams => EditorParams(
        widget.note,
        initialPreviewMode: widget.initialPreviewMode,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(editorProviderFamily(_editorParams).notifier).saveNow();
    }
  }

  void _onFocusChanged() {
    if (!_titleFocusNode.hasFocus && !_contentFocusNode.hasFocus) {
      ref.read(editorProviderFamily(_editorParams).notifier).saveNow();
    }
  }

  void _onTitleChanged() {
    final currentTitle = _titleController.text;
    if (_titleFocusNode.hasFocus) {
      // User is actively editing the title field directly
      if (currentTitle != _lastAutoDerivedTitle) {
        _isTitleManuallySet = currentTitle.trim().isNotEmpty;
      }
      if (currentTitle.trim().isEmpty) {
        _isTitleManuallySet = false;
      }
    }
    ref
        .read(editorProviderFamily(_editorParams).notifier)
        .updateTitle(currentTitle);
  }

  void _onContentChanged() {
    final newContent = _contentController.text;
    ref
        .read(editorProviderFamily(_editorParams).notifier)
        .updateContent(newContent);

    // If user has not manually set a custom title, automatically fill title field from 1st line
    if (!_isTitleManuallySet) {
      final autoTitle = Note.deriveTitle(newContent);
      if (_titleController.text != autoTitle) {
        _lastAutoDerivedTitle = autoTitle;
        _titleController.text = autoTitle;
        ref
            .read(editorProviderFamily(_editorParams).notifier)
            .updateTitle(autoTitle);
      }
    }
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
    final editorState = ref.watch(editorProviderFamily(_editorParams));
    final editorNotifier =
        ref.read(editorProviderFamily(_editorParams).notifier);
    final colors = context.appColors;
    final note = editorState.note;

    final canPop = Navigator.of(context).canPop();

    final isNavSidebarVisible = ref.watch(isNavSidebarVisibleProvider);
    final isNoteListVisible = ref.watch(isNoteListVisibleProvider);
    final isTabletEditor = widget.onClose != null;
    final showSidebarRestore = isTabletEditor && (!isNavSidebarVisible || !isNoteListVisible);

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
          leadingWidth: showSidebarRestore ? 96.0 : null,
          leading: isTabletEditor
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSidebarRestore)
                      QuietIconButton(
                        icon: Icons.view_sidebar_outlined,
                        tooltip: 'Show sidebars',
                        onPressed: () {
                          ref.read(isNavSidebarVisibleProvider.notifier).state =
                              true;
                          ref.read(isNoteListVisibleProvider.notifier).state =
                              true;
                        },
                      ),
                    QuietIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close note',
                      onPressed: () {
                        editorNotifier.handleExitCleanup();
                        widget.onClose?.call();
                      },
                    ),
                  ],
                )
              : (canPop
                  ? QuietIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : null),
          actions: [
            if (isTabletEditor)
              QuietIconButton(
                icon: (!isNavSidebarVisible && !isNoteListVisible)
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: (!isNavSidebarVisible && !isNoteListVisible)
                    ? 'Exit focus mode'
                    : 'Focus mode (hide sidebars)',
                onPressed: () {
                  final currentlyCollapsed =
                      !isNavSidebarVisible && !isNoteListVisible;
                  ref.read(isNavSidebarVisibleProvider.notifier).state =
                      currentlyCollapsed;
                  ref.read(isNoteListVisibleProvider.notifier).state =
                      currentlyCollapsed;
                },
              ),
            if (!note.isTrashed)
              QuietIconButton(
                icon: editorState.isPreviewMode
                    ? Icons.edit_outlined
                    : Icons.remove_red_eye_outlined,
                tooltip: editorState.isPreviewMode ? 'Edit note' : 'Preview note',
                onPressed: () {
                  editorNotifier.togglePreviewMode();
                },
              ),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!editorState.isPreviewMode) {
                      if (!_contentFocusNode.hasFocus && !_titleFocusNode.hasFocus) {
                        if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
                          _titleFocusNode.requestFocus();
                        } else {
                          _contentFocusNode.requestFocus();
                        }
                      }
                    }
                  },
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.maxContentWidth,
                      ),
                      child: editorState.isPreviewMode
                          ? QuietMarkdownPreview(
                              markdownData: _contentController.text.isNotEmpty
                                  ? _contentController.text
                                  : note.content,
                              title: _titleController.text.isNotEmpty
                                  ? _titleController.text
                                  : note.title,
                              tags: note.tags,
                              onAddTag: editorNotifier.addTag,
                              onRemoveTag: editorNotifier.removeTag,
                              scrollController: _scrollController,
                            )
                          : SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                  MarkdownEditor(
                                    controller: _contentController,
                                    focusNode: _contentFocusNode,
                                  ),
                                  // Generous bottom scroll area for comfortable typing above keyboard
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (!_contentFocusNode.hasFocus) {
                                        _contentFocusNode.requestFocus();
                                      }
                                    },
                                    child: const SizedBox(height: 280),
                                  ),
                                ],
                              ),
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

  bool get isTabletEditor => widget.onClose != null;

  void _showOverflowMenu(
    BuildContext context,
    Note note,
    EditorNotifier notifier,
  ) {
    final colors = context.appColors;
    final isPreview = ref.read(editorProviderFamily(_editorParams)).isPreviewMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (!note.isTrashed) ...[
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
                ],
                if (note.isTrashed) ...[
                  // Trash actions: Restore, Delete Permanently
                  ListTile(
                    leading: Icon(
                      Icons.restore_rounded,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Restore note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await notifier.restoreNote();
                      if (context.mounted) {
                        if (isTabletEditor) {
                          widget.onClose?.call();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note restored'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Delete permanently',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: colors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(AppRadii.rLg),
                          ),
                          title: Text(
                            'Delete permanently?',
                            style: AppTypography.headline.copyWith(
                              color: colors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          content: Text(
                            'This note will be permanently deleted.\nThis action cannot be undone.',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: Text(
                                'Cancel',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              child: Text(
                                'Delete Permanently',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await notifier.deletePermanently();
                        if (context.mounted) {
                          if (isTabletEditor) {
                            widget.onClose?.call();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note permanently deleted'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ] else if (note.isArchived) ...[
                  // Archive actions: Unarchive, Move to Trash
                  ListTile(
                    leading: Icon(
                      Icons.unarchive_outlined,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Unarchive note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await notifier.unarchiveNote();
                      if (context.mounted) {
                        if (isTabletEditor) {
                          widget.onClose?.call();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note unarchived'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Move to Trash',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await notifier.trashNote();
                      if (context.mounted) {
                        if (isTabletEditor) {
                          widget.onClose?.call();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note moved to Trash'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ] else ...[
                  // Active note actions: Pin/Unpin, Archive, Move to Trash
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
                      Icons.archive_outlined,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Archive note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await notifier.archiveNote();
                      if (context.mounted) {
                        if (isTabletEditor) {
                          widget.onClose?.call();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note archived'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Move to Trash',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await notifier.trashNote();
                      if (context.mounted) {
                        if (isTabletEditor) {
                          widget.onClose?.call();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Note moved to Trash'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
                if (!note.isTrashed) ...[
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
                ],
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
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
