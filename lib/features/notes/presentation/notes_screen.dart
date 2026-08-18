import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_fab.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/notes_provider.dart';
import '../domain/note_model.dart';
import 'widgets/note_date_header.dart';
import 'widgets/note_empty_state.dart';
import 'widgets/note_list_tile.dart';
import 'widgets/tags_filter_bar.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _selectedNoteIdForTablet;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLayout = screenWidth >= AppSpacing.maxContentWidth;

    if (isTabletLayout) {
      return _buildTabletLayout(context, colors);
    }

    return _buildPhoneLayout(context, colors);
  }

  Widget _buildPhoneLayout(BuildContext context, AppColors colors) {
    final groupedNotesAsync = ref.watch(groupedNotesStreamProvider);
    final selectedFilter = ref.watch(selectedTagFilterProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          selectedFilter != null ? '#$selectedFilter' : 'Notes',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 24,
          ),
        ),
        actions: [
          QuietIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search notes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          QuietIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const TagsFilterBar(),
            Expanded(
              child: groupedNotesAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return NoteEmptyState(
                      onCreateNote: () => _createAndOpenNote(context),
                      tagFilter: selectedFilter,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _calculateTotalItemCount(groups),
                    itemBuilder: (context, index) {
                      return _buildGroupedItem(context, groups, index);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading notes: $err',
                    style: AppTypography.body.copyWith(color: colors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: QuietFab(
        onPressed: () => _createAndOpenNote(context),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, AppColors colors) {
    final groupedNotesAsync = ref.watch(groupedNotesStreamProvider);
    final selectedFilter = ref.watch(selectedTagFilterProvider);
    final allNotesAsync = ref.watch(filteredNotesStreamProvider);

    // If a note was selected, watch it
    Note? activeNote;
    if (_selectedNoteIdForTablet != null) {
      allNotesAsync.whenData((notes) {
        final matches = notes.where((n) => n.id == _selectedNoteIdForTablet);
        if (matches.isNotEmpty) {
          activeNote = matches.first;
        }
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Left Master Sidebar
            SizedBox(
              width: AppSpacing.sidebarWidth,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: colors.divider, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Sidebar Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedFilter != null
                                  ? '#$selectedFilter'
                                  : 'Notes',
                              style: AppTypography.title.copyWith(
                                color: colors.textPrimary,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          QuietIconButton(
                            icon: Icons.search_rounded,
                            tooltip: 'Search',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SearchScreen()),
                              );
                            },
                          ),
                          QuietIconButton(
                            icon: Icons.settings_outlined,
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                          QuietIconButton(
                            icon: Icons.add_rounded,
                            tooltip: 'New note',
                            isActive: true,
                            onPressed: () => _createAndOpenNoteTablet(),
                          ),
                        ],
                      ),
                    ),
                    const TagsFilterBar(),
                    Divider(color: colors.divider, height: 1),
                    Expanded(
                      child: groupedNotesAsync.when(
                        data: (groups) {
                          if (groups.isEmpty) {
                            return NoteEmptyState(
                              onCreateNote: () => _createAndOpenNoteTablet(),
                              tagFilter: selectedFilter,
                            );
                          }

                          return ListView.builder(
                            itemCount: _calculateTotalItemCount(groups),
                            itemBuilder: (context, index) {
                              return _buildGroupedItem(
                                context,
                                groups,
                                index,
                                isTablet: true,
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Error: $err',
                            style:
                                AppTypography.body.copyWith(color: colors.error),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Detail Area
            Expanded(
              child: activeNote != null
                  ? KeyedSubtree(
                      key: ValueKey(activeNote!.id),
                      child: EditorScreen(
                        note: activeNote!,
                        autoFocusBody: false,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Select or create a note',
                        style: AppTypography.body.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateTotalItemCount(List<dynamic> groups) {
    var count = 0;
    for (final g in groups) {
      count += 1; // Section header
      count += (g.notes.length as int); // Notes in this group
    }
    return count;
  }

  Widget _buildGroupedItem(
    BuildContext context,
    List<dynamic> groups,
    int index, {
    bool isTablet = false,
  }) {
    var accumulated = 0;

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (index == accumulated) {
        return NoteDateHeader(
          title: group.header,
          isFirst: i == 0,
        );
      }
      accumulated++;

      final noteIndex = index - accumulated;
      if (noteIndex < group.notes.length) {
        final note = group.notes[noteIndex] as Note;

        return Dismissible(
          key: ValueKey('dismiss_${note.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: context.appColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
          onDismissed: (_) {
            _deleteNoteWithUndo(note);
          },
          child: NoteListTile(
            note: note,
            isSelected: isTablet && _selectedNoteIdForTablet == note.id,
            onTap: () {
              if (isTablet) {
                setState(() {
                  _selectedNoteIdForTablet = note.id;
                });
              } else {
                _openNote(context, note);
              }
            },
            onTagTap: (tag) {
              ref.read(selectedTagFilterProvider.notifier).state = tag;
            },
            onTogglePin: () {
              ref
                  .read(notesRepositoryProvider)
                  .setPinned(note.id, !note.isPinned);
            },
            onDelete: () {
              _deleteNoteWithUndo(note);
            },
          ),
        );
      }
      accumulated += (group.notes.length as int);
    }

    return const SizedBox.shrink();
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
    final selectedFilter = ref.read(selectedTagFilterProvider);

    final initialTags = selectedFilter != null && selectedFilter.isNotEmpty
        ? [selectedFilter]
        : <String>[];

    final newNote = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      tags: initialTags,
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

  void _createAndOpenNoteTablet() async {
    const uuid = Uuid();
    final now = DateTime.now();
    final selectedFilter = ref.read(selectedTagFilterProvider);

    final initialTags = selectedFilter != null && selectedFilter.isNotEmpty
        ? [selectedFilter]
        : <String>[];

    final newNote = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      tags: initialTags,
    );

    await ref.read(notesRepositoryProvider).saveNote(newNote);

    setState(() {
      _selectedNoteIdForTablet = newNote.id;
    });
  }

  void _deleteNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.deleteNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.saveNote(note);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
