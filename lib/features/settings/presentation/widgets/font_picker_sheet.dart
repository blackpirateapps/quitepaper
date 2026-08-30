import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/fonts/font_cache_manager.dart';
import '../../../../core/utils/font_family_helper.dart';
import '../../application/typography_provider.dart';
import 'google_fonts_sheet.dart';

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
  String? _downloadingFont;
  double _downloadProgress = 0.0;


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

  void _openGoogleFontsBrowser() {
    Navigator.of(context).pop();
    GoogleFontsSheet.show(
      context,
      currentFont: widget.currentFont,
      onFontSelected: (font) {
        widget.onFontSelected(font);
      },
    );
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

    final showCustomQueryOption = _searchQuery.isNotEmpty &&
        !allFonts.any((f) => f.toLowerCase() == _searchQuery.toLowerCase());

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
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

              // Title and Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AppTypography.headline.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // View Google Fonts Button
                    TextButton.icon(
                      icon: Icon(Icons.language_rounded,
                          size: 15, color: colors.accent),
                      label: Text(
                        'Google Fonts',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _openGoogleFontsBrowser,
                    ),
                    const SizedBox(width: 4),
                    // Import .TTF / .OTF Button
                    TextButton.icon(
                      icon: Icon(Icons.file_upload_outlined,
                          size: 15, color: colors.accent),
                      label: Text(
                        'Import .ttf',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
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
                          (font == 'System Serif' && widget.currentFont == 'serif') ||
                          (font == 'Monospace' && widget.currentFont == 'monospace');

                      final previewFamily = widget.type == FontPickerType.heading
                          ? FontFamilyHelper.resolveHeadingFontFamily(font)
                          : FontFamilyHelper.resolveBodyFontFamily(font);

                      final fontStyle = FontFamilyHelper.getTextStyle(
                        fontFamily: previewFamily,
                        baseStyle: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? colors.accent
                              : colors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      );

                      final isSystem = font == 'System Sans' ||
                          font == 'System Serif' ||
                          font == 'Monospace';
                      final isHosted = FontFamilyHelper.hostedFonts.contains(font);
                      final hostedEntry = isHosted ? FontCacheManager.instance.findHostedFont(font) : null;
                      final isCached = isHosted && FontCacheManager.instance.isFontCached(font);
                      final isDownloading = _downloadingFont == font;

                      Widget? subtitleWidget;
                      if (isSystem) {
                        subtitleWidget = Text(
                          'System default',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        );
                      } else if (isHosted) {
                        if (isDownloading) {
                          subtitleWidget = Text(
                            'Downloading font (${(_downloadProgress * 100).toInt()}%)...',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        } else if (isCached) {
                          subtitleWidget = Text(
                            'Ready offline • ${hostedEntry?.formattedSize ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textTertiary,
                            ),
                          );
                        } else {
                          subtitleWidget = Text(
                            'Tap to download • ${hostedEntry?.formattedSize ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textTertiary,
                            ),
                          );
                        }
                      }

                      Widget? trailingWidget;
                      if (isDownloading) {
                        trailingWidget = SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                            color: colors.accent,
                          ),
                        );
                      } else if (isSelected) {
                        trailingWidget = Icon(
                          Icons.check_rounded,
                          color: colors.accent,
                          size: 20,
                        );
                      } else if (isHosted && !isCached) {
                        trailingWidget = Icon(
                          Icons.cloud_download_outlined,
                          color: colors.textTertiary.withValues(alpha: 0.7),
                          size: 18,
                        );
                      }

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        title: Text(
                          font,
                          style: fontStyle,
                        ),
                        subtitle: subtitleWidget,
                        trailing: trailingWidget,
                        onTap: () async {
                          if (_downloadingFont != null) return;

                          if (font == 'System Sans') {
                            widget.onFontSelected(null);
                            Navigator.of(context).pop();
                            return;
                          } else if (font == 'System Serif') {
                            widget.onFontSelected('serif');
                            Navigator.of(context).pop();
                            return;
                          } else if (font == 'Monospace') {
                            widget.onFontSelected('monospace');
                            Navigator.of(context).pop();
                            return;
                          }

                          if (isHosted && !isCached) {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            setState(() {
                              _downloadingFont = font;
                              _downloadProgress = 0.05;
                            });

                            final success = await FontCacheManager.instance.downloadAndRegisterFont(
                              font,
                              onProgress: (p) {
                                if (mounted) {
                                  setState(() => _downloadProgress = p);
                                }
                              },
                            );

                            if (mounted) {
                              setState(() => _downloadingFont = null);
                            }

                            if (success) {
                              widget.onFontSelected(font);
                              navigator.pop();
                            } else if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to download font $font. Check connection.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {

                            widget.onFontSelected(font);
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    }),


                    if (showCustomQueryOption) ...[
                      const Divider(height: 16),
                      ListTile(
                        leading: Icon(Icons.font_download_outlined,
                            color: colors.accent),
                        title: Text(
                          'Use "$_searchQuery"',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Apply font via Google Fonts or system typography',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          widget.onFontSelected(_searchQuery);
                          Navigator.of(context).pop();
                        },
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
