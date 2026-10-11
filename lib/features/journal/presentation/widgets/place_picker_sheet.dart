import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_place.dart';
import '../../../../core/location/location_models.dart';
import '../../../../core/location/location_service.dart';
import '../../../notes/domain/note_metadata_extractor.dart';
import '../../application/places_providers.dart';

/// Bottom sheet that lets the user pick a place for a journal entry (§6.5, the
/// nudge's primary action — now also the editor's "Add location" affordance).
/// Calm ways to pick: type or search a place (device-native geocoder, no
/// external service), use an existing known place, or the current device
/// location. Resolves to the chosen [JournalLocation] via [Navigator.pop], or
/// null when dismissed. No maps/tiles — purely typographic (§0, §8).
class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({super.key});

  /// Shows the sheet and resolves to the picked location, or null if cancelled.
  static Future<JournalLocation?> show(BuildContext context) {
    return showModalBottomSheet<JournalLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlacePickerSheet(),
    );
  }

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  final TextEditingController _customController = TextEditingController();

  /// Current-location fetch in progress.
  bool _isFetching = false;

  /// Debounce timer for as-you-type search.
  Timer? _debounce;

  /// Forward-geocode search in progress.
  bool _isSearching = false;

  /// Resolving coordinates for a tapped search result before popping.
  bool _isResolving = false;

  /// Latest search results for the current query (coordinate-less).
  List<JournalLocation> _results = const <JournalLocation>[];

  /// The query the current [_results] belong to, to drop stale responses.
  String _resultsQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _customController.dispose();
    super.dispose();
  }

  /// Writes a real location drawn from the most recent member entry of [place]
  /// (its cached [NoteMetadata.location]); falls back to the display name as a
  /// coordinate-less address when none can be resolved.
  void _pickKnownPlace(JournalPlace place) {
    final entries = ref.read(placeEntriesProvider(place.matchKey));
    JournalLocation? loc;
    if (entries.isNotEmpty) {
      loc = NoteMetadataExtractor.extract(entries.first).location;
    }
    loc ??= JournalLocation(
      address: place.displayName,
      latitude: 0,
      longitude: 0,
    );
    Navigator.of(context).pop(loc);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _results = const <JournalLocation>[];
        _resultsQuery = '';
      });
      return;
    }
    setState(() {}); // reflect the "Use as typed" row and spinner affordance
    _debounce = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _customController.text.trim();
    if (q.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await LocationService().searchPlaces(q);
    if (!mounted) return;
    // Drop responses for a query the user has already moved past.
    if (_customController.text.trim() != q) return;
    setState(() {
      _isSearching = false;
      _results = results;
      _resultsQuery = q;
    });
  }

  /// Picks a searched place, resolving its coordinates via the native geocoder
  /// so Open-in-Maps and weather work; falls back to the address alone.
  Future<void> _pickSearchResult(JournalLocation result) async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    final resolved = await LocationService().geocodeCoordinates(result.address);
    if (!mounted) return;
    Navigator.of(context).pop(resolved);
  }

  /// Uses whatever the user typed, verbatim, as a coordinate-less place.
  void _useAsTyped() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      JournalLocation(address: text, latitude: 0, longitude: 0),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetching) return;
    setState(() => _isFetching = true);
    try {
      final loc = await LocationService().fetchCurrentLocation();
      if (!mounted) return;
      Navigator.of(context).pop(loc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch location: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _isFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final places = ref.watch(placeListProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'ADD A PLACE',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      _buildTypeOrSearchField(colors),
                      const SizedBox(height: AppSpacing.md),
                      _buildCurrentLocation(colors),
                      if (places.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _SectionLabel(label: 'KNOWN PLACES', colors: colors),
                        const SizedBox(height: AppSpacing.xs),
                        ...places.map((p) => _buildKnownPlaceRow(colors, p)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOrSearchField(AppColors colors) {
    final query = _customController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'TYPE OR SEARCH A PLACE', colors: colors),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _customController,
                  cursorColor: colors.accent,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _runSearch();
                  },
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                    hintText: 'e.g. Kolkata, West Bengal',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              if (_isSearching)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
            ],
          ),
        ),
        if (query.isNotEmpty) _buildSearchResults(colors, query),
      ],
    );
  }

  Widget _buildSearchResults(AppColors colors, String query) {
    if (_isResolving) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, left: 2.0),
        child: Row(
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Adding place…',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final showResults = _resultsQuery == query && _results.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showResults) ...[
          const SizedBox(height: AppSpacing.xs),
          ..._results.map((r) => _buildResultRow(colors, r)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Divider(height: 1, color: colors.divider.withValues(alpha: 0.5)),
          ),
        ],
        _buildUseAsTypedRow(colors, query),
      ],
    );
  }

  Widget _buildResultRow(AppColors colors, JournalLocation result) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: () => _pickSearchResult(result),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
          child: Row(
            children: [
              Icon(Icons.place_outlined, size: 15, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  result.address,
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseAsTypedRow(AppColors colors, String query) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('placePickerUseAsTyped'),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: _isResolving ? null : _useAsTyped,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 15, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: AppTypography.bodySmall.copyWith(color: colors.accent),
                    children: [
                      const TextSpan(text: 'Use '),
                      TextSpan(
                        text: '“$query”',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' as typed'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocation(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: _isFetching ? null : _useCurrentLocation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
              child: Row(
                children: [
                  if (_isFetching)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    )
                  else
                    Icon(Icons.my_location_rounded, size: 15, color: colors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isFetching ? 'Fetching current location...' : 'Use current location',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2.0, top: 2.0),
          child: Text(
            'Where you are now may differ from where this entry was written.',
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKnownPlaceRow(AppColors colors, JournalPlace place) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: () => _pickKnownPlace(place),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          child: Row(
            children: [
              Icon(Icons.place_outlined, size: 15, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  place.displayName,
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                place.entryCount == 1 ? '1 entry' : '${place.entryCount} entries',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: colors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 10.5,
      ),
    );
  }
}
