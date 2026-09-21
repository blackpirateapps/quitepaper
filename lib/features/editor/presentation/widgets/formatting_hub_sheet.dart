import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';

/// Bear-inspired comprehensive formatting sheet displaying all available
/// styling, structural, listing, and media formatting options.
class FormattingHubSheet extends StatelessWidget {
  const FormattingHubSheet({
    super.key,
    required this.onSelectFormat,
    this.isBold = false,
    this.isItalic = false,
    this.isStrikethrough = false,
    this.isCode = false,
    this.headingLevel = 0,
    this.isChecklist = false,
    this.isBullet = false,
    this.isOrdered = false,
    this.isQuote = false,
    this.hasTable = true,
    this.hasNoteLink = true,
    this.hasImage = false,
    this.hasScan = false,
    this.hasPdf = false,
    this.hasFile = false,
  });

  final void Function(FormattingOption option) onSelectFormat;
  final bool isBold;
  final bool isItalic;
  final bool isStrikethrough;
  final bool isCode;
  final int headingLevel;
  final bool isChecklist;
  final bool isBullet;
  final bool isOrdered;
  final bool isQuote;
  final bool hasTable;
  final bool hasNoteLink;
  final bool hasImage;
  final bool hasScan;
  final bool hasPdf;
  final bool hasFile;

  static Future<void> show(
    BuildContext context, {
    required void Function(FormattingOption option) onSelectFormat,
    bool isBold = false,
    bool isItalic = false,
    bool isStrikethrough = false,
    bool isCode = false,
    int headingLevel = 0,
    bool isChecklist = false,
    bool isBullet = false,
    bool isOrdered = false,
    bool isQuote = false,
    bool hasTable = true,
    bool hasNoteLink = true,
    bool hasImage = false,
    bool hasScan = false,
    bool hasPdf = false,
    bool hasFile = false,
  }) {
    final colors = context.appColors;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (ctx) => FormattingHubSheet(
        onSelectFormat: onSelectFormat,
        isBold: isBold,
        isItalic: isItalic,
        isStrikethrough: isStrikethrough,
        isCode: isCode,
        headingLevel: headingLevel,
        isChecklist: isChecklist,
        isBullet: isBullet,
        isOrdered: isOrdered,
        isQuote: isQuote,
        hasTable: hasTable,
        hasNoteLink: hasNoteLink,
        hasImage: hasImage,
        hasScan: hasScan,
        hasPdf: hasPdf,
        hasFile: hasFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    final maxSheetHeight = mediaQuery.size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIconsRegular.textAa,
                      size: 18,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Format & Structure',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tap any style to apply to selection or line',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  color: colors.textSecondary,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),

          // Content scroll area
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // SECTION 1: Text Styles
                _buildSectionTitle(context, 'TEXT STYLES'),
                _buildGrid([
                  _FormattingTileData(
                    option: FormattingOption.bold,
                    icon: PhosphorIconsRegular.textB,
                    title: 'Bold',
                    syntax: '**text**',
                    shortcut: 'Ctrl+B',
                    isActive: isBold,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.italic,
                    icon: PhosphorIconsRegular.textItalic,
                    title: 'Italic',
                    syntax: '*text*',
                    shortcut: 'Ctrl+I',
                    isActive: isItalic,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.strikethrough,
                    icon: PhosphorIconsRegular.textStrikethrough,
                    title: 'Strikethrough',
                    syntax: '~~text~~',
                    shortcut: 'Ctrl+Shift+X',
                    isActive: isStrikethrough,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.inlineCode,
                    icon: PhosphorIconsRegular.code,
                    title: 'Inline Code',
                    syntax: '`code`',
                    shortcut: 'Ctrl+`',
                    isActive: isCode,
                  ),
                ], colors),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 2: Structure & Headings
                _buildSectionTitle(context, 'STRUCTURE & HEADINGS'),
                _buildGrid([
                  _FormattingTileData(
                    option: FormattingOption.paragraph,
                    icon: PhosphorIconsRegular.paragraph,
                    title: 'Paragraph',
                    syntax: 'Normal text',
                    shortcut: 'Ctrl+Alt+0',
                    isActive: headingLevel == 0,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.heading1,
                    icon: PhosphorIconsRegular.textH,
                    title: 'Heading 1',
                    syntax: '# Title',
                    shortcut: 'Ctrl+Alt+1',
                    isActive: headingLevel == 1,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.heading2,
                    icon: PhosphorIconsRegular.textH,
                    title: 'Heading 2',
                    syntax: '## Section',
                    shortcut: 'Ctrl+Alt+2',
                    isActive: headingLevel == 2,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.heading3,
                    icon: PhosphorIconsRegular.textH,
                    title: 'Heading 3',
                    syntax: '### Subsection',
                    shortcut: 'Ctrl+Alt+3',
                    isActive: headingLevel == 3,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.quote,
                    icon: PhosphorIconsRegular.quotes,
                    title: 'Blockquote',
                    syntax: '> Quote',
                    shortcut: 'Ctrl+Shift+.',
                    isActive: isQuote,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.codeBlock,
                    icon: PhosphorIconsRegular.codeBlock,
                    title: 'Code Block',
                    syntax: '```code```',
                    shortcut: 'Ctrl+Alt+C',
                  ),
                ], colors),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 3: Lists & Organization
                _buildSectionTitle(context, 'LISTS & ORGANIZATION'),
                _buildGrid([
                  _FormattingTileData(
                    option: FormattingOption.checklist,
                    icon: PhosphorIconsRegular.checkSquare,
                    title: 'To-do List',
                    syntax: '- [ ] Task',
                    shortcut: 'Ctrl+Shift+C',
                    isActive: isChecklist,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.bulletList,
                    icon: PhosphorIconsRegular.listBullets,
                    title: 'Bullet List',
                    syntax: '- Item',
                    shortcut: 'Ctrl+Shift+8',
                    isActive: isBullet,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.orderedList,
                    icon: PhosphorIconsRegular.listNumbers,
                    title: 'Numbered List',
                    syntax: '1. Item',
                    shortcut: 'Ctrl+Shift+7',
                    isActive: isOrdered,
                  ),
                  _FormattingTileData(
                    option: FormattingOption.divider,
                    icon: PhosphorIconsRegular.minus,
                    title: 'Divider Line',
                    syntax: '---',
                    shortcut: 'Ctrl+Alt+-',
                  ),
                ], colors),
                const SizedBox(height: AppSpacing.lg),

                // SECTION 4: Inserts & Media
                _buildSectionTitle(context, 'INSERTS & MEDIA'),
                _buildGrid([
                  if (hasTable)
                    _FormattingTileData(
                      option: FormattingOption.table,
                      icon: PhosphorIconsRegular.table,
                      title: 'Table',
                      syntax: '| Col |',
                      shortcut: 'Ctrl+Alt+T',
                    ),
                  _FormattingTileData(
                    option: FormattingOption.link,
                    icon: PhosphorIconsRegular.link,
                    title: 'Web Link',
                    syntax: '[text](url)',
                    shortcut: 'Ctrl+K',
                  ),
                  if (hasNoteLink)
                    _FormattingTileData(
                      option: FormattingOption.noteLink,
                      icon: PhosphorIconsRegular.fileText,
                      title: 'Note Link',
                      syntax: '[[Note]]',
                      shortcut: 'Ctrl+Shift+L',
                    ),
                  _FormattingTileData(
                    option: FormattingOption.tag,
                    icon: PhosphorIconsRegular.tag,
                    title: 'Tag',
                    syntax: '#tag',
                    shortcut: 'Ctrl+Shift+T',
                  ),
                  if (hasImage)
                    _FormattingTileData(
                      option: FormattingOption.image,
                      icon: PhosphorIconsRegular.image,
                      title: 'Attach Image',
                      syntax: 'Photo / Gallery',
                    ),
                  if (hasScan)
                    _FormattingTileData(
                      option: FormattingOption.scan,
                      icon: PhosphorIconsRegular.scan,
                      title: 'Scan Document',
                      syntax: 'Camera scan',
                    ),
                  if (hasPdf)
                    _FormattingTileData(
                      option: FormattingOption.pdf,
                      icon: PhosphorIconsRegular.filePdf,
                      title: 'Attach PDF',
                      syntax: 'Document',
                    ),
                  if (hasFile)
                    _FormattingTileData(
                      option: FormattingOption.file,
                      icon: PhosphorIconsRegular.paperclip,
                      title: 'Attach File',
                      syntax: 'File picker',
                    ),
                ], colors),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildGrid(List<_FormattingTileData> items, AppColors colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 480 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * AppSpacing.sm) / crossAxisCount;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              height: 68,
              child: _FormattingCardTile(
                data: item,
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectFormat(item.option);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

enum FormattingOption {
  bold,
  italic,
  strikethrough,
  inlineCode,
  paragraph,
  heading1,
  heading2,
  heading3,
  quote,
  codeBlock,
  checklist,
  bulletList,
  orderedList,
  divider,
  table,
  link,
  noteLink,
  tag,
  image,
  scan,
  pdf,
  file,
}

class _FormattingTileData {
  const _FormattingTileData({
    required this.option,
    required this.icon,
    required this.title,
    required this.syntax,
    this.shortcut = '',
    this.isActive = false,
  });

  final FormattingOption option;
  final IconData icon;
  final String title;
  final String syntax;
  final String shortcut;
  final bool isActive;
}

class _FormattingCardTile extends StatelessWidget {
  const _FormattingCardTile({
    required this.data,
    required this.colors,
    required this.onTap,
  });

  final _FormattingTileData data;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = data.isActive
        ? colors.accent.withValues(alpha: isDark ? 0.22 : 0.12)
        : colors.surface;

    final borderColor = data.isActive
        ? colors.accent.withValues(alpha: 0.6)
        : colors.divider;

    final iconColor = data.isActive ? colors.accent : colors.textPrimary;
    final titleColor = data.isActive ? colors.accent : colors.textPrimary;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderMd,
        side: BorderSide(color: borderColor, width: data.isActive ? 1.4 : 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.isActive
                      ? colors.accent.withValues(alpha: 0.2)
                      : colors.divider.withValues(alpha: 0.35),
                  borderRadius: AppRadii.borderSm,
                ),
                child: Center(
                  child: Icon(
                    data.icon,
                    size: 18,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.title,
                            style: AppTypography.bodySmall.copyWith(
                              color: titleColor,
                              fontWeight: data.isActive ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.isActive) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      data.shortcut.isNotEmpty ? data.shortcut : data.syntax,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
