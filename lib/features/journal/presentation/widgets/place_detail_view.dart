import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_place.dart';
import '../../../notes/domain/note_model.dart';
import '../../application/places_providers.dart';
import 'journal_timeline_tile.dart';
import 'place_card.dart';

/// Drill-in view for a single [JournalPlace] (§6.3): a header with the place
/// name / entry count / date span, then the place's entries reverse-
/// chronologically, sub-grouped by visit. No aggregate map (§8).
class PlaceDetailView extends ConsumerWidget {
  const PlaceDetailView({
    super.key,
    required this.place,
    required this.onNoteTap,
    this.selectedNoteId,
  });

  final JournalPlace place;
  final void Function(Note note) onNoteTap;
  final String? selectedNoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final entries = ref.watch(placeEntriesProvider(place.matchKey));
    final visits = ref.watch(placeVisitsProvider(place.matchKey));
    final byId = {for (final note in entries) note.id: note};

    // Flatten visits → rows (a sub-header followed by its member tiles) so the
    // list is lazily built even for places with many entries.
    final rows = <_DetailRow>[];
    for (final visit in visits) {
      rows.add(_DetailRow.header(visit.label, visit.entryCount));
      for (final id in visit.noteIds) {
        final note = byId[id];
        if (note != null) rows.add(_DetailRow.entry(note));
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _DetailHeader(place: place),
            ),
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No entries for this place.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 96.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final row = rows[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: row.isHeader
                          ? _VisitHeader(label: row.label!, count: row.count!)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                JournalTimelineTile(
                                  note: row.note!,
                                  isSelected: selectedNoteId == row.note!.id,
                                  onTap: () => onNoteTap(row.note!),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                  ),
                                  child: Divider(
                                    color: colors.divider
                                        .withValues(alpha: 0.6),
                                    height: 1,
                                    thickness: 0.8,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
                childCount: rows.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single flattened row in the detail list: either a visit sub-header or a
/// journal entry tile.
class _DetailRow {
  const _DetailRow._({
    required this.isHeader,
    this.label,
    this.count,
    this.note,
  });

  factory _DetailRow.header(String label, int count) =>
      _DetailRow._(isHeader: true, label: label, count: count);

  factory _DetailRow.entry(Note note) =>
      _DetailRow._(isHeader: false, note: note);

  final bool isHeader;
  final String? label;
  final int? count;
  final Note? note;
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.place});

  final JournalPlace place;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final name = splitPlaceName(place.displayName);
    final span = placeDateSpanLabel(place);
    final entryLabel =
        '${place.entryCount} ${place.entryCount == 1 ? 'entry' : 'entries'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.primary,
            style: AppTypography.title.copyWith(
              color: colors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (name.secondary != null) ...[
            const SizedBox(height: 2.0),
            Text(
              name.secondary!,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4.0),
          Text(
            '$entryLabel · $span',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: colors.divider, height: 1, thickness: 0.8),
        ],
      ),
    );
  }
}

/// A quiet visit sub-header, e.g. `October 2024 · 5 entries` (§6.3).
class _VisitHeader extends StatelessWidget {
  const _VisitHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        '$label · $count ${count == 1 ? 'entry' : 'entries'}',
        style: AppTypography.caption.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
