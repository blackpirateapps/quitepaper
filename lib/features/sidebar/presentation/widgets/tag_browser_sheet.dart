import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../notes/application/notes_query_provider.dart';
import '../../../tags/application/tag_providers.dart';
import '../../../tags/domain/tag_icon_registry.dart';
import '../../../tags/domain/tag_tree.dart';

class TagBrowserSheet extends ConsumerStatefulWidget {
  const TagBrowserSheet({super.key});

  static Future<void> show(BuildContext context) {
    return QuietAdaptiveModal.show(
      context: context,
      type: AdaptiveModalType.spotlight,
      maxWidth: 520,
      builder: (ctx) => const TagBrowserSheet(),
    );
  }

  @override
  ConsumerState<TagBrowserSheet> createState() => _TagBrowserSheetState();
}

class _TagBrowserSheetState extends ConsumerState<TagBrowserSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = PlatformLayoutHelper.isDesktop(context);
    final tagsAsync = ref.watch(allTagsProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final expandedPaths = ref.watch(expandedTagPathsProvider);

    final content = Column(
      children: [
        const AdaptiveSheetDragHandle(),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Text(
                'All Tags',
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              QuietIconButton(
                icon: PhosphorIconsRegular.x,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Search input
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: isDesktop,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter tags...',
                      hintStyle: AppTypography.bodySmall.copyWith(
                        color: colors.textTertiary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(
                      PhosphorIconsRegular.xCircle,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xs),
        Divider(color: colors.divider, height: 1),

        // Tags list
        Expanded(
          child: tagsAsync.when(
            data: (allTags) {
              final filteredTags = _query.isEmpty
                  ? allTags
                  : allTags
                        .where((t) => t.name.toLowerCase().contains(_query))
                        .toList();

              if (filteredTags.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No tags found'
                        : 'No tags match "$_query"',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                );
              }

              final tree = TagTree.build(filteredTags);
              final flattened = TagTree.flatten(
                tree,
                expandedPaths: expandedPaths,
              );

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: flattened.length,
                separatorBuilder: (context, index) => Divider(
                  color: colors.divider.withValues(alpha: 0.4),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final entry = flattened[index];
                  final node = entry.node;
                  final item = node.tag;
                  final path = node.path?.value ?? item.name;
                  final isSelected = selectedTag == item.name;
                  final isExpanded = expandedPaths.contains(path);
                  final fullLabel = node.path?.token ?? '#${item.name}';

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: AppSpacing.sm + (entry.depth * 16.0),
                      right: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    tileColor: isSelected
                        ? colors.tagBackground
                        : Colors.transparent,
                    leading: Icon(
                      TagIconRegistry.getIconData(item.icon),
                      size: 18,
                      color: isSelected ? colors.accent : colors.textSecondary,
                    ),
                    title: Semantics(
                      label: fullLabel,
                      child: Text(
                        '#${node.displayName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    subtitle: node.path?.isNested == true
                        ? Text(
                            node.path!.breadcrumb,
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.noteCount}',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        if (node.hasChildren) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 24,
                                height: 24,
                              ),
                              iconSize: 15,
                              icon: Icon(
                                isExpanded
                                    ? PhosphorIconsRegular.caretDown
                                    : PhosphorIconsRegular.caretRight,
                                color: colors.textTertiary,
                              ),
                              tooltip: isExpanded
                                  ? 'Collapse sub-tags'
                                  : 'Expand sub-tags',
                              onPressed: () => ref
                                  .read(expandedTagPathsProvider.notifier)
                                  .toggle(path),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      ref.read(currentDestinationProvider.notifier).state =
                          AppDestination.tag;
                      ref.read(selectedTagFilterProvider.notifier).state =
                          item.name;
                      ref.read(selectedTagIdProvider.notifier).state = item.id;
                      ref.read(notesQueryProvider.notifier).setTag(item.name);
                      Navigator.of(context).pop();
                    },
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (err, _) => Center(child: Text('Error loading tags: $err')),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 520),
        child: content,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
      ),
      child: SafeArea(child: content),
    );
  }
}
