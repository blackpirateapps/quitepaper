import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/presentation/widgets/note_list_tile.dart';
import '../application/tag_providers.dart';
import '../domain/tag_icon_registry.dart';
import '../domain/tag_model.dart';
import 'widgets/tag_action_dialogs.dart';
import 'widgets/tag_color_picker_sheet.dart';
import 'widgets/tag_icon_picker_sheet.dart';

/// Dedicated Tag Detail Screen displaying tag identity, metadata actions, and associated notes.
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({
    super.key,
    required this.tagId,
    this.initialTagName,
  });

  final String tagId;
  final String? initialTagName;

  static Future<void> open(
    BuildContext context, {
    required String tagId,
    String? initialTagName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => TagDetailScreen(
          tagId: tagId,
          initialTagName: initialTagName,
        ),
      ),
    );
  }

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  Future<void> _handleRename(Tag tag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    final existingNames = allTags.map((t) => t.name).toList();

    final newName = await TagRenameDialog.show(
      context,
      tag: tag,
      existingTags: existingNames,
    );

    if (newName != null && newName != tag.name && mounted) {
      final service = ref.read(tagServiceProvider);
      try {
        await service.renameTag(tag.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tag renamed to #$newName'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming tag: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDelete(Tag tag) async {
    final confirmed = await TagDeleteDialog.show(context, tag: tag);
    if (confirmed == true && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.deleteTag(tag.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag #${tag.name} deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleMerge(Tag tag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];

    final destination = await TagMergeDialog.show(
      context,
      sourceTag: tag,
      availableTags: allTags,
    );

    if (destination != null && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.mergeTags(tag.id, destination.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merged #${tag.name} into #${destination.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleChangeIcon(Tag tag) async {
    final newIcon = await TagIconPickerSheet.show(
      context,
      currentIconId: tag.icon,
      tagName: tag.name,
    );
    if (mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagIcon(tag.id, newIcon);
    }
  }

  Future<void> _handleChangeColor(Tag tag) async {
    final newColor = await TagColorPickerSheet.show(
      context,
      currentColorId: tag.color,
    );
    if (mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagColor(tag.id, newColor);
    }
  }

  void _handleCreateNoteInTag(String tagName) {
    final newNote = Note(
      id: const Uuid().v4(),
      title: '',
      content: '#$tagName\n\n',
      tags: [tagName],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => EditorScreen(
          note: newNote,
          autoFocusBody: true,
          initialPreviewMode: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTagsAsync = ref.watch(allTagsProvider);
    final tag = ref.watch(tagByIdProvider(widget.tagId));

    if (tag == null) {
      if (allTagsAsync.isLoading) {
        return Scaffold(
          backgroundColor: colors.background,
          body: const Center(child: CircularProgressIndicator.adaptive()),
        );
      }
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: QuietIconButton(
            icon: PhosphorIconsRegular.arrowLeft,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Tag not found',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    final colorDef = tag.colorDefinition;
    final iconData = TagIconRegistry.getIconData(tag.icon);
    final notesAsync = ref.watch(tagNotesStreamProvider(tag.name));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: PhosphorIconsRegular.arrowLeft,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '#${tag.name}',
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        actions: [
          QuietIconButton(
            icon: tag.isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
            tooltip: tag.isPinned ? 'Unpin tag' : 'Pin tag',
            isActive: tag.isPinned,
            onPressed: () {
              ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(PhosphorIconsRegular.dotsThreeVertical, color: colors.textSecondary, size: 20),
            tooltip: 'Tag actions',
            color: colors.surface,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
            onSelected: (val) {
              switch (val) {
                case 'rename':
                  _handleRename(tag);
                  break;
                case 'icon':
                  _handleChangeIcon(tag);
                  break;
                case 'color':
                  _handleChangeColor(tag);
                  break;
                case 'merge':
                  _handleMerge(tag);
                  break;
                case 'delete':
                  _handleDelete(tag);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Rename', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'icon',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.smiley, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Change icon', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'color',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.palette, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Change color', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'merge',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.gitMerge, size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Merge into...', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.trash, size: 18, color: colors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Delete tag', style: AppTypography.bodySmall.copyWith(color: colors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Hero Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorDef != null
                      ? colorDef.background(isDark)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: colorDef != null
                        ? colorDef.foreground(isDark).withValues(alpha: 0.3)
                        : colors.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorDef != null
                                ? colorDef.foreground(isDark)
                                : colors.tagBackground,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Icon(
                            iconData,
                            size: 24,
                            color: colorDef != null ? Colors.white : colors.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${tag.name}',
                                style: AppTypography.title.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              notesAsync.when(
                                data: (notes) => Text(
                                  '${notes.length} note${notes.length == 1 ? '' : 's'}',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                loading: () => Text(
                                  'Loading...',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                error: (e, s) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Quick Action Chips Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: Icon(
                            tag.isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
                            size: 14,
                            color: tag.isPinned ? colors.accent : colors.textSecondary,
                          ),
                          label: Text(tag.isPinned ? 'Pinned' : 'Pin'),
                          labelStyle: AppTypography.caption.copyWith(
                            color: tag.isPinned ? colors.accent : colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: colors.background,
                          side: BorderSide(
                            color: tag.isPinned ? colors.accent : colors.divider,
                          ),
                          onPressed: () {
                            ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
                          },
                        ),
                        ActionChip(
                          avatar: Icon(PhosphorIconsRegular.palette, size: 14, color: colors.textSecondary),
                          label: Text(colorDef?.label ?? 'Color'),
                          labelStyle: AppTypography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: colors.background,
                          side: BorderSide(color: colors.divider),
                          onPressed: () => _handleChangeColor(tag),
                        ),
                        ActionChip(
                          avatar: Icon(PhosphorIconsRegular.smiley, size: 14, color: colors.textSecondary),
                          label: Text(tag.iconItem?.name ?? TagIconRegistry.cleanId(tag.icon) ?? 'Icon'),
                          labelStyle: AppTypography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: colors.background,
                          side: BorderSide(color: colors.divider),
                          onPressed: () => _handleChangeIcon(tag),
                        ),
                        ActionChip(
                          avatar: Icon(PhosphorIconsRegular.pencilSimple, size: 14, color: colors.textSecondary),
                          label: const Text('Rename'),
                          labelStyle: AppTypography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          backgroundColor: colors.background,
                          side: BorderSide(color: colors.divider),
                          onPressed: () => _handleRename(tag),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Notes List
          notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsRegular.notePencil,
                            size: 48,
                            color: colors.textTertiary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No notes with #${tag.name}',
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Create a note or add #${tag.name} to existing notes.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          QuietButton(
                            label: 'New Note with Tag',
                            icon: PhosphorIconsRegular.plus,
                            variant: QuietButtonVariant.primary,
                            onPressed: () => _handleCreateNoteInTag(tag.name),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final note = notes[index];
                      return NoteListTile(
                        note: note,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditorScreen(
                                note: note,
                                initialPreviewMode: true,
                              ),
                            ),
                          );
                        },
                        onTogglePin: () {
                          ref.read(notesRepositoryProvider).setPinned(note.id, !note.isPinned);
                        },
                        onArchive: () {
                          ref.read(notesRepositoryProvider).archiveNote(note.id);
                        },
                        onTrash: () {
                          ref.read(notesRepositoryProvider).trashNote(note.id);
                        },
                      );
                    },
                    childCount: notes.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error loading notes: $err', style: AppTypography.bodySmall.copyWith(color: colors.error)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        tooltip: 'New note with #${tag.name}',
        onPressed: () => _handleCreateNoteInTag(tag.name),
        child: const Icon(PhosphorIconsRegular.plus),
      ),
    );
  }
}
