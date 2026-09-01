import 'package:flutter/material.dart';
import '../../domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../domain/tag_colors.dart';
import '../../domain/tag_icon_registry.dart';
import '../../domain/tag_model.dart';
import 'tag_color_picker_sheet.dart';
import 'tag_icon_picker_sheet.dart';

/// Editorial dialog for creating a new tag.
class TagCreateDialog extends StatefulWidget {
  const TagCreateDialog({
    super.key,
    required this.existingTags,
    this.initialName,
  });

  final List<String> existingTags;
  final String? initialName;

  static Future<Tag?> show(
    BuildContext context, {
    required List<String> existingTags,
    String? initialName,
  }) {
    return showDialog<Tag>(
      context: context,
      builder: (ctx) => TagCreateDialog(
        existingTags: existingTags,
        initialName: initialName,
      ),
    );
  }

  @override
  State<TagCreateDialog> createState() => _TagCreateDialogState();
}

class _TagCreateDialogState extends State<TagCreateDialog> {
  late final TextEditingController _controller;
  String? _selectedIcon;
  String? _selectedColor;
  bool _isPinned = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final raw = _controller.text.trim();
    final normalized = TagParser.normalizeTag(raw);

    if (normalized.isEmpty) {
      setState(() => _errorText = 'Tag name cannot be empty');
      return;
    }

    if (!TagParser.isValidTag(normalized)) {
      setState(() => _errorText = 'Invalid tag name (use letters, numbers, -, _)');
      return;
    }

    final lowerExisting = widget.existingTags.map(TagParser.normalizeTag).toSet();
    if (lowerExisting.contains(normalized)) {
      setState(() => _errorText = 'A tag with this name already exists');
      return;
    }

    final now = DateTime.now();
    final tag = Tag(
      id: '', // Will be assigned UUID by repository
      name: normalized,
      icon: _selectedIcon,
      color: _selectedColor,
      isPinned: _isPinned,
      pinnedOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    Navigator.of(context).pop(tag);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = TagColors.fromId(_selectedColor);

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'New Tag',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                prefixText: '#',
                prefixStyle: AppTypography.body.copyWith(
                  color: colorDef?.foreground(isDark) ?? colors.accent,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'tag-name',
                hintStyle: AppTypography.body.copyWith(color: colors.textTertiary),
                errorText: _errorText,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide(color: colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide(color: colors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _validateAndSubmit(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Optional Icon and Color Row
            Row(
              children: [
                // Icon selector button
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await TagIconPickerSheet.show(
                        context,
                        currentIconId: _selectedIcon,
                        tagName: _controller.text,
                      );
                      setState(() => _selectedIcon = picked);
                    },
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            TagIconRegistry.getIconData(_selectedIcon),
                            size: 18,
                            color: colorDef?.foreground(isDark) ?? colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedIcon != null ? 'Icon' : 'Add Icon',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Color selector button
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await TagColorPickerSheet.show(
                        context,
                        currentColorId: _selectedColor,
                      );
                      setState(() => _selectedColor = picked);
                    },
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorDef != null ? colorDef.background(isDark) : colors.background,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: colorDef != null ? colorDef.foreground(isDark) : colors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorDef?.foreground(isDark) ?? colors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              colorDef?.label ?? 'Add Color',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: colorDef?.foreground(isDark) ?? colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Pin toggle checkbox
            InkWell(
              onTap: () => setState(() => _isPinned = !_isPinned),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isPinned,
                      onChanged: (val) => setState(() => _isPinned = val ?? false),
                      activeColor: colors.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Pin to top of tag list',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Create',
          variant: QuietButtonVariant.primary,
          onPressed: _validateAndSubmit,
        ),
      ],
    );
  }
}

/// Editorial dialog for renaming an existing tag.
class TagRenameDialog extends StatefulWidget {
  const TagRenameDialog({
    super.key,
    required this.tag,
    required this.existingTags,
  });

  final Tag tag;
  final List<String> existingTags;

  static Future<String?> show(
    BuildContext context, {
    required Tag tag,
    required List<String> existingTags,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => TagRenameDialog(tag: tag, existingTags: existingTags),
    );
  }

  @override
  State<TagRenameDialog> createState() => _TagRenameDialogState();
}

class _TagRenameDialogState extends State<TagRenameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final raw = _controller.text.trim();
    final normalized = TagParser.normalizeTag(raw);

    if (normalized.isEmpty) {
      setState(() => _errorText = 'Tag name cannot be empty');
      return;
    }

    if (!TagParser.isValidTag(normalized)) {
      setState(() => _errorText = 'Invalid tag name (use letters, numbers, -, _)');
      return;
    }

    if (normalized == widget.tag.name) {
      Navigator.of(context).pop();
      return;
    }

    final otherTags = widget.existingTags
        .where((t) => TagParser.normalizeTag(t) != widget.tag.name)
        .map(TagParser.normalizeTag)
        .toSet();

    if (otherTags.contains(normalized)) {
      setState(() => _errorText = 'A tag with this name already exists. Use Merge instead.');
      return;
    }

    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'Rename Tag',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Renaming this tag will update all ${widget.tag.noteCount} associated notes.',
            style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              prefixText: '#',
              prefixStyle: AppTypography.body.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
              errorText: _errorText,
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: colors.divider),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _validateAndSubmit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Rename',
          variant: QuietButtonVariant.primary,
          onPressed: _validateAndSubmit,
        ),
      ],
    );
  }
}

/// Editorial confirmation dialog for deleting a tag.
class TagDeleteDialog extends StatelessWidget {
  const TagDeleteDialog({
    super.key,
    required this.tag,
  });

  final Tag tag;

  static Future<bool?> show(BuildContext context, {required Tag tag}) {
    return showDialog<bool?>(
      context: context,
      builder: (ctx) => TagDeleteDialog(tag: tag),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'Delete #${tag.name}?',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        'This will remove the tag from ${tag.noteCount} note${tag.noteCount == 1 ? '' : 's'}.\n\nYour notes will not be deleted.',
        style: AppTypography.body.copyWith(
          color: colors.textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Delete',
          variant: QuietButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Editorial dialog for merging a source tag into a destination tag.
class TagMergeDialog extends StatefulWidget {
  const TagMergeDialog({
    super.key,
    required this.sourceTag,
    required this.availableTags,
  });

  final Tag sourceTag;
  final List<Tag> availableTags;

  static Future<Tag?> show(
    BuildContext context, {
    required Tag sourceTag,
    required List<Tag> availableTags,
  }) {
    return showDialog<Tag?>(
      context: context,
      builder: (ctx) => TagMergeDialog(
        sourceTag: sourceTag,
        availableTags: availableTags,
      ),
    );
  }

  @override
  State<TagMergeDialog> createState() => _TagMergeDialogState();
}

class _TagMergeDialogState extends State<TagMergeDialog> {
  Tag? _selectedDestination;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
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
    final candidates = widget.availableTags
        .where((t) => t.id != widget.sourceTag.id)
        .where((t) => _query.isEmpty || t.name.toLowerCase().contains(_query))
        .toList();

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'Merge #${widget.sourceTag.name}',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the destination tag. All occurrences of #${widget.sourceTag.name} across ${widget.sourceTag.noteCount} note(s) will be changed to the destination tag, and #${widget.sourceTag.name} will be removed.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Search box
            TextField(
              controller: _searchController,
              style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search destination tag...',
                hintStyle: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: colors.textTertiary),
                filled: true,
                fillColor: colors.background,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide(color: colors.divider),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Tag list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: candidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No other tags available',
                          style: AppTypography.caption.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (ctx, index) {
                        final item = candidates[index];
                        final isSelected = _selectedDestination?.id == item.id;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: colors.tagBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          leading: Icon(
                            TagIconRegistry.getIconData(item.icon),
                            size: 18,
                            color: isSelected ? colors.accent : colors.textSecondary,
                          ),
                          title: Text(
                            '#${item.name}',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          trailing: Text(
                            '${item.noteCount} notes',
                            style: AppTypography.caption.copyWith(color: colors.textTertiary),
                          ),
                          onTap: () => setState(() => _selectedDestination = item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Merge',
          variant: QuietButtonVariant.primary,
          onPressed: _selectedDestination != null
              ? () => Navigator.of(context).pop(_selectedDestination)
              : null,
        ),
      ],
    );
  }
}
