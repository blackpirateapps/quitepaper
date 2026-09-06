import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../../application/notes_provider.dart';
import '../../application/notes_query_provider.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_model.dart';
import '../widgets/note_empty_state.dart';
import '../widgets/notes_loading_more_indicator.dart';
import 'editorial_list_header.dart';
import 'editorial_note_row.dart';

/// Standalone Editorial notes list view container.
/// Renders a continuous, content-first list without date section headers,
/// with dynamic collection header, inline attachments, and subtle hairline dividers.
class EditorialNotesList extends ConsumerWidget {
  const EditorialNotesList({
    super.key,
    required this.isTablet,
    this.selectedNoteId,
    required this.onNoteSelected,
    required this.onCreateNote,
    required this.onOpenSearch,
    this.isSidebarVisible = true,
    this.onToggleSidebar,
    this.onEmptyTrash,
    this.onHideNoteList,
    required this.isMultiSelecting,
    required this.selectedNoteIds,
    required this.onToggleNoteMultiSelect,
    required this.onExitMultiSelect,
    required this.onArchiveNoteWithUndo,
    required this.onTrashNoteWithUndo,
    required this.onRestoreNoteWithUndo,
    required this.onUnarchiveNoteWithUndo,
    required this.onDeletePermanently,
  });

  final bool isTablet;
  final String? selectedNoteId;
  final ValueChanged<Note> onNoteSelected;
  final VoidCallback onCreateNote;
  final VoidCallback onOpenSearch;
  final bool isSidebarVisible;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onEmptyTrash;
  final VoidCallback? onHideNoteList;
  final bool isMultiSelecting;
  final Set<String> selectedNoteIds;
  final ValueChanged<String> onToggleNoteMultiSelect;
  final VoidCallback onExitMultiSelect;
  final ValueChanged<Note> onArchiveNoteWithUndo;
  final ValueChanged<Note> onTrashNoteWithUndo;
  final ValueChanged<Note> onRestoreNoteWithUndo;
  final ValueChanged<Note> onUnarchiveNoteWithUndo;
  final ValueChanged<Note> onDeletePermanently;

  String _getDestinationTitle(AppDestination destination, String? selectedTag) {
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
        return selectedTag != null && selectedTag.isNotEmpty
            ? '#$selectedTag'
            : 'Tags';
      case AppDestination.tagBrowser:
        return 'Tags';
      case AppDestination.allJournalEntries:
        return 'All Entries';
      case AppDestination.onThisDay:
        return 'On This Day';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final destination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final collectionState = ref.watch(notesCollectionProvider);
    final query = ref.watch(notesQueryProvider);
    final repository = ref.watch(notesRepositoryProvider);
    final title = _getDestinationTitle(destination, selectedTag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header (Normal Editorial or Multi-select toolbar)
        if (isMultiSelecting)
          _buildMultiSelectHeader(context, ref, colors, destination, repository)
        else
          EditorialListHeader(
            title: title,
            destination: destination,
            isTablet: isTablet,
            isSidebarVisible: isSidebarVisible,
            onToggleSidebar: onToggleSidebar,
            onCreateNote: onCreateNote,
            onOpenSearch: onOpenSearch,
            onEmptyTrash: onEmptyTrash,
            onHideNoteList: onHideNoteList,
          ),

        // 2. Note list content
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 800) {
                ref.read(notesCollectionProvider.notifier).loadMore();
              }
              return false;
            },
            child: collectionState.initialLoading
                ? const Center(
                    child: CircularProgressIndicator.adaptive(),
                  )
                : collectionState.notes.isEmpty
                    ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: SizedBox(
                          height: 400,
                          child: NoteEmptyState(
                            onCreateNote: onCreateNote,
                            destination: destination,
                            tagFilter: selectedTag,
                            hasActiveFilters: query.filter.hasAdvancedFilters,
                            onClearFilters: () => ref
                                .read(notesQueryProvider.notifier)
                                .clearAllFilters(),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          top: 4.0,
                          bottom: isTablet ? 32.0 : 96.0,
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: collectionState.notes.length + 1,
                        itemBuilder: (context, index) {
                          if (index == collectionState.notes.length) {
                            return NotesLoadingMoreIndicator(
                              loadingMore: collectionState.loadingMore,
                              error: collectionState.error,
                              onRetry: () => ref
                                  .read(notesCollectionProvider.notifier)
                                  .retry(),
                            );
                          }

                          final note = collectionState.notes[index];
                          final isSelected =
                              isTablet && selectedNoteId == note.id;
                          final isItemMultiSelected =
                              selectedNoteIds.contains(note.id);

                          return _buildDismissibleItem(
                            context: context,
                            ref: ref,
                            note: note,
                            destination: destination,
                            repository: repository,
                            isSelected: isSelected,
                            isItemMultiSelected: isItemMultiSelected,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildDismissibleItem({
    required BuildContext context,
    required WidgetRef ref,
    required Note note,
    required AppDestination destination,
    required NotesRepository repository,
    required bool isSelected,
    required bool isItemMultiSelected,
  }) {
    final colors = context.appColors;

    DismissDirection dismissDirection;
    Widget? background;
    Widget? secondaryBackground;

    if (destination == AppDestination.trash) {
      dismissDirection = DismissDirection.startToEnd;
      background = Container(
        color: colors.success,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.restore_rounded, color: Colors.white),
      );
    } else if (destination == AppDestination.archive) {
      dismissDirection = DismissDirection.horizontal;
      background = Container(
        color: colors.tagBackground,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Icon(Icons.unarchive_outlined, color: colors.textPrimary),
      );
      secondaryBackground = Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      );
    } else {
      dismissDirection = DismissDirection.horizontal;
      background = Container(
        color: colors.tagBackground,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Icon(Icons.archive_outlined, color: colors.accent),
      );
      secondaryBackground = Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      );
    }

    return Dismissible(
      key: ValueKey('editorial_dismiss_${note.id}'),
      direction: dismissDirection,
      background: background,
      secondaryBackground: secondaryBackground,
      onDismissed: (direction) {
        if (destination == AppDestination.trash) {
          onRestoreNoteWithUndo(note);
        } else if (destination == AppDestination.archive) {
          if (direction == DismissDirection.startToEnd) {
            onUnarchiveNoteWithUndo(note);
          } else {
            onTrashNoteWithUndo(note);
          }
        } else {
          if (direction == DismissDirection.startToEnd) {
            onArchiveNoteWithUndo(note);
          } else {
            onTrashNoteWithUndo(note);
          }
        }
      },
      child: EditorialNoteRow(
        note: note,
        isSelected: isSelected,
        isMultiSelecting: isMultiSelecting,
        isItemMultiSelected: isItemMultiSelected,
        onItemMultiSelectToggle: () => onToggleNoteMultiSelect(note.id),
        onTap: () => onNoteSelected(note),
        onTagTap: (tag) {
          ref.read(currentDestinationProvider.notifier).state =
              AppDestination.tag;
          ref.read(selectedTagFilterProvider.notifier).state = tag;
          ref.read(notesQueryProvider.notifier).setTag(tag);
        },
        onTogglePin: () {
          repository.setPinned(note.id, !note.isPinned);
          ref.read(notesCollectionProvider.notifier).refresh();
        },
        onArchive: () => onArchiveNoteWithUndo(note),
        onUnarchive: () => onUnarchiveNoteWithUndo(note),
        onTrash: () => onTrashNoteWithUndo(note),
        onRestore: () => onRestoreNoteWithUndo(note),
        onDeletePermanently: () => onDeletePermanently(note),
        onDelete: () => onTrashNoteWithUndo(note),
      ),
    );
  }

  Widget _buildMultiSelectHeader(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    AppDestination destination,
    NotesRepository repository,
  ) {
    final count = selectedNoteIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.divider, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          QuietIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close selection',
            onPressed: onExitMultiSelect,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count selected',
              style: AppTypography.headline.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
            ),
          ),
          if (destination == AppDestination.trash) ...[
            QuietIconButton(
              icon: Icons.restore_rounded,
              tooltip: 'Restore selected',
              onPressed: () async {
                final ids = selectedNoteIds.toList();
                await repository.restoreNotes(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                onExitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
                final ids = selectedNoteIds.toList();
                final confirmed =
                    await PermanentDeleteDialog.show(context, count: count);
                if (confirmed) {
                  await repository.deletePermanentlyBatch(ids);
                  for (final id in ids) {
                    ref
                        .read(notesCollectionProvider.notifier)
                        .removeLocalNote(id);
                  }
                  onExitMultiSelect();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
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
            QuietIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Unarchive selected',
              onPressed: () async {
                final ids = selectedNoteIds.toList();
                await repository.unarchiveNotes(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                onExitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
                final ids = selectedNoteIds.toList();
                await repository.trashNotes(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                onExitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
            QuietIconButton(
              icon: Icons.archive_outlined,
              tooltip: 'Archive selected',
              onPressed: () async {
                final ids = selectedNoteIds.toList();
                await repository.archiveNotes(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                onExitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
                final ids = selectedNoteIds.toList();
                await repository.trashNotes(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                onExitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
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
        ],
      ),
    );
  }
}
