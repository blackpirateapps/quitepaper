import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/presentation/widgets/note_list_tile.dart';

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
    final searchResultsAsync = ref.watch(searchNotesStreamProvider);

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
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: widget.initialQuery.isEmpty,
          cursorColor: colors.accent,
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: 'Search notes and tags...',
            hintStyle: AppTypography.headline.copyWith(
              color: colors.textTertiary,
              fontSize: 18,
            ),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            QuietIconButton(
              icon: Icons.clear_rounded,
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
          QuietIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New note',
            onPressed: () => _createAndOpenNote(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: query.trim().isEmpty
            ? _buildInitialState(colors)
            : searchResultsAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return _buildEmptyResultsState(colors, query);
                  }
                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return NoteListTile(
                        note: note,
                        searchQuery: query,
                        onTap: () => _openNote(context, note),
                        onTogglePin: () {
                          ref
                              .read(notesRepositoryProvider)
                              .setPinned(note.id, !note.isPinned);
                        },
                        onArchive: () {
                          final repo = ref.read(notesRepositoryProvider);
                          repo.archiveNote(note.id);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Note archived'),
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
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Note moved to Trash'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => repo.restoreFromTrash(note.id),
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        onDelete: () {
                          final repo = ref.read(notesRepositoryProvider);
                          repo.trashNote(note.id);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Note moved to Trash'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => repo.restoreFromTrash(note.id),
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error searching notes: $err',
                    style: AppTypography.body.copyWith(color: colors.error),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInitialState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 40,
            color: colors.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Type to search title, body, or tags',
            style: AppTypography.body.copyWith(
              color: colors.textTertiary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsState(AppColors colors, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No notes found',
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try another search or create a new note.',
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontSize: 15,
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
        builder: (_) => EditorScreen(note: note),
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
          ),
        ),
      );
    }
  }
}
