import 'package:flutter/material.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_place.dart';
import '../../../../core/widgets/quiet_button.dart';
import 'place_card.dart';

/// Result of the merge dialog: the chosen canonical display name (§2.3).
///
/// Returned trimmed and non-empty; the caller derives the normalized canonical
/// key from it via `PlaceGroupingService.normalizeKey`.

/// A calm, single-accent dialog to pick the canonical name for a set of merged
/// places (§2.3). Offers each selected place's name as a choice plus a custom
/// text field, defaulting to the most-frequent selected place's name.
class PlaceMergeDialog extends StatefulWidget {
  const PlaceMergeDialog({super.key, required this.places});

  /// The places being merged (≥2). Order is irrelevant; the default choice is
  /// the most-frequent (then first) place's display name.
  final List<JournalPlace> places;

  /// Shows the dialog and resolves to the chosen display name, or null if
  /// cancelled.
  static Future<String?> show(
    BuildContext context, {
    required List<JournalPlace> places,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PlaceMergeDialog(places: places),
    );
  }

  @override
  State<PlaceMergeDialog> createState() => _PlaceMergeDialogState();
}

class _PlaceMergeDialogState extends State<PlaceMergeDialog> {
  late final TextEditingController _customController;

  /// The chosen candidate name (one of the selected places' names), or null
  /// when the custom field is driving the choice.
  String? _choice;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();
    _choice = _defaultName();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  /// Distinct selected display names, most-frequent place first (stable).
  List<String> _candidateNames() {
    final sorted = List<JournalPlace>.of(widget.places)
      ..sort((a, b) {
        final byCount = b.entryCount.compareTo(a.entryCount);
        if (byCount != 0) return byCount;
        return a.matchKey.compareTo(b.matchKey);
      });
    final seen = <String>{};
    final names = <String>[];
    for (final p in sorted) {
      if (seen.add(p.displayName)) names.add(p.displayName);
    }
    return names;
  }

  String _defaultName() {
    final names = _candidateNames();
    return names.isEmpty ? '' : names.first;
  }

  /// The effective chosen name: the custom field when non-empty, else the
  /// selected candidate.
  String get _chosenName {
    final custom = _customController.text.trim();
    if (custom.isNotEmpty) return custom;
    return _choice ?? '';
  }

  void _submit() {
    final name = _chosenName;
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final candidates = _candidateNames();
    final usingCustom = _customController.text.trim().isNotEmpty;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'Merge places',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combine ${widget.places.length} places into one. '
              'Choose a name to show.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...candidates.map(
              (name) => _NameChoiceRow(
                label: name,
                selected: !usingCustom && _choice == name,
                onTap: () {
                  setState(() {
                    _choice = name;
                    _customController.clear();
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _customController,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Or type a custom name',
                hintStyle:
                    AppTypography.body.copyWith(color: colors.textTertiary),
                filled: true,
                fillColor: colors.background,
                isDense: true,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style:
                AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Merge',
          variant: QuietButtonVariant.primary,
          onPressed: _chosenName.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

/// A single tappable canonical-name choice, selected state carried by the
/// single accent (a filled check circle), no second hue.
class _NameChoiceRow extends StatelessWidget {
  const _NameChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              selected
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsRegular.circle,
              size: 20,
              color: selected ? colors.accent : colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: colors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A calm rename dialog prefilled with the current display name (§2.3).
/// Resolves to the new trimmed name, or null if cancelled/unchanged.
class PlaceRenameDialog extends StatefulWidget {
  const PlaceRenameDialog({super.key, required this.initialName});

  final String initialName;

  static Future<String?> show(
    BuildContext context, {
    required String initialName,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PlaceRenameDialog(initialName: initialName),
    );
  }

  @override
  State<PlaceRenameDialog> createState() => _PlaceRenameDialogState();
}

class _PlaceRenameDialogState extends State<PlaceRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text(
        'Rename place',
        style: AppTypography.headline.copyWith(color: colors.textPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style:
                AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
        QuietButton(
          label: 'Rename',
          variant: QuietButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The per-place action chosen from the actions sheet.
enum PlaceAction { rename, unmerge }

/// A calm bottom sheet offering per-place actions (§2.3): Rename always,
/// Unmerge only when [isMerged]. Resolves to the chosen [PlaceAction] or null.
Future<PlaceAction?> showPlaceActionsSheet(
  BuildContext context, {
  required JournalPlace place,
  required bool isMerged,
}) {
  final colors = context.appColors;
  final name = splitPlaceName(place.displayName).primary;
  return showModalBottomSheet<PlaceAction>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                name,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ActionRow(
              icon: PhosphorIconsRegular.pencilSimple,
              label: 'Rename',
              onTap: () => Navigator.of(ctx).pop(PlaceAction.rename),
            ),
            if (isMerged)
              _ActionRow(
                icon: PhosphorIconsRegular.arrowsOutSimple,
                label: 'Unmerge',
                onTap: () => Navigator.of(ctx).pop(PlaceAction.unmerge),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
