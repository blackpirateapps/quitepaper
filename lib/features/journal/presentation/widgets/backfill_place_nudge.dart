import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_date_helper.dart';
import '../../../editor/application/frontmatter_editor_helper.dart';
import '../../../notes/domain/note_metadata_extractor.dart';
import '../../../notes/domain/note_model.dart';
import '../../../settings/application/default_settings_provider.dart';
import '../../application/backfill_suppression_store.dart';
import 'place_picker_sheet.dart';

/// Subtle, inline, dismissible nudge offering to backfill a place onto a
/// journal entry that has none (§6.5). Manual only — it never infers location.
///
/// It renders only when ALL hold: the note is a journal entry, is NOT
/// password-protected, has no cached location, the global
/// `suggestPlaceForPastEntries` setting is ON, and this entry's date is not in
/// the device-local suppression set. In every other case it renders nothing.
class BackfillPlaceNudge extends ConsumerStatefulWidget {
  const BackfillPlaceNudge({
    super.key,
    required this.note,
    required this.rawDocument,
    required this.isJournal,
    required this.onDocumentChanged,
  });

  /// The entry being viewed (source of identity, lock state and date).
  final Note note;

  /// The live editor document text to write the location into.
  final String rawDocument;

  /// Whether this entry is a journal entry (note or parsed frontmatter).
  final bool isJournal;

  /// The editor's content-change sink — the SAME path the Properties section
  /// uses, so autosave persists the write.
  final ValueChanged<String> onDocumentChanged;

  @override
  ConsumerState<BackfillPlaceNudge> createState() => _BackfillPlaceNudgeState();
}

class _BackfillPlaceNudgeState extends ConsumerState<BackfillPlaceNudge> {
  /// Ephemeral "Not now" dismissal — persists nothing; resets when the entry
  /// is reopened (the widget is rebuilt fresh), so the nudge may reappear.
  bool _dismissedForNow = false;

  /// This entry's calendar date (`YYYY-MM-DD`) used as the suppression key.
  String _entryDateKey() {
    final parsed = JournalDateHelper.tryParseDateString(widget.note.journalDate);
    if (parsed != null) return JournalDateHelper.toDateString(parsed);
    return JournalDateHelper.toDateString(widget.note.createdAt);
  }

  bool _hasLocation() {
    // Never parse/read location for locked notes (§8) — guarded by the caller
    // checking isPasswordProtected first, but the extractor also nulls it.
    return NoteMetadataExtractor.extract(widget.note).location != null;
  }

  Future<void> _addPlace() async {
    final loc = await PlacePickerSheet.show(context);
    if (loc == null || !mounted) return;
    final updated = FrontmatterEditorHelper.updateLocation(
      documentText: widget.rawDocument,
      location: loc,
    );
    widget.onDocumentChanged(updated);
    // Refresh cached metadata so the nudge (and lists) see the new location.
    NoteMetadataExtractor.invalidate(widget.note.id);
  }

  void _notNow() {
    // Dismiss for now only — persist nothing.
    setState(() => _dismissedForNow = true);
  }

  void _dontAskForThisDay() {
    // Device-local, per-day suppression (not synced).
    ref.read(backfillSuppressionProvider.notifier).suppressDay(_entryDateKey());
  }

  void _dontAskAgain() {
    // Flip the global master switch OFF, then confirm where to re-enable it.
    ref.read(defaultSettingsProvider.notifier).setSuggestPlaceForPastEntries(false);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You can change this later in Settings.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedForNow) return const SizedBox.shrink();

    // Global master switch (§6.6).
    final suggestEnabled =
        ref.watch(defaultSettingsProvider).suggestPlaceForPastEntries;
    if (!suggestEnabled) return const SizedBox.shrink();

    // Journal-only, never on locked notes.
    if (!widget.isJournal) return const SizedBox.shrink();
    if (widget.note.isPasswordProtected) return const SizedBox.shrink();

    // Already located → nothing to backfill.
    if (_hasLocation()) return const SizedBox.shrink();

    // Device-local per-day suppression.
    final suppressed = ref.watch(backfillSuppressionProvider);
    if (suppressed.contains(_entryDateKey())) return const SizedBox.shrink();

    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 15, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Add a place to this entry?',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Padding(
            padding: const EdgeInsets.only(left: 23.0),
            child: Text(
              'Only added when you choose — places are never guessed.',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 23.0),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PrimaryAction(
                  label: 'Add place',
                  colors: colors,
                  onPressed: _addPlace,
                ),
                _QuietAction(
                  label: 'Not now',
                  colors: colors,
                  onPressed: _notNow,
                ),
                _QuietAction(
                  label: "Don't ask again for this day",
                  colors: colors,
                  onPressed: _dontAskForThisDay,
                ),
                _QuietAction(
                  label: "Don't ask again",
                  colors: colors,
                  onPressed: _dontAskAgain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final AppColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.accent,
      borderRadius: BorderRadius.circular(AppRadii.btn),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.btn),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final AppColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.btn),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.btn),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
