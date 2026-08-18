import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_fab.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sidebar/presentation/sidebar_view.dart';
import '../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../application/notes_provider.dart';
import '../data/notes_repository.dart';
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
  final Set<String> _selectedNoteIds = {};
  bool _isMultiSelecting = false;

  bool _shouldAutoFocusTablet = false;

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelecting = false;
      _selectedNoteIds.clear();
    });
  }

  void _toggleNoteMultiSelect(String id) {
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
        if (_selectedNoteIds.isEmpty) {
          _isMultiSelecting = false;
        }
      } else {
        _selectedNoteIds.add(id);
      }
    });
  }

  String _getDestinationTitle(AppDestination destination, String? selectedTag) {
    if (selectedTag != null && selectedTag.isNotEmpty) {
      return '#$selectedTag';
    }
    switch (destination) {
      case AppDestination.allNotes:
        return 'Notes';
      case AppDestination.pinned:
        return 'Pinned';
      case AppDestination.archive:
        return 'Archive';
      case AppDestination.trash:
        return 'Trash';
      case AppDestination.tag:
        return 'Tags';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLayout = screenWidth >= 900.0;

    if (isTabletLayout) {
      return _buildTabletLayout(context, colors);
    }

    return _buildPhoneLayout(context, colors);
  }

  Widget _buildPhoneLayout(BuildContext context, AppColors colors) {
    final destination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final groupedNotesAsync = ref.watch(groupedNotesStreamProvider);
    final repository = ref.watch(notesRepositoryProvider);

    final title = _getDestinationTitle(destination, selectedTag);

    return Scaffold(
      backgroundColor: colors.background,
      drawer: Drawer(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: AppRadii.rMd),
        ),
        width: 300,
        child: SidebarView(
          onItemSelected: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      appBar: _isMultiSelecting
          ? _buildMultiSelectAppBar(context, colors, destination, repository)
          : AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Builder(
                builder: (scaffoldCtx) => QuietIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Open navigation',
                  onPressed: () {
                    Scaffold.of(scaffoldCtx).openDrawer();
                  },
                ),
              ),
              title: Row(
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (selectedTag != null && destination != AppDestination.tag) ...[
                    const SizedBox(width: AppSpacing.xs),
                    GestureDetector(
                      onTap: () {
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
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
                if (destination == AppDestination.trash) ...[
                  QuietIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: 'Empty trash',
                    onPressed: () => _confirmEmptyTrash(context),
                  ),
                ],
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
            if (destination == AppDestination.allNotes ||
                destination == AppDestination.tag)
              const TagsFilterBar(),
            Expanded(
              child: groupedNotesAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return NoteEmptyState(
                      onCreateNote: () => _createAndOpenNote(context),
                      destination: destination,
                      tagFilter: selectedTag,
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
      floatingActionButton: (destination == AppDestination.allNotes ||
              destination == AppDestination.pinned ||
              destination == AppDestination.tag)
          ? QuietFab(
              onPressed: () => _createAndOpenNote(context),
            )
          : null,
    );
  }

  AppBar _buildMultiSelectAppBar(
    BuildContext context,
    AppColors colors,
    AppDestination destination,
    NotesRepository repository,
  ) {
    final count = _selectedNoteIds.length;

    return AppBar(
      backgroundColor: colors.surface,
      elevation: 1,
      leading: QuietIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close selection',
        onPressed: _exitMultiSelect,
      ),
      title: Text(
        '$count selected',
        style: AppTypography.headline.copyWith(
          color: colors.textPrimary,
          fontSize: 18,
        ),
      ),
      actions: [
        if (destination == AppDestination.trash) ...[
          // Trash multi-actions: Restore, Delete Permanently
          QuietIconButton(
            icon: Icons.restore_rounded,
            tooltip: 'Restore selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.restoreNotes(ids);
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes restored'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_forever_rounded,
            tooltip: 'Delete permanently',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              final confirmed =
                  await PermanentDeleteDialog.show(context, count: count);
              if (confirmed) {
                await repository.deletePermanentlyBatch(ids);
                _exitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$count notes permanently deleted'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
        ] else if (destination == AppDestination.archive) ...[
          // Archive multi-actions: Unarchive, Move to Trash
          QuietIconButton(
            icon: Icons.unarchive_outlined,
            tooltip: 'Unarchive selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.unarchiveNotes(ids);
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes unarchived'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Move to Trash',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.trashNotes(ids);
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes moved to Trash'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ] else ...[
          // Active multi-actions: Archive, Move to Trash
          QuietIconButton(
            icon: Icons.archive_outlined,
            tooltip: 'Archive selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.archiveNotes(ids);
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes archived'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Move to Trash',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.trashNotes(ids);
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes moved to Trash'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, AppColors colors) {
    final destination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final groupedNotesAsync = ref.watch(groupedNotesStreamProvider);
    final allNotesAsync = ref.watch(filteredNotesStreamProvider);
    final title = _getDestinationTitle(destination, selectedTag);

    // Watch active note if one is selected in tablet mode
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
            // 1. Left Persistent Navigation Sidebar (280dp)
            SizedBox(
              width: 280,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: colors.divider, width: 1),
                  ),
                ),
                child: const SidebarView(),
              ),
            ),

            // 2. Middle Note List Pane (320dp)
            SizedBox(
              width: 320,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: colors.divider, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Middle Pane Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.title.copyWith(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (destination == AppDestination.trash) ...[
                            QuietIconButton(
                              icon: Icons.delete_sweep_outlined,
                              tooltip: 'Empty trash',
                              onPressed: () => _confirmEmptyTrash(context),
                            ),
                          ],
                          QuietIconButton(
                            icon: Icons.add_rounded,
                            tooltip: 'New note',
                            isActive: true,
                            onPressed: () => _createAndOpenNoteTablet(),
                          ),
                        ],
                      ),
                    ),
                    if (destination == AppDestination.allNotes ||
                        destination == AppDestination.tag) ...[
                      const TagsFilterBar(),
                    ],
                    Divider(color: colors.divider, height: 1),
                    Expanded(
                      child: groupedNotesAsync.when(
                        data: (groups) {
                          if (groups.isEmpty) {
                            return NoteEmptyState(
                              onCreateNote: () => _createAndOpenNoteTablet(),
                              destination: destination,
                              tagFilter: selectedTag,
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
                            style: AppTypography.body.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Right Detail Editor Pane
            Expanded(
              child: activeNote != null
                  ? KeyedSubtree(
                      key: ValueKey(activeNote!.id),
                      child: EditorScreen(
                        note: activeNote!,
                        autoFocusBody: _shouldAutoFocusTablet &&
                            _selectedNoteIdForTablet == activeNote!.id,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Select or create a note',
                        style: AppTypography.body.copyWith(
                          color: colors.textTertiary,
                          fontSize: 16,
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
    final destination = ref.watch(currentDestinationProvider);
    final repository = ref.watch(notesRepositoryProvider);
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
        final isSelected = isTablet && _selectedNoteIdForTablet == note.id;
        final isItemMultiSelected = _selectedNoteIds.contains(note.id);

        DismissDirection dismissDirection;
        Widget? background;
        Widget? secondaryBackground;

        if (destination == AppDestination.trash) {
          dismissDirection = DismissDirection.startToEnd;
          background = Container(
            color: context.appColors.success,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.restore_rounded,
              color: Colors.white,
            ),
          );
        } else if (destination == AppDestination.archive) {
          dismissDirection = DismissDirection.horizontal;
          background = Container(
            color: context.appColors.tagBackground,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(
              Icons.unarchive_outlined,
              color: context.appColors.textPrimary,
            ),
          );
          secondaryBackground = Container(
            color: context.appColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          );
        } else {
          // All Notes / Pinned / Tag:
          // Swipe right (startToEnd) -> Archive
          // Swipe left (endToStart) -> Move to Trash
          dismissDirection = DismissDirection.horizontal;
          background = Container(
            color: context.appColors.tagBackground,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(
              Icons.archive_outlined,
              color: context.appColors.accent,
            ),
          );
          secondaryBackground = Container(
            color: context.appColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          );
        }

        return Dismissible(
          key: ValueKey('dismiss_${note.id}'),
          direction: dismissDirection,
          background: background,
          secondaryBackground: secondaryBackground,
          onDismissed: (direction) {
            if (destination == AppDestination.trash) {
              _restoreNoteWithUndo(note);
            } else if (destination == AppDestination.archive) {
              if (direction == DismissDirection.startToEnd) {
                _unarchiveNoteWithUndo(note);
              } else {
                _trashNoteWithUndo(note);
              }
            } else {
              if (direction == DismissDirection.startToEnd) {
                // Swiped to right side -> Archive
                _archiveNoteWithUndo(note);
              } else {
                // Swiped to left side -> Trash
                _trashNoteWithUndo(note);
              }
            }
          },
          child: NoteListTile(
            note: note,
            isSelected: isSelected,
            isMultiSelecting: _isMultiSelecting,
            isItemMultiSelected: isItemMultiSelected,
            onItemMultiSelectToggle: () => _toggleNoteMultiSelect(note.id),
            onTap: () {
              if (isTablet) {
                setState(() {
                  _selectedNoteIdForTablet = note.id;
                  _shouldAutoFocusTablet = false;
                });
              } else {
                _openNote(context, note);
              }
            },
            onTagTap: (tag) {
              ref.read(currentDestinationProvider.notifier).state =
                  AppDestination.tag;
              ref.read(selectedTagFilterProvider.notifier).state = tag;
            },
            onTogglePin: () {
              repository.setPinned(note.id, !note.isPinned);
            },
            onArchive: () {
              _archiveNoteWithUndo(note);
            },
            onUnarchive: () {
              _unarchiveNoteWithUndo(note);
            },
            onTrash: () {
              _trashNoteWithUndo(note);
            },
            onRestore: () {
              _restoreNoteWithUndo(note);
            },
            onDeletePermanently: () {
              _deletePermanently(note);
            },
            onDelete: () {
              _trashNoteWithUndo(note);
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
      _shouldAutoFocusTablet = true;
    });
  }

  void _archiveNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.archiveNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note archived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.unarchiveNote(note.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _unarchiveNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.unarchiveNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note unarchived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.archiveNote(note.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _trashNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.trashNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.restoreFromTrash(note.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _restoreNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.restoreFromTrash(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note restored'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.trashNote(note.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _deletePermanently(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.deletePermanently(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note permanently deleted'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final count = ref.read(trashedNotesCountProvider).valueOrNull ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trash is already empty'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await PermanentDeleteDialog.show(context, count: count);
    if (confirmed) {
      await ref.read(notesRepositoryProvider).emptyTrash();
      setState(() {
        _selectedNoteIdForTablet = null;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trash emptied'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
