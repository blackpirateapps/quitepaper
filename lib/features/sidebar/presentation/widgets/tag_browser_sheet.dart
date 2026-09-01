import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../tags/domain/tag_icon_registry.dart';

class TagBrowserSheet extends ConsumerStatefulWidget {
  const TagBrowserSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final tagsAsync = ref.watch(allTagsStreamProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

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
                          .where((t) => t.tag.name.toLowerCase().contains(_query))
                          .toList();

                  if (filteredTags.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty ? 'No tags found' : 'No tags match "$_query"',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: filteredTags.length,
                    separatorBuilder: (context, index) => Divider(
                      color: colors.divider.withValues(alpha: 0.4),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredTags[index];
                      final isSelected = selectedTag == item.tag.name;

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        tileColor: isSelected
                            ? colors.tagBackground
                            : Colors.transparent,
                        leading: Icon(
                          TagIconRegistry.getIconData(item.tag.icon),
                          size: 18,
                          color: isSelected ? colors.accent : colors.textSecondary,
                        ),
                        title: Text(
                          item.tag.name,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        trailing: Text(
                          '${item.noteCount}',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.tag;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              item.tag.name;
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading tags: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
