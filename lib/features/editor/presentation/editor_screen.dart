import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/documents/document_models.dart';
import '../../../core/documents/document_provider.dart';
import '../../../core/documents/presentation/document_viewer_screen.dart';
import '../../../core/markdown/markdown_preview.dart';
import '../../../core/widgets/intelligent_heading_scrollbar.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../../features/web_clipper/presentation/web_snapshot_viewer_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/domain/note_version_model.dart';
import '../application/editor_provider.dart';
import '../application/markdown_editing_controller.dart';
import '../application/markdown_table_formatter.dart';
import '../application/undo_redo_manager.dart';
import '../application/version_session_tracker.dart';
import 'widgets/editor_stats_dialog.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/in_note_search_bar.dart';
import 'widgets/markdown_editor.dart';
import 'widgets/password_unlock_view.dart';
import 'widgets/table/table_insert_dialog.dart';
import 'widgets/tag_editor_bar.dart';
import 'widgets/version_history_sheet.dart';
import '../../notes/presentation/widgets/note_password_dialogs.dart';
import '../../scanner/presentation/document_scanner_screen.dart';
import '../../settings/application/settings_provider.dart';
import '../../settings/application/typography_provider.dart';
import '../domain/editor_editing_style.dart';
import '../domain/frontmatter_document.dart';
import '../application/frontmatter_editor_helper.dart';
import 'widgets/frontmatter_properties_section.dart';
import '../domain/markdown_styles.dart';
import 'package:flutter/rendering.dart';

import '../../../core/note_links/note_link_provider.dart';
import '../../../core/note_links/note_link_search_service.dart';
import '../application/markdown_formatter.dart';
import '../application/note_link_autocomplete_trigger.dart';
import 'widgets/note_link_inline_overlay.dart';

import '../../../core/utils/font_family_helper.dart';
import '../../../core/utils/tag_parser.dart';
import '../../export/presentation/export_note_sheet.dart';




class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.note,
    this.autoFocusBody = false,
    this.initialPreviewMode = false,
    this.onClose,
    this.onOpenLinkedNote,
  });

  final Note note;
  final bool autoFocusBody;
  final bool initialPreviewMode;
  final VoidCallback? onClose;
  final void Function(Note note, {bool initialPreviewMode})? onOpenLinkedNote;

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
  late final UndoRedoManager _undoRedoManager;
  late final VersionSessionTracker _sessionTracker;

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

  TextEditingController? _activeTargetController;
  FocusNode? _activeTargetFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final frontmatterDoc = FrontmatterEditorHelper.parse(widget.note.content);
    _isTitleManuallySet = widget.note.title.trim().isNotEmpty ||
        (frontmatterDoc.title?.trim().isNotEmpty == true);
    _lastAutoDerivedTitle = widget.note.title.isEmpty
        ? (frontmatterDoc.title?.isNotEmpty == true
            ? frontmatterDoc.title!
            : Note.deriveTitle(widget.note.content))
        : '';
    final initialTitle = frontmatterDoc.title?.isNotEmpty == true
        ? frontmatterDoc.title!
        : (widget.note.title.isNotEmpty
            ? widget.note.title
            : _lastAutoDerivedTitle);

    _titleController = TextEditingController(text: initialTitle);
    _contentController = MarkdownEditingController(text: widget.note.content);
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    _activeTargetController = _contentController;
    _activeTargetFocusNode = _contentFocusNode;
    _scrollController = ScrollController();

    _undoRedoManager = UndoRedoManager();
    _undoRedoManager.initialize(_contentController.value);
    _undoRedoManager.addListener(() {
      if (mounted) setState(() {});
    });

    _sessionTracker = VersionSessionTracker(widget.note);

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

    _contentFocusNode.onKeyEvent = (node, event) {
      if (_inlineAutocompleteController?.isOpen == true) {
        return _inlineAutocompleteController!.handleKeyEvent(event);
      }
      return KeyEventResult.ignored;
    };

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
    } else {
      if (oldWidget.note.content != widget.note.content &&
          !_contentFocusNode.hasFocus) {
        _contentController.text = widget.note.content;
        if (!_isTitleManuallySet && widget.note.title.isEmpty) {
          final autoTitle = Note.deriveTitle(widget.note.content);
          _lastAutoDerivedTitle = autoTitle;
          _titleController.text = autoTitle;
        }
      }
      if (oldWidget.note.title != widget.note.title &&
          !_titleFocusNode.hasFocus) {
        _titleController.text = widget.note.title;
        _isTitleManuallySet = widget.note.title.trim().isNotEmpty;
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
      _commitSessionVersionIfNeeded();
    }
  }

  void _onFocusChanged() {
    if (_contentFocusNode.hasFocus) {
      _activeTargetController = _contentController;
      _activeTargetFocusNode = _contentFocusNode;
    }
    if (!_titleFocusNode.hasFocus && !_contentFocusNode.hasFocus) {
      ref.read(editorProviderFamily(_editorParams).notifier).saveNow();
    }
  }

  void _undo() {
    final result = _undoRedoManager.undo(_contentController.value);
    if (result != null) {
      _contentController.value = result;
      _onContentChanged();
    }
  }

  void _redo() {
    final result = _undoRedoManager.redo(_contentController.value);
    if (result != null) {
      _contentController.value = result;
      _onContentChanged();
    }
  }

  void _onRemoveTag(String tag) {
    final normalized = TagParser.normalizeTag(tag);
    final currentTitle = _titleController.text;
    final currentContent = _contentController.text;

    final newTitle = TagParser.removeTagFromText(currentTitle, normalized);
    final newContent = TagParser.removeTagFromText(currentContent, normalized);

    if (newTitle != currentTitle) {
      _titleController.text = newTitle;
    }
    if (newContent != currentContent) {
      _contentController.text = newContent;
      _undoRedoManager.pushAtomicEdit(_contentController.value);
    }

    ref.read(editorProviderFamily(_editorParams).notifier).removeTag(tag);
  }

  Future<void> _commitSessionVersionIfNeeded() async {
    final finalTitle = _titleController.text;
    final finalContent = _contentController.text;
    final currentNote = ref.read(editorProviderFamily(_editorParams)).note;
    final finalTags = currentNote.tags;

    if (_sessionTracker.isMeaningfulSession(
      finalTitle: finalTitle,
      finalContent: finalContent,
      finalTags: finalTags,
    )) {
      final repository = ref.read(notesRepositoryProvider);
      final nextNum = await repository.getNextVersionNumber(widget.note.id);
      final summary = _sessionTracker.generateSummary(
        finalTitle: finalTitle,
        finalContent: finalContent,
        finalTags: finalTags,
      );

      final version = NoteVersion(
        id: const Uuid().v4(),
        noteId: widget.note.id,
        versionNumber: nextNum,
        title: finalTitle,
        content: finalContent,
        tags: finalTags,
        createdAt: DateTime.now(),
        charCount: finalContent.length,
        wordCount: NoteVersion.countWords(finalContent),
        deltaSummary: summary,
        isDirty: true,
      );

      await repository.saveVersion(version);
      await repository.pruneVersions(widget.note.id, maxKeep: 50);

      final syncEngine = ref.read(syncEngineProvider);
      syncEngine.triggerSyncDebounced();
    }
  }

  Future<void> _restoreVersion(NoteVersion version) async {
    await _commitSessionVersionIfNeeded();

    setState(() {
      _titleController.text = version.title;
      _contentController.text = version.content;
      _isTitleManuallySet = version.title.trim().isNotEmpty;
    });

    final notifier = ref.read(editorProviderFamily(_editorParams).notifier);
    notifier.updateTitle(version.title);
    notifier.updateContent(version.content);
    notifier.setTags(version.tags);
    await notifier.saveNow();

    _undoRedoManager.initialize(_contentController.value);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored Version ${version.versionNumber}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    // Sync with frontmatter title if frontmatter is present
    final frontmatterDoc = FrontmatterEditorHelper.parse(_contentController.text);
    if (frontmatterDoc.hasFrontmatter) {
      final updatedContent = FrontmatterEditorHelper.updateTitle(
        documentText: _contentController.text,
        newTitle: currentTitle,
      );
      if (updatedContent != _contentController.text) {
        _contentController.text = updatedContent;
        ref
            .read(editorProviderFamily(_editorParams).notifier)
            .updateContent(updatedContent);
      }
    }

    ref
        .read(editorProviderFamily(_editorParams).notifier)
        .updateTitle(currentTitle);
  }

  void _onContentChanged() {
    final newContent = _contentController.text;
    _undoRedoManager.registerEdit(_contentController.value);

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

    _checkAutocompleteTrigger();
  }

  NoteLinkInlineOverlayController? _inlineAutocompleteController;

  void _checkAutocompleteTrigger() {
    final trigger = NoteLinkAutocompleteTrigger.detect(_contentController.value);
    if (trigger == null) {
      _inlineAutocompleteController?.hide();
      return;
    }

    _inlineAutocompleteController ??= NoteLinkInlineOverlayController(
      context: context,
      searchService: ref.read(noteLinkSearchServiceProvider),
      currentNoteId: widget.note.id,
      onSelectNote: _onAutocompleteSelectNote,
      onCreateNote: _onAutocompleteCreateNote,
    );

    final caretRect = _getCaretRect(trigger.triggerStart);
    _inlineAutocompleteController!.showOrUpdate(
      query: trigger.query,
      triggerStart: trigger.triggerStart,
      queryEnd: trigger.queryEnd,
      caretRect: caretRect,
    );
  }

  Rect _getCaretRect(int offset) {
    final ctx = _contentFocusNode.context;
    if (ctx != null) {
      final renderObject = ctx.findRenderObject();
      final renderEditable = _findRenderEditable(renderObject);
      if (renderEditable != null) {
        final endpoints = renderEditable.getEndpointsForSelection(
          TextSelection.collapsed(offset: offset.clamp(0, _contentController.text.length)),
        );
        if (endpoints.isNotEmpty) {
          final globalPoint = renderEditable.localToGlobal(endpoints.first.point);
          return Rect.fromLTWH(globalPoint.dx, globalPoint.dy, 2.0, renderEditable.preferredLineHeight);
        }
      }
      if (renderObject is RenderBox && renderObject.hasSize) {
        final global = renderObject.localToGlobal(Offset.zero);
        return Rect.fromLTWH(global.dx, global.dy + 40, 2.0, 24.0);
      }
    }
    return const Rect.fromLTWH(40.0, 200.0, 2.0, 24.0);
  }

  RenderEditable? _findRenderEditable(RenderObject? ro) {
    if (ro is RenderEditable) return ro;
    RenderEditable? found;
    ro?.visitChildren((child) {
      found ??= _findRenderEditable(child);
    });
    return found;
  }

  void _onAutocompleteSelectNote(NoteLinkSearchResultItem item, int replaceStart, int replaceEnd) {
    final updated = MarkdownFormatter.insertNoteLink(
      value: _contentController.value,
      noteId: item.id,
      targetTitle: item.title,
      replaceStart: replaceStart,
      replaceEnd: replaceEnd,
    );
    _contentController.value = updated;
    _undoRedoManager.pushAtomicEdit(_contentController.value);
    _onContentChanged();
    if (!_contentFocusNode.hasFocus) {
      _contentFocusNode.requestFocus();
    }
  }

  Future<void> _onAutocompleteCreateNote(String title, int replaceStart, int replaceEnd) async {
    final notesRepo = ref.read(notesRepositoryProvider);
    final newNoteId = const Uuid().v4();
    final newNote = Note(
      id: newNoteId,
      title: title,
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await notesRepo.saveNote(newNote);

    final updated = MarkdownFormatter.insertNoteLink(
      value: _contentController.value,
      noteId: newNoteId,
      targetTitle: title,
      replaceStart: replaceStart,
      replaceEnd: replaceEnd,
    );
    _contentController.value = updated;
    _undoRedoManager.pushAtomicEdit(_contentController.value);
    _onContentChanged();

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(note: newNote),
        ),
      );
    }
  }

  void _handleNoteLinkPrompt() {
    final targetCtrl = _activeTargetController ?? _contentController;
    final targetFn = _activeTargetFocusNode ?? _contentFocusNode;

    if (!targetFn.hasFocus) {
      targetFn.requestFocus();
    }

    final sel = targetCtrl.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final start = min(sel.start, sel.end);
      final end = max(sel.start, sel.end);
      final selectedText = targetCtrl.text.substring(start, end);
      final newText = targetCtrl.text.replaceRange(start, end, '[[$selectedText');
      targetCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 2 + selectedText.length),
      );
    } else {
      final offset = sel.isValid ? sel.baseOffset : targetCtrl.text.length;
      final newText = targetCtrl.text.replaceRange(offset, offset, '[[');
      targetCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 2),
      );
    }
    _onContentChanged();
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
    _searchQueryController.clear();
    _replaceQueryController.clear();
    _searchMatches.clear();
    _currentMatchIndex = 0;
    _contentController.setSearchHighlight(query: null, activeRange: null);

    _searchAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSearchVisible = false;
          _showReplace = false;
        });
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
    const maxSearchMatches = 1000;
    while (start < lowerText.length && matches.length < maxSearchMatches) {
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
    _undoRedoManager.dispose();
    _inlineAutocompleteController?.dispose();
    _inlineAutocompleteController = null;
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProviderFamily(_editorParams));
    final editorNotifier =
        ref.read(editorProviderFamily(_editorParams).notifier);
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final globalEditingStyle = ref.watch(editorEditingStyleProvider);
    final effectiveEditingStyle = editorState.effectiveEditingStyle(globalEditingStyle);
    final isWysiwyg = effectiveEditingStyle == EditorEditingStyle.wysiwyg;
    final note = editorState.note;
    final contentText = _contentController.text.isNotEmpty ? _contentController.text : note.content;
    final frontmatterDoc = isWysiwyg ? FrontmatterEditorHelper.parse(contentText) : FrontmatterDocument.empty;

    _contentController.styles = MarkdownStyles.fromColors(
      colors,
      typography: typography,
    );

    final canPop = Navigator.of(context).canPop();
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final isNavSidebarVisible = ref.watch(isNavSidebarVisibleProvider);
    final isNoteListVisible = ref.watch(isNoteListVisibleProvider);
    final isTabletEditor = isTablet && widget.onClose != null;
    final showSidebarRestore =
        isTabletEditor && (!isNavSidebarVisible || !isNoteListVisible);

    // If note is encrypted and locked in this session, present the Unlock View
    if (!editorState.isUnlocked) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: canPop
              ? QuietIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
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
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redo,
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
            _commitSessionVersionIfNeeded();
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
                          _commitSessionVersionIfNeeded();
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
                      behavior: HitTestBehavior.translucent,
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
                          child: IntelligentHeadingScrollbar(
                            scrollController: _scrollController,
                            contentController: _contentController,
                            titleController: _titleController,
                            markdownData: _contentController.text.isNotEmpty
                                ? _contentController.text
                                : note.content,
                            title: _titleController.text.isNotEmpty
                                ? _titleController.text
                                : note.title,
                            child: editorState.isPreviewMode
                                ? QuietMarkdownPreview(
                                    markdownData: _contentController.text.isNotEmpty
                                        ? _contentController.text
                                        : note.content,
                                    noteId: note.id,
                                    title: _titleController.text.isNotEmpty
                                        ? _titleController.text
                                        : note.title,
                                    tags: note.tags,
                                    onAddTag: editorNotifier.addTag,
                                    onRemoveTag: _onRemoveTag,
                                    scrollController: _scrollController,
                                    searchQuery: _isSearchVisible
                                        ? _searchQueryController.text
                                        : null,
                                    onDocumentRenamed: _updateDocumentMarkdownTitle,
                                    onAttachmentRenamed: _updateAttachmentMarkdownTitle,
                                    onAttachmentDeleted: _removeAttachmentMarkdownRef,
                                    onInsertText: _insertExtractedOcrText,
                                    onOpenLinkedNote: widget.onOpenLinkedNote,
                                    showScrollbar: false,
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
                                      fontFamily: FontFamilyHelper.resolveHeadingFontFamily(
                                        typography.headingFontFamily ??
                                            typography.bodyFontFamily,
                                      ),
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
                                        fontFamily: FontFamilyHelper.resolveHeadingFontFamily(
                                          typography.headingFontFamily ??
                                              typography.bodyFontFamily,
                                        ),
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
                                      onRemoveTag: _onRemoveTag,
                                    ),
                                    const SizedBox(height: 12.0),
                                  ],

                                   // Frontmatter Properties Section (in WYSIWYG mode when matching frontmatter exists)
                                   if (isWysiwyg && frontmatterDoc.hasMatchingSectionProperties) ...[
                                     FrontmatterPropertiesSection(
                                      frontmatter: frontmatterDoc,
                                      rawDocument: contentText,
                                      readOnly: editorState.isReadOnly,
                                      onDocumentChanged: (updated) {
                                        _contentController.text = updated;
                                        editorNotifier.updateContent(updated);
                                        final newDoc = FrontmatterEditorHelper.parse(updated);
                                        if (newDoc.title != null && newDoc.title != _titleController.text) {
                                          _titleController.text = newDoc.title!;
                                          editorNotifier.updateTitle(newDoc.title!);
                                        }
                                      },
                                    ),
                                  ],

                                  // Attached web snapshots / documents bar
                                  _buildAttachedResourcesBar(context, colors),

                                  // Body markdown editor
                                  MarkdownEditor(
                                    controller: _contentController,
                                    focusNode: _contentFocusNode,
                                    editingStyle: effectiveEditingStyle,
                                    stripFrontmatter: isWysiwyg && frontmatterDoc.hasFrontmatter,
                                    readOnly: editorState.isReadOnly,
                                    onNoteLinkPrompt: _handleNoteLinkPrompt,
                                    searchQuery: _isSearchVisible
                                        ? _searchQueryController.text
                                        : null,
                                    onActiveTargetChanged: (ctrl, fn) {
                                      if (mounted) {
                                        setState(() {
                                          _activeTargetController = ctrl;
                                          _activeTargetFocusNode = fn;
                                        });
                                      }
                                    },
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
                ),

              // Floating/Docked formatting toolbar (only in active edit mode)
              if (!editorState.isPreviewMode && !editorState.isReadOnly)
                FormattingToolbar(
                  controller: _activeTargetController ?? _contentController,
                  focusNode: _activeTargetFocusNode ?? _contentFocusNode,
                  canUndo: _undoRedoManager.canUndo,
                  canRedo: _undoRedoManager.canRedo,
                  onUndo: _undo,
                  onRedo: _redo,
                  onNoteLinkPressed: _handleNoteLinkPrompt,
                  onApplyAtomicEdit: (val) {

                    if ((_activeTargetController ?? _contentController) != _contentController) {
                      _undoRedoManager.pushAtomicEdit(_contentController.value);
                    } else {
                      _undoRedoManager.pushAtomicEdit(val);
                    }
                  },
                  onTagPressed: () {
                    final ctrl = _activeTargetController ?? _contentController;
                    final fn = _activeTargetFocusNode ?? _contentFocusNode;
                    final val = ctrl.value;
                    final text = val.text;
                    final sel = val.selection;
                    final start = sel.isValid ? sel.start : text.length;
                    final newText = text.replaceRange(start, start, '#');
                    final updated = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: start + 1),
                    );
                    ctrl.value = updated;
                    if (ctrl != _contentController) {
                      _undoRedoManager.pushAtomicEdit(_contentController.value);
                    } else {
                      _undoRedoManager.pushAtomicEdit(updated);
                    }
                    if (!fn.hasFocus) {
                      fn.requestFocus();
                    }
                  },
                  onTablePressed: _handleInsertTable,
                  onImagePressed: _handleInsertImage,
                  onScanPressed: _handleScanDocument,
                  onPdfPressed: _handleAttachPdf,
                  onFilePressed: _handleAttachFile,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _updateDocumentMarkdownTitle(String documentId, String newTitle) {
    final text = _contentController.text;
    final regex = RegExp(
      r'\[([^\]\n]*)\]\(qp:\/\/document\/' + RegExp.escape(documentId) + r'(\?[^\)]*)?\)',
    );
    if (regex.hasMatch(text)) {
      final newText = text.replaceAllMapped(regex, (match) {
        final queryPart = match.group(2) ?? '';
        return '[$newTitle](qp://document/$documentId$queryPart)';
      });
      _contentController.text = newText;
      _undoRedoManager.pushAtomicEdit(_contentController.value);
      _onContentChanged();
    }
  }

  void _updateAttachmentMarkdownTitle(String attachmentId, String newTitle) {
    final text = _contentController.text;
    final regex = RegExp(
      r'\[([^\]\n]*)\]\(qp:\/\/asset\/' + RegExp.escape(attachmentId) + r'(\?[^\)]*)?\)',
    );
    if (regex.hasMatch(text)) {
      final newText = text.replaceAllMapped(regex, (match) {
        final queryPart = match.group(2) ?? '';
        return '[$newTitle](qp://asset/$attachmentId$queryPart)';
      });
      _contentController.text = newText;
      _undoRedoManager.pushAtomicEdit(_contentController.value);
      _onContentChanged();
    }
  }

  void _removeAttachmentMarkdownRef(String attachmentId) {
    final text = _contentController.text;
    final regex = RegExp(
      r'!?\[([^\]\n]*)\]\(qp:\/\/asset\/' + RegExp.escape(attachmentId) + r'(\?[^\)]*)?\)\n?',
    );
    if (regex.hasMatch(text)) {
      final newText = text.replaceAll(regex, '');
      _contentController.text = newText;
      _undoRedoManager.pushAtomicEdit(_contentController.value);
      _onContentChanged();
    }
  }

  Future<void> _handleAttachFile() async {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final attachmentService = ref.read(attachmentServiceProvider);
      final validSnippets = <String>[];
      int successCount = 0;
      int failCount = 0;
      final failedNames = <String>[];

      for (final pickedFile in result.files) {
        try {
          final fileName = pickedFile.name;
          Uint8List? bytes = pickedFile.bytes;
          if (bytes == null && pickedFile.path != null) {
            bytes = await File(pickedFile.path!).readAsBytes();
          }
          if (bytes == null) {
            failCount++;
            failedNames.add(fileName);
            continue;
          }

          final res = await attachmentService.importGenericFileFromBytes(
            bytes,
            fileName: fileName,
            noteId: widget.note.id,
          );
          validSnippets.add(res.markdownSnippet);
          successCount++;
        } catch (e) {
          failCount++;
          failedNames.add(pickedFile.name);
        }
      }

      if (validSnippets.isNotEmpty) {
        final val = _contentController.value;
        final text = val.text;
        final sel = val.selection;
        final start = sel.isValid ? sel.start : text.length;
        final end = sel.isValid ? sel.end : text.length;

        final combinedSnippet = '\n${validSnippets.join('\n')}\n';
        final newText = text.replaceRange(start, end, combinedSnippet);
        final newCursor = start + combinedSnippet.length;

        final updated = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursor),
        );

        _contentController.value = updated;
        _undoRedoManager.pushAtomicEdit(updated);

        if (!_contentFocusNode.hasFocus) {
          _contentFocusNode.requestFocus();
        }

        _onContentChanged();
      }

      if (mounted && failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? 'Added $successCount ${successCount == 1 ? "file" : "files"}. $failCount could not be attached.'
                  : 'Couldn\'t attach ${failedNames.join(", ")}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleInsertTable() async {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;

    final result = await TableInsertDialog.show(context);
    if (result != null) {
      final updated = MarkdownTableFormatter.insertTable(
        value: _contentController.value,
        rows: result.rows,
        columns: result.columns,
      );
      _contentController.value = updated;
      _undoRedoManager.pushAtomicEdit(updated);
      _onContentChanged();

      if (!_contentFocusNode.hasFocus) {
        _contentFocusNode.requestFocus();
      }
    }
  }

  Future<void> _handleAttachPdf() async {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        File? file;
        final bytes = pickedFile.bytes;
        if (pickedFile.path != null) {
          file = File(pickedFile.path!);
        } else if (bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(p.join(tempDir.path, pickedFile.name));
          await tempFile.writeAsBytes(bytes);
          file = tempFile;
        }

        if (file != null) {
          final docService = ref.read(documentServiceProvider);
          final res = await docService.importPdfFile(
            file: file,
            noteId: widget.note.id,
            title: pickedFile.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
          );

          final val = _contentController.value;
          final text = val.text;
          final sel = val.selection;
          final start = sel.isValid ? sel.start : text.length;
          final end = sel.isValid ? sel.end : text.length;

          final snippet = '\n${res.markdownSnippet}\n';
          final newText = text.replaceRange(start, end, snippet);
          final newCursor = start + snippet.length;

          final updated = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursor),
          );

          _contentController.value = updated;
          _undoRedoManager.pushAtomicEdit(updated);

          if (!_contentFocusNode.hasFocus) {
            _contentFocusNode.requestFocus();
          }

          _onContentChanged();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleScanDocument() async {
    final editorState = ref.read(editorProviderFamily(_editorParams));
    if (editorState.isReadOnly) return;

    try {
      final scanResult = await DocumentScannerScreen.open(
        context,
        noteId: widget.note.id,
        initialTitle: 'Scanned Document',
      );

      if (scanResult != null) {
        final val = _contentController.value;
        final text = val.text;
        final sel = val.selection;
        final start = sel.isValid ? sel.start : text.length;
        final end = sel.isValid ? sel.end : text.length;

        final snippet = '\n${scanResult.markdownSnippet}\n';
        final newText = text.replaceRange(start, end, snippet);
        final newCursor = start + snippet.length;

        final updated = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursor),
        );

        _contentController.value = updated;
        _undoRedoManager.pushAtomicEdit(updated);

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
            content: Text('Failed to scan document: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  void _insertExtractedOcrText(String extractedText) {
    final clean = extractedText.trim();
    if (clean.isEmpty) return;

    final val = _contentController.value;
    final text = val.text;
    final sel = val.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    final snippet = '\n\n$clean\n';
    final newText = text.replaceRange(start, end, snippet);
    final newCursor = start + snippet.length;

    final updated = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _contentController.value = updated;
    _undoRedoManager.pushAtomicEdit(updated);

    if (!_contentFocusNode.hasFocus) {
      _contentFocusNode.requestFocus();
    }

    _onContentChanged();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extracted text inserted into note'),
        behavior: SnackBarBehavior.floating,
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
                  if (!isPreview && !isReadOnly) ...[
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
                        Icons.document_scanner_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Scan document',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _handleScanDocument();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.table_chart_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Insert table',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _handleInsertTable();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.attach_file_rounded,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Attach file',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _handleAttachFile();
                      },
                    ),
                  ],
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
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final currentNoteSnapshot = note.copyWith(
                        title: _titleController.text,
                        content: _contentController.text,
                      );
                      ExportNoteSheet.show(context, note: currentNoteSnapshot);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.history_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Version history',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      VersionHistorySheet.show(
                        context,
                        note: note,
                        currentTitle: _titleController.text,
                        currentContent: _contentController.text,
                        currentTags: note.tags,
                        onRestoreVersion: _restoreVersion,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final globalStyle = ref.read(editorEditingStyleProvider);
                      final currentStyle = ref.read(editorProviderFamily(_editorParams)).effectiveEditingStyle(globalStyle);
                      final isCurrentWysiwyg = currentStyle == EditorEditingStyle.wysiwyg;

                      return ListTile(
                        leading: Icon(
                          isCurrentWysiwyg ? Icons.code_rounded : Icons.visibility_outlined,
                          color: colors.textSecondary,
                        ),
                        title: Text(
                          isCurrentWysiwyg ? 'Edit Markdown' : 'Edit Visually',
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isCurrentWysiwyg ? 'Show raw Markdown syntax' : 'Hide Markdown syntax',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          notifier.setPerNoteEditingStyle(
                            isCurrentWysiwyg ? EditorEditingStyle.markdown : EditorEditingStyle.wysiwyg,
                          );
                        },
                      );
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
                  // Trash actions: Export, Restore, Delete Permanently
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final currentNoteSnapshot = note.copyWith(
                        title: _titleController.text,
                        content: _contentController.text,
                      );
                      ExportNoteSheet.show(context, note: currentNoteSnapshot);
                    },
                  ),
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
                  // Archive actions: Export, Unarchive, Move to Trash
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final currentNoteSnapshot = note.copyWith(
                        title: _titleController.text,
                        content: _contentController.text,
                      );
                      ExportNoteSheet.show(context, note: currentNoteSnapshot);
                    },
                  ),
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

  Widget _buildAttachedResourcesBar(BuildContext context, AppColors colors) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<DocumentEntity>>(
      stream: db.watchDocumentsForNote(widget.note.id),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: docs.map((doc) {
              final lowerTitle = doc.title.toLowerCase();
              final isWebSnapshot = doc.source == DocumentSource.webSnapshot.identifier ||
                  doc.source == 'web_snapshot' ||
                  doc.mimeType == 'text/html' ||
                  lowerTitle.contains('(web snapshot)') ||
                  lowerTitle.endsWith('.html') ||
                  lowerTitle.endsWith('.htm');
              return Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (isWebSnapshot) {
                      WebSnapshotViewerScreen.open(
                        context,
                        documentId: doc.id,
                        title: doc.title,
                      );
                    } else {
                      DocumentViewerScreen.open(
                        context,
                        documentId: doc.id,
                        title: doc.title,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.divider, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWebSnapshot ? Icons.language_rounded : Icons.picture_as_pdf_rounded,
                          size: 14,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            isWebSnapshot ? 'Web Snapshot' : (doc.title.isNotEmpty ? doc.title : 'Document'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
