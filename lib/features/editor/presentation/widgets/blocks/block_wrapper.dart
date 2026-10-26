import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../domain/rich_block.dart';
import '../../../application/rich_document_controller.dart';
import 'block_inserter_sheet.dart';

/// Quiet editorial gutter wrapper around an autonomous block in Quiet Paper's Visual Editor.
///
/// In idle state, preserves clean paper aesthetics without visual clutter.
/// On desktop mouse hover or mobile tap, subtly reveals the drag handle (`⠿`)
/// and the insert block button (`+`).
class BlockWrapper extends StatefulWidget {
  const BlockWrapper({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    required this.child,
    this.readOnly = false,
    this.onDelete,
    this.onInsertBelow,
  });

  final RichBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final Widget child;
  final bool readOnly;
  final VoidCallback? onDelete;
  final ValueChanged<RichBlock>? onInsertBelow;

  @override
  State<BlockWrapper> createState() => _BlockWrapperState();
}

class _BlockWrapperState extends State<BlockWrapper> {
  bool _isHovered = false;

  void _showInserterSheet(BuildContext context) {
    if (widget.readOnly) return;
    BlockInserterSheet.show(
      context: context,
      onSelect: (newBlock) {
        if (widget.onInsertBelow != null) {
          widget.onInsertBelow!(newBlock);
        } else {
          widget.controller.insertBlockBelow(widget.blockIndex, newBlock);
        }
      },
    );
  }

  void _showBlockOptionsMenu(BuildContext context) {
    if (widget.readOnly) return;
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(PhosphorIconsRegular.plus, color: colors.textPrimary),
                title: Text('Insert block below', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInserterSheet(context);
                },
              ),
              if (widget.blockIndex > 0)
                ListTile(
                  leading: Icon(PhosphorIconsRegular.arrowUp, color: colors.textPrimary),
                  title: Text('Move up', style: TextStyle(color: colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.moveBlock(widget.blockIndex, widget.blockIndex - 1);
                  },
                ),
              if (widget.blockIndex < widget.controller.document.blocks.length - 1)
                ListTile(
                  leading: Icon(PhosphorIconsRegular.arrowDown, color: colors.textPrimary),
                  title: Text('Move down', style: TextStyle(color: colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.moveBlock(widget.blockIndex, widget.blockIndex + 1);
                  },
                ),
              ListTile(
                leading: Icon(PhosphorIconsRegular.trash, color: colors.error),
                title: Text('Delete block', style: TextStyle(color: colors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.onDelete != null) {
                    widget.onDelete!();
                  } else {
                    widget.controller.deleteBlock(widget.blockIndex);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      return widget.child;
    }

    final colors = context.appColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          // Subtle Gutter Controls anchored to left edge
          Positioned(
            left: -38,
            top: 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              opacity: _isHovered ? 0.75 : 0.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick '+' add button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showInserterSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        PhosphorIconsRegular.plus,
                        size: 15,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  // Drag handle ('⠿') / Context menu tap
                  ReorderableDragStartListener(
                    index: widget.blockIndex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showBlockOptionsMenu(context),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          PhosphorIconsRegular.dotsSixVertical,
                          size: 15,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
