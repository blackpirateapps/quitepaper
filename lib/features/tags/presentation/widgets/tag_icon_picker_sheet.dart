import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/tag_icon_registry.dart';

/// Modal bottom sheet for browsing, searching, and selecting a tag icon.
class TagIconPickerSheet extends StatefulWidget {
  const TagIconPickerSheet({
    super.key,
    required this.selectedIconId,
    required this.onIconSelected,
    this.tagName = '',
  });

  final String? selectedIconId;
  final ValueChanged<String?> onIconSelected;
  final String tagName;

  static Future<String?> show(
    BuildContext context, {
    String? currentIconId,
    String tagName = '',
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TagIconPickerSheet(
        selectedIconId: currentIconId,
        tagName: tagName,
        onIconSelected: (iconId) => Navigator.of(ctx).pop(iconId),
      ),
    );
  }

  @override
  State<TagIconPickerSheet> createState() => _TagIconPickerSheetState();
}

class _TagIconPickerSheetState extends State<TagIconPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  TagIconCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
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
    final suggestions = widget.tagName.isNotEmpty
        ? TagIconRegistry.suggestIcons(widget.tagName)
        : <TagIconItem>[];

    final filteredIcons = TagIconRegistry.all.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesId = item.id.toLowerCase().contains(_searchQuery);
        final matchesName = item.displayName.toLowerCase().contains(_searchQuery);
        final matchesKeywords = item.keywords.any((kw) => kw.toLowerCase().contains(_searchQuery));
        return matchesId || matchesName || matchesKeywords;
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    'Tag Icon',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (widget.selectedIconId != null)
                    TextButton(
                      onPressed: () => widget.onIconSelected(null),
                      child: Text(
                        'Remove Icon',
                        style: AppTypography.caption.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  QuietIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
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
                          hintText: 'Search icons...',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: colors.textTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Category filter chips
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _buildCategoryChip(
                    label: 'All',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                    colors: colors,
                  ),
                  ...TagIconCategory.values.map((cat) {
                    return _buildCategoryChip(
                      label: cat.displayName,
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                      colors: colors,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Divider(color: colors.divider, height: 1),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Suggestions section if available and not searching
                  if (suggestions.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == null) ...[
                    Text(
                      'SUGGESTED FOR #${widget.tagName.toUpperCase()}',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((item) {
                        return _buildIconTile(item, colors);
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ALL ICONS',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],

                  if (filteredIcons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No icons found',
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredIcons.map((item) {
                        return _buildIconTile(item, colors);
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? colors.tagBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: isSelected ? colors.accent : colors.divider.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? colors.accent : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconTile(TagIconItem item, AppColors colors) {
    final isSelected = widget.selectedIconId == item.id;

    return Tooltip(
      message: item.displayName,
      child: InkWell(
        onTap: () => widget.onIconSelected(item.id),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSoft : colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: isSelected ? colors.accent : colors.divider.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected ? colors.accentDark : colors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
