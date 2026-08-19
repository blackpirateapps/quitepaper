import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/typography_provider.dart';

enum FontPickerType {
  heading,
  body,
  code,
}

class FontPickerSheet extends ConsumerStatefulWidget {
  const FontPickerSheet({
    super.key,
    required this.title,
    required this.currentFont,
    required this.type,
    required this.onFontSelected,
  });

  final String title;
  final String? currentFont;
  final FontPickerType type;
  final ValueChanged<String?> onFontSelected;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String? currentFont,
    required FontPickerType type,
    required ValueChanged<String?> onFontSelected,
  }) {
    final colors = context.appColors;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (_) => FontPickerSheet(
        title: title,
        currentFont: currentFont,
        type: type,
        onFontSelected: onFontSelected,
      ),
    );
  }

  @override
  ConsumerState<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends ConsumerState<FontPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDownloading = false;
  String? _downloadMessage;

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

  List<String> _getPresets() {
    switch (widget.type) {
      case FontPickerType.heading:
        return CuratedFonts.headingPresets;
      case FontPickerType.body:
        return CuratedFonts.bodyPresets;
      case FontPickerType.code:
        return CuratedFonts.codePresets;
    }
  }

  Future<void> _importLocalFont() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final loadedFamily = await ref
            .read(typographySettingsProvider.notifier)
            .loadCustomFontFromFile(path);

        if (loadedFamily != null && mounted) {
          widget.onFontSelected(loadedFamily);
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import font: $e')),
        );
      }
    }
  }

  Future<void> _fetchGoogleFont(String fontName) async {
    setState(() {
      _isDownloading = true;
      _downloadMessage = 'Fetching $fontName from Google Fonts...';
    });

    final success = await ref
        .read(typographySettingsProvider.notifier)
        .fetchGoogleFont(fontName);

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadMessage = null;
      });

      if (success) {
        widget.onFontSelected(fontName);
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download "$fontName". Using system fallback.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);

    final allFonts = <String>{
      ..._getPresets(),
      ...typography.customFonts,
    }.toList();

    final filtered = _searchQuery.isEmpty
        ? allFonts
        : allFonts
            .where((f) => f.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final effectiveCurrent = widget.currentFont ??
        (widget.type == FontPickerType.code
            ? CuratedFonts.systemMono
            : CuratedFonts.systemSans);

    final showGoogleSearchOption = _searchQuery.isNotEmpty &&
        !allFonts.any((f) => f.toLowerCase() == _searchQuery.toLowerCase());

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.headline.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: Icon(Icons.file_upload_outlined,
                          size: 16, color: colors.accent),
                      label: Text(
                        'Import .ttf',
                        style: TextStyle(color: colors.accent, fontSize: 13),
                      ),
                      onPressed: _importLocalFont,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    cursorColor: colors.accent,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search or type font name...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 14,
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),

              if (_isDownloading)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(radius: 8),
                      const SizedBox(width: 8),
                      Text(
                        _downloadMessage ?? 'Downloading font...',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Font List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  children: [
                    ...filtered.map((font) {
                      final isSelected = (font == effectiveCurrent) ||
                          (font == 'System Sans' && widget.currentFont == null) ||
                          (font == 'serif' && widget.currentFont == 'serif');

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        title: Text(
                          font,
                          style: TextStyle(
                            fontFamily: (font == 'System Sans' ||
                                    font == 'System Serif')
                                ? (font == 'System Serif' ? 'serif' : null)
                                : font,
                            fontSize: 16,
                            color: isSelected
                                ? colors.accent
                                : colors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded,
                                color: colors.accent, size: 20)
                            : null,
                        onTap: () {
                          widget.onFontSelected(font);
                          Navigator.of(context).pop();
                        },
                      );
                    }),

                    // Fetch from Google Fonts if user searched for a custom name
                    if (showGoogleSearchOption) ...[
                      const Divider(height: 16),
                      ListTile(
                        leading: Icon(Icons.cloud_download_outlined,
                            color: colors.accent),
                        title: Text(
                          'Fetch "$_searchQuery" from Google Fonts',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Downloads and registers font for live rendering',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _fetchGoogleFont(_searchQuery),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
