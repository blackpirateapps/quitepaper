import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../domain/markdown_table.dart';
import '../../../domain/rich_block.dart';

const _uuid = Uuid();

/// Editorial sheet to quickly insert any block type below the active block.
class BlockInserterSheet extends StatelessWidget {
  const BlockInserterSheet({
    super.key,
    required this.onSelect,
  });

  final ValueChanged<RichBlock> onSelect;

  static void show({
    required BuildContext context,
    required ValueChanged<RichBlock> onSelect,
  }) {
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => BlockInserterSheet(
        onSelect: (block) {
          Navigator.pop(ctx);
          onSelect(block);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final options = <_BlockOption>[
      _BlockOption(
        title: 'Paragraph',
        subtitle: 'Plain text without formatting',
        icon: PhosphorIconsRegular.textT,
        builder: () => ParagraphBlock.empty(_uuid.v4()),
      ),
      _BlockOption(
        title: 'Heading 1',
        subtitle: 'Top-level document title',
        icon: PhosphorIconsRegular.textHOne,
        builder: () => HeadingBlock(id: _uuid.v4(), level: 1),
      ),
      _BlockOption(
        title: 'Heading 2',
        subtitle: 'Major section heading',
        icon: PhosphorIconsRegular.textHTwo,
        builder: () => HeadingBlock(id: _uuid.v4(), level: 2),
      ),
      _BlockOption(
        title: 'Heading 3',
        subtitle: 'Sub-section heading',
        icon: PhosphorIconsRegular.textHThree,
        builder: () => HeadingBlock(id: _uuid.v4(), level: 3),
      ),
      _BlockOption(
        title: 'To-do item',
        subtitle: 'Track tasks with an interactive checkbox',
        icon: PhosphorIconsRegular.checkSquare,
        builder: () => ChecklistItemBlock(id: _uuid.v4(), isChecked: false),
      ),
      _BlockOption(
        title: 'Bulleted list',
        subtitle: 'Create a simple bulleted list',
        icon: PhosphorIconsRegular.listBullets,
        builder: () => BulletedListItemBlock(id: _uuid.v4()),
      ),
      _BlockOption(
        title: 'Numbered list',
        subtitle: 'Create an ordered sequential list',
        icon: PhosphorIconsRegular.listNumbers,
        builder: () => OrderedListItemBlock(id: _uuid.v4(), order: 1),
      ),
      _BlockOption(
        title: 'Quote',
        subtitle: 'Capture quotes or highlighted excerpts',
        icon: PhosphorIconsRegular.quotes,
        builder: () => QuoteBlock(id: _uuid.v4()),
      ),
      _BlockOption(
        title: 'Callout note',
        subtitle: 'Highlight critical editorial notes or tips',
        icon: PhosphorIconsRegular.info,
        builder: () => CalloutBlock(id: _uuid.v4(), kind: CalloutKind.note),
      ),
      _BlockOption(
        title: 'Code block',
        subtitle: 'Monospace fenced code with syntax language',
        icon: PhosphorIconsRegular.code,
        builder: () => CodeBlock(id: _uuid.v4(), language: '', code: ''),
      ),
      _BlockOption(
        title: 'Table',
        subtitle: 'Grid table with rows and columns',
        icon: PhosphorIconsRegular.table,
        builder: () => TableBlock(
          id: _uuid.v4(),
          table: MarkdownTable.empty(rows: 3, columns: 3),
        ),
      ),
      _BlockOption(
        title: 'Divider',
        subtitle: 'Visually separate document sections',
        icon: PhosphorIconsRegular.minus,
        builder: () => HorizontalRuleBlock(id: _uuid.v4()),
      ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'INSERT BLOCK',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: colors.divider.withValues(alpha: 0.3),
                ),
                itemBuilder: (ctx, i) {
                  final opt = options[i];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(opt.icon, size: 18, color: colors.textPrimary),
                    ),
                    title: Text(
                      opt.title,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      opt.subtitle,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    onTap: () => onSelect(opt.builder()),
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

class _BlockOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final RichBlock Function() builder;

  const _BlockOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}
