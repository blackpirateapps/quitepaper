import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/markdown/markdown_preview.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../application/editor_provider.dart';
import '../application/markdown_editing_controller.dart';
import 'widgets/editor_stats_dialog.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/in_note_search_bar.dart';
import 'widgets/markdown_editor.dart';
import 'widgets/password_unlock_view.dart';
import 'widgets/tag_editor_bar.dart';
import '../../notes/presentation/widgets/note_password_dialogs.dart';
import '../../settings/application/typography_provider.dart';
import '../domain/markdown_styles.dart';
import '../../../core/utils/font_family_helper.dart';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final MarkdownEditingController _contentController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  late final ScrollController _scrollController;

  // In-Note Search & Replace state & animations
  bool _isSearchVisible = false;
  bool _showReplace = false;
  late final TextEditingController _searchQueryController;
  late final FocusNode _searchQueryFocusNode;
  late final TextEditingController _replaceQueryController;
  late final FocusNode _replaceQueryFocusNode;
  late final AnimationController _searchAnimationController;
  late final Animation<double> _searchAnimation;
  late final Animation<Offset> _searchSlideAnimation;
  List<TextRange> _searchMatches = [];
  int _currentMatchIndex = 0;

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

    _searchQueryController = TextEditingController();
    _searchQueryFocusNode = FocusNode();
    _replaceQueryController = TextEditingController();
    _replaceQueryFocusNode = FocusNode();

    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.25),
      end: Offset.zero,
    ).animate(_searchAnimation);

    _searchQueryController.addListener(_onSearchQueryChanged);

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
      if (_isSearchVisible && _searchQueryController.text.isNotEmpty) {
        _recalculateMatches(_searchQueryController.text);
      }
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

    if (_isSearchVisible && _searchQueryController.text.isNotEmpty) {
      _recalculateMatches(_searchQueryController.text);
    }
  }

  void _openSearch({bool withReplace = false}) {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchVisible = true;
      if (withReplace) _showReplace = true;
    });
    _searchAnimationController.forward();

    final selection = _contentController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selected = _contentController.text
          .substring(selection.start, selection.end)
          .trim();
      if (selected.isNotEmpty && !selected.contains('\n')) {
        _searchQueryController.text = selected;
        _searchQueryController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: selected.length,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchQueryFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    if (_searchQueryFocusNode.hasFocus) {
      _searchQueryFocusNode.unfocus();
    }
    if (_replaceQueryFocusNode.hasFocus) {
      _replaceQueryFocusNode.unfocus();
    }
    _searchAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSearchVisible = false;
          _showReplace = false;
          _searchQueryController.clear();
          _replaceQueryController.clear();
          _searchMatches.clear();
          _currentMatchIndex = 0;
        });
        _contentController.setSearchHighlight(query: null, activeRange: null);
      }
    });
  }

  void _onSearchQueryChanged() {
    final query = _searchQueryController.text;
    _recalculateMatches(query);
  }

  void _recalculateMatches(String query) {
    final text = _contentController.text;
    if (query.isEmpty || text.isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentMatchIndex = 0;
      });
      _contentController.setSearchHighlight(query: null, activeRange: null);
      return;
    }

    final matches = <TextRange>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    while (start < lowerText.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(TextRange(start: index, end: index + query.length));
      start = index + query.length;
    }

    var newIndex = _currentMatchIndex;
    if (matches.isEmpty) {
      newIndex = 0;
    } else if (newIndex >= matches.length) {
      newIndex = 0;
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = newIndex;
    });

    final activeRange = matches.isNotEmpty ? matches[newIndex] : null;
    _contentController.setSearchHighlight(
      query: query,
      activeRange: activeRange,
    );
    if (activeRange != null) {
      _scrollToMatch(activeRange);
    }
  }

  void _goToNextMatch() {
    if (_searchMatches.isEmpty) return;
    final nextIdx = (_currentMatchIndex + 1) % _searchMatches.length;
    setState(() {
      _currentMatchIndex = nextIdx;
    });
    final activeRange = _searchMatches[nextIdx];
    _contentController.setSearchHighlight(
      query: _searchQueryController.text,
      activeRange: activeRange,
    );
    _scrollToMatch(activeRange);
  }

  void _goToPreviousMatch() {
    if (_searchMatches.isEmpty) return;
    final prevIdx =
        (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    setState(() {
      _currentMatchIndex = prevIdx;
    });
    final activeRange = _searchMatches[prevIdx];
    _contentController.setSearchHighlight(
      query: _searchQueryController.text,
      activeRange: activeRange,
    );
    _scrollToMatch(activeRange);
  }

  void _scrollToMatch(TextRange range) {
    if (!_scrollController.hasClients) return;
    final text = _contentController.text;
    if (range.start < 0 || range.start > text.length) return;

    final textBefore = text.substring(0, range.start);
    final lineCount = '\n'.allMatches(textBefore).length;
    final typography = ref.read(typographySettingsProvider);
    final estimatedLineHeight =
        typography.fontSize * typography.lineHeight + 4.0;
    final targetOffset = (lineCount * estimatedLineHeight + 40.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _replaceActiveMatch() {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;
    if (_searchMatches.isEmpty ||
        _currentMatchIndex >= _searchMatches.length) {
      return;
    }

    final match = _searchMatches[_currentMatchIndex];
    final text = _contentController.text;
    final replaceText = _replaceQueryController.text;

    final newText = text.replaceRange(match.start, match.end, replaceText);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: match.start + replaceText.length,
      ),
    );
    _onContentChanged();
    _recalculateMatches(_searchQueryController.text);
  }

  void _replaceAllMatches() {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;
    final query = _searchQueryController.text;
    if (query.isEmpty) return;

    final text = _contentController.text;
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    final count = pattern.allMatches(text).length;
    if (count == 0) return;

    final replaceText = _replaceQueryController.text;
    final newText = text.replaceAll(pattern, replaceText);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _onContentChanged();
    _recalculateMatches(query);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replaced $count occurrences'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchQueryController.removeListener(_onSearchQueryChanged);
    _searchQueryController.dispose();
    _searchQueryFocusNode.dispose();
    _replaceQueryController.dispose();
    _replaceQueryFocusNode.dispose();
    _titleController.removeListener(_onTitleChanged);
    _contentController.removeListener(_onContentChanged);
    _titleFocusNode.removeListener(_onFocusChanged);
    _contentFocusNode.removeListener(_onFocusChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProviderFamily(_editorParams));
    final editorNotifier =
        ref.read(editorProviderFamily(_editorParams).notifier);
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final note = editorState.note;

    _contentController.styles = MarkdownStyles.fromColors(
      colors,
      typography: typography,
    );

    final canPop = Navigator.of(context).canPop();

    final isNavSidebarVisible = ref.watch(isNavSidebarVisibleProvider);
    final isNoteListVisible = ref.watch(isNoteListVisibleProvider);
    final isTabletEditor = widget.onClose != null;
    final showSidebarRestore = isTabletEditor && (!isNavSidebarVisible || !isNoteListVisible);

    // If note is encrypted and locked in this session, present the Unlock View
    if (!editorState.isUnlocked) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: isTabletEditor
                ? QuietIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close note',
                    onPressed: () => widget.onClose?.call(),
                  )
                : (canPop
                    ? QuietIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : null),
            title: Text(
              editorState.note.displayTitle,
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            child: PasswordUnlockView(
              title: editorState.note.displayTitle,
              hint: editorState.activePasswordHint,
              onUnlock: (password) async {
                final success =
                    await editorNotifier.unlockWithPassword(password);
                if (success && mounted) {
                  final unlockedNote =
                      ref.read(editorProviderFamily(_editorParams)).note;
                  _titleController.text = unlockedNote.title;
                  _contentController.text = unlockedNote.content;
                }
                return success;
              },
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _openSearch(withReplace: false),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            _openSearch(withReplace: false),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            _openSearch(withReplace: true),
        const SingleActivator(LogicalKeyboardKey.keyH, meta: true): () =>
            _openSearch(withReplace: true),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearchVisible) _closeSearch();
        },
      },
      child: PopScope(
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
              QuietIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Find in note',
                isActive: _isSearchVisible,
                onPressed: () {
                  if (_isSearchVisible) {
                    _closeSearch();
                  } else {
                    _openSearch();
                  }
                },
              ),
              if (editorState.isReadOnly)
                QuietIconButton(
                  icon: Icons.lock_outline_rounded,
                  tooltip: 'Read-only mode (tap to unlock)',
                  onPressed: () {
                    editorNotifier.toggleReadOnly();
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note unlocked for editing'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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
                if (_isSearchVisible || _searchAnimationController.value > 0)
                  SizeTransition(
                    sizeFactor: _searchAnimation,
                    child: FadeTransition(
                    opacity: _searchAnimation,
                    child: SlideTransition(
                      position: _searchSlideAnimation,
                      child: InNoteSearchBar(
                        searchController: _searchQueryController,
                        searchFocusNode: _searchQueryFocusNode,
                        onClose: _closeSearch,
                        onPreviousMatch: _goToPreviousMatch,
                        onNextMatch: _goToNextMatch,
                        matchCount: _searchMatches.length,
                        currentMatchIndex: _currentMatchIndex,
                        showReplace: _showReplace,
                        onToggleReplace: () {
                          setState(() {
                            _showReplace = !_showReplace;
                          });
                          if (_showReplace) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _replaceQueryFocusNode.requestFocus();
                            });
                          }
                        },
                        replaceController: _replaceQueryController,
                        replaceFocusNode: _replaceQueryFocusNode,
                        onReplace: _replaceActiveMatch,
                        onReplaceAll: _replaceAllMatches,
                        isReadOnly: editorState.isReadOnly,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is OverscrollNotification &&
                          notification.overscroll < -15) {
                        if (!_isSearchVisible) {
                          _openSearch();
                        }
                        return true;
                      }
                      if (notification is ScrollUpdateNotification &&
                          notification.metrics.pixels <= 0 &&
                          notification.scrollDelta != null &&
                          notification.scrollDelta! < -12 &&
                          notification.dragDetails != null) {
                        if (!_isSearchVisible) {
                          _openSearch();
                        }
                        return true;
                      }
                      return false;
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 250 &&
                            _scrollController.hasClients &&
                            _scrollController.offset <= 0) {
                          if (!_isSearchVisible) {
                            _openSearch();
                          }
                        }
                      },
                      onTap: () {
                        if (!editorState.isPreviewMode && !editorState.isReadOnly) {
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
                          constraints: BoxConstraints(
                            maxWidth: typography.paragraphWidth.maxWidth,
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
                                  searchQuery: _isSearchVisible
                                      ? _searchQueryController.text
                                      : null,
                                )
                              : SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                left: AppSpacing.lg + typography.paragraphIndent,
                                right: AppSpacing.lg,
                                top: AppSpacing.md,
                                bottom: AppSpacing.md,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Document Title input
                                  TextField(
                                    controller: _titleController,
                                    focusNode: _titleFocusNode,
                                    readOnly: editorState.isReadOnly,
                                    cursorColor: colors.accent,
                                    style: FontFamilyHelper.getTextStyle(
                                      fontFamily: typography.headingFontFamily ??
                                          typography.bodyFontFamily,
                                      baseStyle: TextStyle(
                                        fontSize: typography.scaledTitleSize,
                                        fontWeight: FontWeight.w700,
                                        height: typography.lineHeight,
                                        letterSpacing: typography.letterSpacing - 0.5,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Title',
                                      hintStyle: FontFamilyHelper.getTextStyle(
                                        fontFamily: typography.headingFontFamily ??
                                            typography.bodyFontFamily,
                                        baseStyle: TextStyle(
                                          fontSize: typography.scaledTitleSize,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textTertiary.withValues(alpha: 0.4),
                                        ),
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
                                    readOnly: editorState.isReadOnly,
                                  ),
                                  // Generous bottom scroll area for comfortable typing above keyboard
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (!_contentFocusNode.hasFocus &&
                                          !editorState.isReadOnly) {
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
            ),

              // Floating/Docked formatting toolbar (only in active edit mode)
              if (!editorState.isPreviewMode && !editorState.isReadOnly)
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
                  onImagePressed: _handleInsertImage,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _handleInsertImage() async {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final attachmentService = ref.read(attachmentServiceProvider);

        ({AttachmentEntity attachment, String markdownSnippet}) importResult;

        if (pickedFile.path != null) {
          importResult = await attachmentService.importImageFromFile(
            File(pickedFile.path!),
            noteId: widget.note.id,
            preferredAltText: pickedFile.name,
          );
        } else if (pickedFile.bytes != null) {
          importResult = await attachmentService.importImageFromBytes(
            pickedFile.bytes!,
            mimeType: 'image/png',
            noteId: widget.note.id,
            preferredAltText: pickedFile.name,
          );
        } else {
          return;
        }

        final val = _contentController.value;
        final text = val.text;
        final sel = val.selection;
        final start = sel.isValid ? sel.start : text.length;
        final end = sel.isValid ? sel.end : text.length;

        final snippet = '\n${importResult.markdownSnippet}\n';
        final newText = text.replaceRange(start, end, snippet);
        final newCursor = start + snippet.length;

        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursor),
        );

        if (!_contentFocusNode.hasFocus) {
          _contentFocusNode.requestFocus();
        }

        _onContentChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to insert image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool get isTabletEditor => widget.onClose != null;

  void _showOverflowMenu(
    BuildContext context,
    Note note,
    EditorNotifier notifier,
  ) {
    final colors = context.appColors;
    final isPreview = ref.read(editorProviderFamily(_editorParams)).isPreviewMode;
    final isReadOnly = ref.read(editorProviderFamily(_editorParams)).isReadOnly;

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
                  if (!isPreview && !isReadOnly)
                    ListTile(
                      leading: Icon(
                        Icons.image_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Insert image',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _handleInsertImage();
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.search_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Find in note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openSearch();
                    },
                  ),
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
                      ref.read(editorProviderFamily(_editorParams)).isReadOnly
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      ref.read(editorProviderFamily(_editorParams)).isReadOnly
                          ? 'Unlock note (Edit mode)'
                          : 'Lock note (Read-only)',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final isCurrentlyReadOnly =
                          ref.read(editorProviderFamily(_editorParams)).isReadOnly;
                      notifier.toggleReadOnly();
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            !isCurrentlyReadOnly
                                ? 'Note locked in read-only mode'
                                : 'Note unlocked for editing',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  if (ref.read(editorProviderFamily(_editorParams)).activePassword == null &&
                      !note.isPasswordProtected) ...[
                    ListTile(
                      leading: Icon(
                        Icons.enhanced_encryption_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Protect with password',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final res = await SetNotePasswordDialog.show(context);
                        if (res != null) {
                          await notifier.setPasswordProtection(
                            password: res.password,
                            hint: res.hint,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Note password protection enabled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ] else ...[
                    ListTile(
                      leading: Icon(
                        Icons.password_rounded,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Change note password',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final res = await SetNotePasswordDialog.show(
                          context,
                          isChangingPassword: true,
                        );
                        if (res != null) {
                          await notifier.setPasswordProtection(
                            password: res.password,
                            hint: res.hint,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Note password updated'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.no_encryption_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Remove password protection',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await notifier.removePasswordProtection();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note password protection removed'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.lock_clock_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Lock note now',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        notifier.lockNow();
                      },
                    ),
                  ],
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
