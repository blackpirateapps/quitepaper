import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/journal/domain/journal_place.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/domain/note_model.dart';
import '../application/places_providers.dart';
import 'widgets/place_card.dart';
import 'widgets/place_detail_view.dart';

/// The Places journal surface (§6). A calm, map-free, editorial browser of
/// journal entries grouped by place. Shows a top-level list of place cards and
/// drills in to a single place's entries (sub-grouped by visit). Unlocated and
/// locked entries are silently excluded upstream by [placeListProvider].
class JournalPlacesView extends ConsumerStatefulWidget {
  const JournalPlacesView({
    super.key,
    this.onOpenDrawer,
    this.isTablet = false,
    this.isSidebarVisible = false,
    this.selectedNoteId,
    this.onToggleSidebar,
    this.onNoteSelected,
  });

  /// Open navigation drawer callback for phone layout.
  final VoidCallback? onOpenDrawer;

  /// Whether running within the tablet 3-pane layout.
  final bool isTablet;

  /// Whether the navigation sidebar is visible on tablet layout.
  final bool isSidebarVisible;

  /// Currently selected note ID on tablet layout.
  final String? selectedNoteId;

  /// Toggle navigation sidebar callback for tablet layout.
  final VoidCallback? onToggleSidebar;

  /// Optional callback when an entry is selected (tablet 3-pane layout).
  final void Function(Note note)? onNoteSelected;

  @override
  ConsumerState<JournalPlacesView> createState() => _JournalPlacesViewState();
}

class _JournalPlacesViewState extends ConsumerState<JournalPlacesView> {
  /// The match key of the drilled-in place, or null while on the list.
  String? _openMatchKey;

  void _openPlace(JournalPlace place) {
    setState(() => _openMatchKey = place.matchKey);
  }

  void _closePlace() {
    setState(() => _openMatchKey = null);
  }

  void _handleNoteTap(Note note) {
    if (widget.onNoteSelected != null) {
      widget.onNoteSelected!(note);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(note: note)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final places = ref.watch(placeListProvider);
    final openKey = _openMatchKey;

    // Resolve the drilled-in place; fall back to the list if it vanished
    // (e.g. its last entry was deleted or an alias merge moved it).
    JournalPlace? openPlace;
    if (openKey != null) {
      for (final p in places) {
        if (p.matchKey == openKey) {
          openPlace = p;
          break;
        }
      }
    }

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildTopBar(context, colors, openPlace),
          Expanded(
            child: openPlace != null
                ? PlaceDetailView(
                    place: openPlace,
                    selectedNoteId: widget.selectedNoteId,
                    onNoteTap: _handleNoteTap,
                  )
                : _buildPlaceList(context, colors, places),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppColors colors,
    JournalPlace? openPlace,
  ) {
    final inDetail = openPlace != null;

    Widget leading;
    if (inDetail) {
      leading = QuietIconButton(
        icon: PhosphorIconsRegular.arrowLeft,
        tooltip: 'Back to places',
        onPressed: _closePlace,
      );
    } else if (widget.isTablet) {
      leading = QuietIconButton(
        icon: widget.isSidebarVisible
            ? Icons.menu_open_rounded
            : Icons.view_sidebar_outlined,
        tooltip: widget.isSidebarVisible ? 'Hide navigation' : 'Show navigation',
        onPressed: widget.onToggleSidebar,
      );
    } else {
      leading = QuietIconButton(
        icon: Icons.menu_rounded,
        tooltip: 'Open navigation',
        onPressed: widget.onOpenDrawer,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          leading,
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPlaceList(
    BuildContext context,
    AppColors colors,
    List<JournalPlace> places,
  ) {
    if (places.isEmpty) {
      return const _PlacesEmptyState();
    }

    final totalEntries = places.fold<int>(0, (sum, p) => sum + p.entryCount);
    final granularity = ref.watch(placeGranularityProvider);
    final sortOrder = ref.watch(placeSortOrderProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _PlacesListHeader(
                placeCount: places.length,
                entryCount: totalEntries,
                granularity: granularity,
                sortOrder: sortOrder,
                onGranularity: (g) =>
                    ref.read(placeGranularityProvider.notifier).state = g,
                onSort: (s) =>
                    ref.read(placeSortOrderProvider.notifier).state = s,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 96.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final place = places[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlaceCard(
                          place: place,
                          onTap: () => _openPlace(place),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Divider(
                            color: colors.divider.withValues(alpha: 0.6),
                            height: 1,
                            thickness: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: places.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// Calm learning/empty state (§6.4). Reuses the On This Day empty-state voice.
class _PlacesEmptyState extends StatelessWidget {
  const _PlacesEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsLight.mapPin,
                size: 44,
                color: colors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No places yet.',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Places you write from will gather here.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editorial header for the place list: a large title, a quiet summary line,
/// and the granularity + sort segmented toggles (§6.2). Mirrors the editorial
/// header spacing/typography of On This Day / All Entries.
class _PlacesListHeader extends StatelessWidget {
  const _PlacesListHeader({
    required this.placeCount,
    required this.entryCount,
    required this.granularity,
    required this.sortOrder,
    required this.onGranularity,
    required this.onSort,
  });

  final int placeCount;
  final int entryCount;
  final PlaceGranularity granularity;
  final PlaceSortOrder sortOrder;
  final ValueChanged<PlaceGranularity> onGranularity;
  final ValueChanged<PlaceSortOrder> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final placeLabel = '$placeCount ${placeCount == 1 ? 'place' : 'places'}';
    final entryLabel = '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.mapPin, size: 22, color: colors.accent),
              const SizedBox(width: 8.0),
              Text(
                'PLACES',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'Places',
            style: AppTypography.title.copyWith(
              color: colors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            '$placeLabel · $entryLabel',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SegmentedToggle<PlaceGranularity>(
            selected: granularity,
            onChanged: onGranularity,
            segments: const [
              (value: PlaceGranularity.city, label: 'City'),
              (value: PlaceGranularity.region, label: 'Region'),
              (value: PlaceGranularity.country, label: 'Country'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SegmentedToggle<PlaceSortOrder>(
            selected: sortOrder,
            onChanged: onSort,
            segments: const [
              (value: PlaceSortOrder.frequency, label: 'Frequency'),
              (value: PlaceSortOrder.recency, label: 'Recency'),
              (value: PlaceSortOrder.firstSeen, label: 'First seen'),
              (value: PlaceSortOrder.alphabetical, label: 'A–Z'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.divider, height: 1, thickness: 0.8),
        ],
      ),
    );
  }
}

/// A quiet, single-accent segmented toggle. The selected segment carries a
/// subtle accent-tinted fill; others are plain text. No second hue, no chrome.
class _SegmentedToggle<T> extends StatelessWidget {
  const _SegmentedToggle({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      padding: const EdgeInsets.all(2.0),
      child: Row(
        children: segments.map((seg) {
          final isSelected = seg.value == selected;
          return Expanded(
            child: Semantics(
              selected: isSelected,
              button: true,
              label: seg.label,
              child: Material(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: isSelected ? null : () => onChanged(seg.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7.0),
                    child: Text(
                      seg.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: isSelected ? colors.accent : colors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

