import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/attachments/presentation/image_viewer_modal.dart';
import '../../../core/documents/presentation/document_viewer_screen.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/presentation/widgets/note_list_tile.dart';
import '../../tags/application/tag_providers.dart';
import '../../tags/domain/tag_icon_registry.dart';
import '../application/search_provider.dart';
import 'widgets/document_search_tile.dart';
import 'widgets/search_filter_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchFocusNode = FocusNode();
    _debouncer = Debouncer(duration: const Duration(milliseconds: 150));

    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(searchQueryProvider.notifier).state = widget.initialQuery;
        }
      });
    }

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debouncer.run(() {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = _searchController.text;
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final query = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(globalSearchResultsProvider);
    final activeFilter = ref.watch(searchFilterProvider);
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            Navigator.of(context).pop();
          },
        ),
        actions: [
          QuietIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New note',
            onPressed: () => _createAndOpenNote(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(colors, hasQuery),
            Expanded(
              child: hasQuery
                  ? _buildResultsArea(
                      context, colors, query, searchResultsAsync, activeFilter)
                  : _buildInitialState(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors, bool hasQuery) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large editorial title; collapses once a query is active to give
          // the results list more vertical room.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: hasQuery
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Search',
                      style: AppTypography.display.copyWith(
                        color: colors.textPrimary,
                        fontSize: 30,
                      ),
                    ),
                  ),
          ),
          _buildSearchField(colors),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderLg,
        border: Border.all(color: colors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: widget.initialQuery.isEmpty,
              cursorColor: colors.accent,
              textInputAction: TextInputAction.search,
              style: AppTypography.body
                  .copyWith(color: colors.textPrimary, fontSize: 16.5),
              decoration: InputDecoration(
                hintText: 'Search notes, documents, OCR, tags...',
                hintStyle: AppTypography.body
                    .copyWith(color: colors.textTertiary, fontSize: 16.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return InkResponse(
                onTap: () {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: colors.textTertiary),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea(
    BuildContext context,
    AppColors colors,
    String query,
    AsyncValue<GlobalSearchResults> searchResultsAsync,
    SearchFilter activeFilter,
  ) {
    final results = searchResultsAsync.valueOrNull;
    final isLoading = searchResultsAsync.isLoading;

    if (results != null) {
      return Column(
        children: [
          if (isLoading || results.searchPhase != SearchPhase.complete)
            LinearProgressIndicator(
              minHeight: 2.0,
              backgroundColor: Colors.transparent,
              color: colors.accent,
            )
          else
            const SizedBox(height: 2.0),
          SearchFilterBar(results: results),
          Expanded(
            child: results.isEmpty
                ? _buildEmptyResultsState(
                    colors,
                    query,
                    isSearching:
                        results.searchPhase != SearchPhase.complete,
                  )
                : _buildResultsList(
                    context: context,
                    colors: colors,
                    query: query,
                    results: results,
                    filter: activeFilter,
                  ),
          ),
        ],
      );
    }
    if (isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (searchResultsAsync.hasError) {
      return Center(
        child: Text(
          'Error searching: ${searchResultsAsync.error}',
          style: AppTypography.body.copyWith(color: colors.error),
        ),
      );
    }

    return _buildInitialState(colors);
  }

  Widget _buildResultsList({
    required BuildContext context,
    required AppColors colors,
    required String query,
    required GlobalSearchResults results,
    required SearchFilter filter,
  }) {
    switch (filter) {
      case SearchFilter.notes:
        if (results.noteMatches.isEmpty) {
          return _buildEmptyCategoryState(colors, 'No matching notes found');
        }
        return ListView.builder(
          itemCount: results.noteMatches.length,
          itemBuilder: (context, index) {
            final match = results.noteMatches[index];
            return _buildNoteTile(
              context,
              match.note,
              query,
              matchedSnippet: match.matchedSnippet,
              titleHighlightSpans: match.titleHighlightSpans,
              snippetHighlightSpans: match.snippetHighlightSpans,
            );
          },
        );

      case SearchFilter.documents:
        if (results.documentMatches.isEmpty) {
          return _buildEmptyCategoryState(colors, 'No matching documents or OCR text found');
        }
        return ListView.builder(
          itemCount: results.documentMatches.length,
          itemBuilder: (context, index) {
            return _buildDocumentTile(context, results.documentMatches[index], query);
          },
        );

      case SearchFilter.tags:
        final tagNotes = results.noteMatches.where((n) => n.matchedInTags).toList();
        if (tagNotes.isEmpty) {
          return _buildEmptyCategoryState(colors, 'No notes found matching tag query');
        }
        return ListView.builder(
          itemCount: tagNotes.length,
          itemBuilder: (context, index) {
            final match = tagNotes[index];
            return _buildNoteTile(
              context,
              match.note,
              query,
              matchedSnippet: match.matchedSnippet,
              titleHighlightSpans: match.titleHighlightSpans,
              snippetHighlightSpans: match.snippetHighlightSpans,
            );
          },
        );

      case SearchFilter.all:
        final showSectionHeaders =
            results.noteMatches.isNotEmpty && results.documentMatches.isNotEmpty;

        return ListView(
          children: [
            // Notes Section
            if (results.noteMatches.isNotEmpty) ...[
              if (showSectionHeaders)
                _buildSectionHeader(colors, 'NOTES', results.notesCount),
              ...results.noteMatches.map((match) {
                return _buildNoteTile(
                  context,
                  match.note,
                  query,
                  matchedSnippet: match.matchedSnippet,
                  titleHighlightSpans: match.titleHighlightSpans,
                  snippetHighlightSpans: match.snippetHighlightSpans,
                );
              }),
            ],

            // Documents & OCR Section
            if (results.documentMatches.isNotEmpty) ...[
              if (showSectionHeaders)
                _buildSectionHeader(colors, 'DOCUMENTS & SCANNED OCR', results.documentsCount),
              ...results.documentMatches.map((docMatch) {
                return _buildDocumentTile(context, docMatch, query);
              }),
            ],
          ],
        );
    }
  }

  Widget _buildSectionHeader(AppColors colors, String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      color: colors.background,
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: colors.divider.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(
    BuildContext context,
    Note note,
    String query, {
    String? matchedSnippet,
    List<TokenSpanDto>? titleHighlightSpans,
    List<TokenSpanDto>? snippetHighlightSpans,
  }) {
    return NoteListTile(
      note: note,
      searchQuery: query,
      precomputedSnippet: matchedSnippet,
      titleHighlightSpans: titleHighlightSpans,
      snippetHighlightSpans: snippetHighlightSpans,
      onTap: () => _openNote(context, note),
      onTogglePin: () {
        ref.read(notesRepositoryProvider).setPinned(note.id, !note.isPinned);
      },
      onArchive: () {
        final repo = ref.read(notesRepositoryProvider);
        repo.archiveNote(note.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note archived'),
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.horizontal,
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.unarchiveNote(note.id),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      onTrash: () {
        final repo = ref.read(notesRepositoryProvider);
        repo.trashNote(note.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note moved to Trash'),
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.horizontal,
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  repo.restoreFromTrash(note.id, restoreUpdatedAt: note.updatedAt),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      onDelete: () {
        final repo = ref.read(notesRepositoryProvider);
        repo.trashNote(note.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note moved to Trash'),
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.horizontal,
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  repo.restoreFromTrash(note.id, restoreUpdatedAt: note.updatedAt),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );
  }

  Widget _buildDocumentTile(BuildContext context, DocumentSearchMatch match, String query) {
    return DocumentSearchTile(
      match: match,
      searchQuery: query,
      onTap: () {
        if (match.isAttachment && match.attachment != null) {
          ImageViewerModal.open(
            context,
            assetId: match.attachment!.id,
            altText: match.title,
          );
        } else if (match.document != null) {
          DocumentViewerScreen.open(
            context,
            documentId: match.document!.id,
            title: match.document!.title,
            initialPageIndex: match.matchedPageNumber > 0 ? match.matchedPageNumber - 1 : 0,
          );
        }
      },
    );
  }

  Widget _buildInitialState(AppColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTagsAsync = ref.watch(allTagsProvider);
    final pinnedTags = ref.watch(pinnedTagsProvider);
    final allTags = allTagsAsync.valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'Notes, documents, OCR text, and tags — all in one search.',
          style: AppTypography.body.copyWith(
            color: colors.textTertiary,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),

        // Pinned Tags Shortcuts
        if (pinnedTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Icon(Icons.push_pin_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                'PINNED TAGS',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pinnedTags.map((tag) {
              final colorDef = tag.colorDefinition;
              final customColor = colorDef?.foreground(isDark);
              final customBg = colorDef?.background(isDark);

              return ActionChip(
                avatar: Icon(
                  TagIconRegistry.getIconData(tag.icon, fallback: Icons.tag_rounded),
                  size: 14,
                  color: customColor ?? colors.accent,
                ),
                label: Text('#${tag.name} (${tag.noteCount})'),
                labelStyle: AppTypography.caption.copyWith(
                  color: customColor ?? colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: customBg ?? colors.surface,
                side: BorderSide(
                  color: customColor?.withValues(alpha: 0.4) ?? colors.divider,
                ),
                onPressed: () {
                  _searchController.text = '#${tag.name}';
                  ref.read(searchQueryProvider.notifier).state = '#${tag.name}';
                },
              );
            }).toList(),
          ),
        ],

        // Recent / Top Tags Shortcuts
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'QUICK TAGS',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () {
                  ref.read(currentDestinationProvider.notifier).state =
                      AppDestination.tagBrowser;
                  ref.read(selectedTagFilterProvider.notifier).state = null;
                  ref.read(selectedTagIdProvider.notifier).state = null;
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Browse all →',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.take(12).map((tag) {
              final colorDef = tag.colorDefinition;
              final customColor = colorDef?.foreground(isDark);
              final customBg = colorDef?.background(isDark);

              return ActionChip(
                avatar: Icon(
                  TagIconRegistry.getIconData(tag.icon, fallback: Icons.tag_rounded),
                  size: 14,
                  color: customColor ?? colors.textSecondary,
                ),
                label: Text('#${tag.name}'),
                labelStyle: AppTypography.caption.copyWith(
                  color: customColor ?? colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: customBg ?? colors.background,
                side: BorderSide(
                  color: customColor?.withValues(alpha: 0.3) ?? colors.divider,
                ),
                onPressed: () {
                  _searchController.text = '#${tag.name}';
                  ref.read(searchQueryProvider.notifier).state = '#${tag.name}';
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyCategoryState(AppColors colors, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          style: AppTypography.body.copyWith(
            color: colors.textSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyResultsState(AppColors colors, String query, {bool isSearching = false}) {
    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Searching note content & documents…',
                style: AppTypography.body.copyWith(
                  color: colors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No results found',
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No notes, documents, or OCR text matched "$query".\nTry another search or create a new note.',
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontSize: 14.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openNote(BuildContext context, Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          note: note,
          initialPreviewMode: true,
        ),
      ),
    );
  }

  void _createAndOpenNote(BuildContext context) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final newNote = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(notesRepositoryProvider).saveNote(newNote);

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            note: newNote,
            autoFocusBody: true,
            initialPreviewMode: false,
          ),
        ),
      );
    }
  }
}

/// Custom top-slide and fade transition route for opening SearchScreen seamlessly.
class SearchPageRoute<T> extends PageRouteBuilder<T> {
  SearchPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, -0.06),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}
