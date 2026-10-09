import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/journal/application/place_grouping_service.dart';
import '../../../core/journal/domain/journal_place.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/domain/note_model.dart';
import '../application/place_alias_store.dart';
import '../application/places_providers.dart';
import 'widgets/place_card.dart';
import 'widgets/place_detail_view.dart';
import 'widgets/place_edit_dialogs.dart';

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

  /// Whether the list is in multi-select (merge) mode.
  bool _selectionMode = false;

  /// Match keys currently selected for merging.
  final Set<String> _selectedKeys = <String>{};

  void _openPlace(JournalPlace place) {
    setState(() => _openMatchKey = place.matchKey);
  }

  void _closePlace() {
    setState(() => _openMatchKey = null);
  }

  void _enterSelection() {
    setState(() {
      _selectionMode = true;
      _selectedKeys.clear();
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  void _handleCardTap(JournalPlace place) {
    if (_selectionMode) {
      setState(() {
        if (!_selectedKeys.remove(place.matchKey)) {
          _selectedKeys.add(place.matchKey);
        }
      });
    } else {
      _openPlace(place);
    }
  }

  /// A place is "merged" when some other normalized key folds into its match
  /// key (beyond the canonical self-mapping) — only then is Unmerge offered.
  bool _isMerged(Map<String, PlaceAlias> aliases, String matchKey) {
    return aliases.entries
        .any((e) => e.value.canonicalKey == matchKey && e.key != matchKey);
  }

  Future<void> _startMerge(List<JournalPlace> places) async {
    final selected = places
        .where((p) => _selectedKeys.contains(p.matchKey))
        .toList(growable: false);
    if (selected.length < 2) return;

    final chosenName = await PlaceMergeDialog.show(context, places: selected);
    if (chosenName == null || !mounted) return;

    final canonicalKey = PlaceGroupingService.normalizeKey(chosenName);
    ref.read(placeAliasStoreProvider.notifier).merge(
          selected.map((p) => p.matchKey).toList(growable: false),
          canonicalKey: canonicalKey,
          displayName: chosenName,
        );
    _exitSelection();
  }

  Future<void> _showPlaceActions(JournalPlace place) async {
    final aliases = ref.read(placeAliasStoreProvider);
    final merged = _isMerged(aliases, place.matchKey);
    final action = await showPlaceActionsSheet(
      context,
      place: place,
      isMerged: merged,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case PlaceAction.rename:
        await _renamePlace(place);
        break;
      case PlaceAction.unmerge:
        ref
            .read(placeAliasStoreProvider.notifier)
            .unmergeCanonical(place.matchKey);
        // The regrouped constituents replace this place; leave any drill-in.
        if (_openMatchKey == place.matchKey) _closePlace();
        break;
    }
  }

  Future<void> _renamePlace(JournalPlace place) async {
    final newName = await PlaceRenameDialog.show(
      context,
      initialName: place.displayName,
    );
    if (newName == null || !mounted) return;
    ref.read(placeAliasStoreProvider.notifier).rename(
          canonicalKey: place.matchKey,
          displayName: newName,
        );
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

    // Drop any selected keys that no longer exist (e.g. after a regroup).
    if (_selectionMode) {
      final live = {for (final p in places) p.matchKey};
      _selectedKeys.removeWhere((k) => !live.contains(k));
    }

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildTopBar(context, colors, openPlace, places),
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
    List<JournalPlace> places,
  ) {
    final inDetail = openPlace != null;

    Widget leading;
    if (_selectionMode) {
      leading = QuietIconButton(
        icon: PhosphorIconsRegular.x,
        tooltip: 'Cancel selection',
        onPressed: _exitSelection,
      );
    } else if (inDetail) {
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

    final trailing = <Widget>[];
    if (_selectionMode) {
      final count = _selectedKeys.length;
      trailing.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            count == 0 ? 'Select places' : '$count selected',
            style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
      );
      trailing.add(
        _TopBarTextAction(
          label: 'Merge',
          enabled: count >= 2,
          onPressed: () => _startMerge(places),
        ),
      );
    } else if (inDetail) {
      trailing.add(
        QuietIconButton(
          icon: PhosphorIconsRegular.dotsThreeVertical,
          tooltip: 'Place options',
          onPressed: () => _showPlaceActions(openPlace),
        ),
      );
    } else if (places.length >= 2) {
      trailing.add(
        _TopBarTextAction(
          label: 'Select',
          enabled: true,
          onPressed: _enterSelection,
        ),
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
          ...trailing,
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
                selectionMode: _selectionMode,
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
                          selectionMode: _selectionMode,
                          isSelected: _selectedKeys.contains(place.matchKey),
                          onTap: () => _handleCardTap(place),
                          onLongPress: () => _showPlaceActions(place),
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

/// A quiet text action for the top bar (Select / Merge). Carries the single
/// accent when enabled, textTertiary when disabled; no chrome.
class _TopBarTextAction extends StatelessWidget {
  const _TopBarTextAction({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.borderSm,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: AppRadii.borderSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10.0,
          ),
          child: Text(
            label,
            style: AppTypography.bodySmallMedium.copyWith(
              color: enabled ? colors.accent : colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
    this.selectionMode = false,
  });

  final int placeCount;
  final int entryCount;
  final PlaceGranularity granularity;
  final PlaceSortOrder sortOrder;
  final ValueChanged<PlaceGranularity> onGranularity;
  final ValueChanged<PlaceSortOrder> onSort;
  final bool selectionMode;

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
            selectionMode ? 'Tap places to merge' : '$placeLabel · $entryLabel',
            style: AppTypography.bodySmall.copyWith(
              color: selectionMode ? colors.accent : colors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (!selectionMode) ...[
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
          ],
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

