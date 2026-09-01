import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../application/phosphor_catalog_service.dart';
import '../../application/tag_icon_preferences_service.dart';
import '../../domain/tag_icon_definition.dart';
import '../../domain/tag_icon_registry.dart';

/// Modal sheet or responsive dialog for browsing, searching, and selecting a Phosphor tag icon.
class TagIconPickerSheet extends StatefulWidget {
  const TagIconPickerSheet({
    super.key,
    required this.selectedIconId,
    required this.onIconSelected,
    this.tagName = '',
    this.catalogService,
    this.preferencesService,
  });

  final String? selectedIconId;
  final ValueChanged<String?> onIconSelected;
  final String tagName;
  final PhosphorCatalogService? catalogService;
  final TagIconPreferencesService? preferencesService;

  /// Shows the tag icon picker as an adaptive bottom sheet (phones) or centered dialog (tablets).
  static Future<String?> show(
    BuildContext context, {
    String? currentIconId,
    String tagName = '',
    PhosphorCatalogService? catalogService,
    TagIconPreferencesService? preferencesService,
  }) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (isTablet) {
      return showDialog<String?>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
            child: ClipRRect(
              borderRadius: AppRadii.borderLg,
              child: TagIconPickerSheet(
                selectedIconId: currentIconId,
                tagName: tagName,
                catalogService: catalogService,
                preferencesService: preferencesService,
                onIconSelected: (iconId) => Navigator.of(ctx).pop(iconId),
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TagIconPickerSheet(
        selectedIconId: currentIconId,
        tagName: tagName,
        catalogService: catalogService,
        preferencesService: preferencesService,
        onIconSelected: (iconId) => Navigator.of(ctx).pop(iconId),
      ),
    );
  }

  @override
  State<TagIconPickerSheet> createState() => _TagIconPickerSheetState();
}

class _TagIconPickerSheetState extends State<TagIconPickerSheet> {
  late final PhosphorCatalogService _catalogService;
  late final TagIconPreferencesService _preferencesService;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<PhosphorIconDefinition> _icons = [];
  Set<String> _favoriteIds = {};
  List<String> _recentIds = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _hasError = false;
  int _searchGeneration = 0;

  static const List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'recent', 'label': 'Recent'},
    {'id': 'favorites', 'label': 'Favorites'},
    {'id': 'activity', 'label': 'Activity'},
    {'id': 'arrows', 'label': 'Arrows'},
    {'id': 'brands', 'label': 'Brands'},
    {'id': 'buildings', 'label': 'Buildings'},
    {'id': 'communication', 'label': 'Communication'},
    {'id': 'design', 'label': 'Design'},
    {'id': 'development', 'label': 'Development'},
    {'id': 'education', 'label': 'Education'},
    {'id': 'files', 'label': 'Files'},
    {'id': 'finance', 'label': 'Finance'},
    {'id': 'food', 'label': 'Food & Drink'},
    {'id': 'health', 'label': 'Health'},
    {'id': 'maps', 'label': 'Maps & Travel'},
    {'id': 'media', 'label': 'Media'},
    {'id': 'nature', 'label': 'Nature'},
    {'id': 'objects', 'label': 'Objects'},
    {'id': 'people', 'label': 'People'},
    {'id': 'places', 'label': 'Places'},
    {'id': 'science', 'label': 'Science'},
    {'id': 'security', 'label': 'Security'},
    {'id': 'shapes', 'label': 'Shapes'},
    {'id': 'system', 'label': 'System'},
    {'id': 'technology', 'label': 'Technology'},
    {'id': 'transportation', 'label': 'Transportation'},
    {'id': 'weather', 'label': 'Weather'},
  ];

  @override
  void initState() {
    super.initState();
    _catalogService = widget.catalogService ?? PhosphorCatalogService();
    _preferencesService = widget.preferencesService ?? TagIconPreferencesService();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final favorites = await _preferencesService.getFavoriteIconIds();
      final recents = await _preferencesService.getRecentIconIds();
      final catalog = await _catalogService.getCatalog();

      if (!mounted) return;

      setState(() {
        _favoriteIds = favorites;
        _recentIds = recents;
        _icons = catalog;
        _isLoading = false;
      });

      // If a tagName was provided and not empty, check if we can filter/suggest
      if (widget.tagName.isNotEmpty && _searchQuery.isEmpty) {
        _searchQuery = '';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    final generation = ++_searchGeneration;
    _searchQuery = query.trim().toLowerCase();

    final results = await _catalogService.search(
      query: _searchQuery,
      category: _selectedCategory,
      favoriteIds: _favoriteIds,
      recentIds: _recentIds,
      generation: generation,
    );

    if (!mounted || generation != _searchGeneration) return;

    setState(() {
      _icons = results;
    });
  }

  Future<void> _onCategorySelected(String catId) async {
    setState(() {
      _selectedCategory = catId;
    });

    final results = await _catalogService.search(
      query: _searchQuery,
      category: _selectedCategory,
      favoriteIds: _favoriteIds,
      recentIds: _recentIds,
      generation: ++_searchGeneration,
    );

    if (!mounted) return;
    setState(() {
      _icons = results;
    });
  }

  Future<void> _toggleFavorite(String iconId) async {
    HapticFeedback.lightImpact();
    final newFav = await _preferencesService.toggleFavorite(iconId);
    if (!mounted) return;

    setState(() {
      if (newFav) {
        _favoriteIds.add(iconId);
      } else {
        _favoriteIds.remove(iconId);
      }
    });

    // If currently on Favorites category, refresh list
    if (_selectedCategory == 'favorites') {
      _onCategorySelected('favorites');
    }
  }

  void _selectIcon(String iconId) {
    HapticFeedback.selectionClick();
    _preferencesService.addRecentIcon(iconId);
    final key = TagIconRegistry.formatIconKey(iconId);
    widget.onIconSelected(key);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cleanCurrentId = TagIconRegistry.cleanId(widget.selectedIconId);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final sheetHeight = isTablet
        ? 680.0
        : MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isTablet
            ? AppRadii.borderLg
            : const BorderRadius.vertical(top: AppRadii.rLg),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle on phones
            if (!isTablet) ...[
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
            ] else ...[
              const SizedBox(height: AppSpacing.md),
            ],

            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    widget.tagName.isNotEmpty
                        ? 'Choose Icon for #${widget.tagName}'
                        : 'Choose Tag Icon',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (cleanCurrentId != null)
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onIconSelected(null);
                      },
                      icon: Icon(
                        PhosphorIconsRegular.trash,
                        size: 16,
                        color: colors.error,
                      ),
                      label: Text(
                        'Remove Icon',
                        style: AppTypography.caption.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
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
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search 1,500+ icons...',
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
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
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
            const SizedBox(height: AppSpacing.sm),

            // Category filter bar
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final catId = cat['id']!;
                  final label = cat['label']!;
                  final isSelected = _selectedCategory == catId;

                  // Add badge for Favorites or Recent if non-empty
                  String displayLabel = label;
                  if (catId == 'favorites' && _favoriteIds.isNotEmpty) {
                    displayLabel = '$label (${_favoriteIds.length})';
                  } else if (catId == 'recent' && _recentIds.isNotEmpty) {
                    displayLabel = '$label (${_recentIds.length})';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _onCategorySelected(catId),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.tagBackground : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: isSelected ? colors.accent : colors.divider.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (catId == 'favorites') ...[
                              Icon(
                                isSelected ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                                size: 14,
                                color: isSelected ? colors.accent : colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                            ] else if (catId == 'recent') ...[
                              Icon(
                                PhosphorIconsRegular.clockCounterClockwise,
                                size: 14,
                                color: isSelected ? colors.accent : colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              displayLabel,
                              style: AppTypography.caption.copyWith(
                                color: isSelected ? colors.accent : colors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Divider(color: colors.divider, height: 1),

            // Content Area
            Expanded(
              child: _buildBody(colors, cleanCurrentId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors, String? cleanCurrentId) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: colors.accent,
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.warningCircle, size: 36, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Icons unavailable',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _loadInitialData,
              child: Text('Try Again', style: TextStyle(color: colors.accent)),
            ),
          ],
        ),
      );
    }

    if (_icons.isEmpty) {
      final isFav = _selectedCategory == 'favorites';
      final isRecent = _selectedCategory == 'recent';
      final emptyMessage = isFav
          ? 'No favorite icons yet.\nLong-press any icon to add it to favorites.'
          : isRecent
              ? 'No recently chosen icons.'
              : 'No matching icons found.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        childAspectRatio: 1.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _icons.length,
      itemBuilder: (context, index) {
        final item = _icons[index];
        final isSelected = cleanCurrentId == item.id;
        final isFav = _favoriteIds.contains(item.id);

        return _buildIconGridCell(item, isSelected, isFav, colors);
      },
    );
  }

  Widget _buildIconGridCell(
    PhosphorIconDefinition item,
    bool isSelected,
    bool isFav,
    AppColors colors,
  ) {
    return Semantics(
      label: '${item.name}, icon.${isSelected ? ' Selected.' : ''}${isFav ? ' In favorites.' : ''} Double tap to select, long press to favorite.',
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: item.name,
        child: InkWell(
          onTap: () => _selectIcon(item.id),
          onLongPress: () => _toggleFavorite(item.id),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.accentSoft : colors.background,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: isSelected ? colors.accent : colors.divider.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  item.getIconData(PhosphorIconWeight.regular),
                  size: 24,
                  color: isSelected ? colors.accentDark : colors.textPrimary,
                ),
                if (isFav && !isSelected)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Icon(
                      PhosphorIconsFill.star,
                      size: 8,
                      color: colors.accent,
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIconsRegular.check,
                        size: 8,
                        color: colors.surface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
