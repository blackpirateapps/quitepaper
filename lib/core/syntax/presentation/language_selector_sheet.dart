import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../application/syntax_language_registry.dart';
import '../domain/syntax_language.dart';

/// Compact, searchable bottom sheet or dialog to select a syntax language.
class LanguageSelectorSheet extends StatefulWidget {
  const LanguageSelectorSheet({
    super.key,
    this.currentLanguageId,
    this.onSelected,
    this.title = 'Select Code Language',
  });

  final String? currentLanguageId;
  final ValueChanged<SyntaxLanguage>? onSelected;
  final String title;

  /// Shows the language selector modal sheet.
  static Future<SyntaxLanguage?> show(
    BuildContext context, {
    String? currentLanguageId,
    String title = 'Select Code Language',
  }) {
    return showModalBottomSheet<SyntaxLanguage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LanguageSelectorSheet(
        currentLanguageId: currentLanguageId,
        title: title,
        onSelected: (lang) => Navigator.of(ctx).pop(lang),
      ),
    );
  }

  @override
  State<LanguageSelectorSheet> createState() => _LanguageSelectorSheetState();
}

class _LanguageSelectorSheetState extends State<LanguageSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<SyntaxLanguage> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = SyntaxLanguageRegistry.instance.allLanguages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filteredLanguages = SyntaxLanguageRegistry.instance.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentClean = widget.currentLanguageId?.toLowerCase().trim();

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
          border: Border.all(color: colors.divider.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: AppTypography.headline.copyWith(color: colors.textPrimary, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: colors.divider),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search language or extension…',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textTertiary),
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
                onChanged: _onSearch,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Language List
          Expanded(
            child: _filteredLanguages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No matching languages found',
                        style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredLanguages.length,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final lang = _filteredLanguages[index];
                      final isSelected = lang.id.toLowerCase() == currentClean ||
                          lang.aliases.any((a) => a.toLowerCase() == currentClean);

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        tileColor: isSelected ? colors.accent.withValues(alpha: 0.12) : null,
                        title: Row(
                          children: [
                            Text(
                              lang.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: isSelected ? colors.accent : colors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '(${lang.id})',
                              style: AppTypography.caption.copyWith(
                                color: colors.textTertiary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        subtitle: lang.category != null
                            ? Text(
                                lang.category!,
                                style: AppTypography.caption.copyWith(color: colors.textSecondary),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(Icons.check_rounded, color: colors.accent, size: 18)
                            : null,
                        onTap: () {
                          widget.onSelected?.call(lang);
                          Navigator.of(context).pop(lang);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
}
