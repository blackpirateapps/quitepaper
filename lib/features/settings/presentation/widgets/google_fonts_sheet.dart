import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/font_family_helper.dart';

/// Modal sheet for browsing, previewing, and selecting from Google Fonts.
class GoogleFontsSheet extends StatefulWidget {
  const GoogleFontsSheet({
    super.key,
    required this.currentFont,
    required this.onFontSelected,
  });

  final String? currentFont;
  final ValueChanged<String> onFontSelected;

  static Future<void> show(
    BuildContext context, {
    required String? currentFont,
    required ValueChanged<String> onFontSelected,
  }) {
    final colors = context.appColors;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (_) => GoogleFontsSheet(
        currentFont: currentFont,
        onFontSelected: onFontSelected,
      ),
    );
  }

  @override
  State<GoogleFontsSheet> createState() => _GoogleFontsSheetState();
}

class _GoogleFontsSheetState extends State<GoogleFontsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const List<String> _categories = [
    'All',
    'Sans-serif',
    'Serif',
    'Monospace',
    'Handwriting',
    'Display',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GoogleFontEntry> _getFilteredFonts() {
    return FontFamilyHelper.popularGoogleFonts.where((entry) {
      final matchesCategory = _selectedCategory == 'All' || entry.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          entry.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filteredFonts = _getFilteredFonts();

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'Google Fonts',
                      style: AppTypography.headline.copyWith(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    cursorColor: colors.accent,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search Google Fonts (e.g. Inter, Lora, Caveat)...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.textTertiary,
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Category Filter Chips
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = _categories[idx];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accent
                              : colors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? colors.accent
                                : colors.divider.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Fonts List
              Expanded(
                child: filteredFonts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: colors.textTertiary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching fonts found',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.cloud_download_outlined, size: 16),
                                  label: Text('Use "$_searchQuery" directly'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.accent,
                                    side: BorderSide(color: colors.accent),
                                  ),
                                  onPressed: () {
                                    widget.onFontSelected(_searchQuery);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: filteredFonts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final fontEntry = filteredFonts[idx];
                          final isSelected = widget.currentFont == fontEntry.name;

                          TextStyle sampleStyle;
                          try {
                            sampleStyle = GoogleFonts.getFont(
                              fontEntry.name,
                              textStyle: TextStyle(
                                fontSize: 16,
                                color: colors.textPrimary,
                              ),
                            );
                          } catch (_) {
                            sampleStyle = TextStyle(
                              fontFamily: fontEntry.name,
                              fontSize: 16,
                              color: colors.textPrimary,
                            );
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            onTap: () {
                              widget.onFontSelected(fontEntry.name);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accent.withValues(alpha: 0.08)
                                    : colors.background,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.accent
                                      : colors.divider.withValues(alpha: 0.5),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        fontEntry.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: isSelected
                                              ? colors.accent
                                              : colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: colors.divider.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          fontEntry.category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: colors.accent,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The quick brown fox jumps over the lazy dog.',
                                    style: sampleStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
