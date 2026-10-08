import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/application/activity_storage_service.dart';
import '../../../../core/journal/application/weather_service.dart';
import '../../../../core/journal/domain/journal_moment.dart';
import '../../../../core/journal/domain/journal_mood.dart';
import '../../../../core/journal/domain/journal_weather.dart';
import '../../../../core/location/location_models.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/link_launcher_helper.dart';
import '../../application/frontmatter_editor_helper.dart';
import '../../domain/frontmatter_document.dart';
import 'activity_picker_sheet.dart';
import 'moment_picker_sheet.dart';
import 'mood_picker_sheet.dart';
import 'tag_editor_bar.dart';

/// An understated, calm editorial Properties section rendered above the body in WYSIWYG mode.
/// Exposes recognized YAML frontmatter metadata (Author, Created, Source, Description, Location, Tags)
/// as editable properties with direct synchronization back to canonical Markdown source.
class FrontmatterPropertiesSection extends StatefulWidget {
  const FrontmatterPropertiesSection({
    super.key,
    required this.frontmatter,
    required this.rawDocument,
    required this.onDocumentChanged,
    required this.readOnly,
    this.isJournal = false,
    this.initialExpanded = true,
  });

  final FrontmatterDocument frontmatter;
  final String rawDocument;
  final ValueChanged<String> onDocumentChanged;
  final bool readOnly;
  final bool isJournal;
  final bool initialExpanded;

  @override
  State<FrontmatterPropertiesSection> createState() => _FrontmatterPropertiesSectionState();
}

class _FrontmatterPropertiesSectionState extends State<FrontmatterPropertiesSection> {
  late bool _isExpanded;
  bool _isFetchingLocation = false;
  bool _isFetchingWeather = false;

  late final TextEditingController _authorController;
  late final TextEditingController _createdController;
  late final TextEditingController _sourceController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;

    _authorController = TextEditingController(text: widget.frontmatter.author ?? '');
    _createdController = TextEditingController(text: widget.frontmatter.created ?? '');
    _sourceController = TextEditingController(text: widget.frontmatter.source ?? '');
    _descriptionController = TextEditingController(text: widget.frontmatter.description ?? '');
  }

  @override
  void didUpdateWidget(FrontmatterPropertiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frontmatter != widget.frontmatter) {
      if (_authorController.text != (widget.frontmatter.author ?? '')) {
        _authorController.text = widget.frontmatter.author ?? '';
      }
      if (_createdController.text != (widget.frontmatter.created ?? '')) {
        _createdController.text = widget.frontmatter.created ?? '';
      }
      if (_sourceController.text != (widget.frontmatter.source ?? '')) {
        _sourceController.text = widget.frontmatter.source ?? '';
      }
      if (_descriptionController.text != (widget.frontmatter.description ?? '')) {
        _descriptionController.text = widget.frontmatter.description ?? '';
      }
    }
  }

  @override
  void dispose() {
    _authorController.dispose();
    _createdController.dispose();
    _sourceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onPropertySubmitted(String key, String newValue) {
    if (widget.readOnly) return;
    final updated = FrontmatterEditorHelper.updateProperty(
      documentText: widget.rawDocument,
      key: key,
      newValue: newValue.trim(),
    );
    widget.onDocumentChanged(updated);
  }

  void _onAddTag(String tag) {
    if (widget.readOnly) return;
    final currentTags = List<String>.from(widget.frontmatter.tags);
    if (!currentTags.contains(tag)) {
      currentTags.add(tag);
      final updated = FrontmatterEditorHelper.updateTags(
        documentText: widget.rawDocument,
        tags: currentTags,
      );
      widget.onDocumentChanged(updated);
    }
  }

  void _onRemoveTag(String tag) {
    if (widget.readOnly) return;
    final currentTags = List<String>.from(widget.frontmatter.tags);
    currentTags.remove(tag);
    final updated = FrontmatterEditorHelper.updateTags(
      documentText: widget.rawDocument,
      tags: currentTags,
    );
    widget.onDocumentChanged(updated);
  }

  Future<void> _fetchLocation() async {
    if (widget.readOnly || _isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      final locationService = LocationService();
      final loc = await locationService.fetchCurrentLocation();
      if (!mounted) return;
      final updated = FrontmatterEditorHelper.updateLocation(
        documentText: widget.rawDocument,
        location: loc,
      );
      widget.onDocumentChanged(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _removeLocation() {
    if (widget.readOnly) return;
    final updated = FrontmatterEditorHelper.removeLocation(
      documentText: widget.rawDocument,
    );
    widget.onDocumentChanged(updated);
  }

  Future<void> _fetchWeather() async {
    if (widget.readOnly || _isFetchingWeather) return;
    setState(() => _isFetchingWeather = true);
    try {
      double lat = 0.0;
      double lng = 0.0;
      var currentDoc = widget.rawDocument;
      final loc = widget.frontmatter.location;
      if (loc != null && (loc.latitude != 0.0 || loc.longitude != 0.0)) {
        lat = loc.latitude;
        lng = loc.longitude;
      } else {
        final fetchedLoc = await LocationService().fetchCurrentLocation();
        lat = fetchedLoc.latitude;
        lng = fetchedLoc.longitude;
        if (loc == null) {
          currentDoc = FrontmatterEditorHelper.updateLocation(
            documentText: currentDoc,
            location: fetchedLoc,
          );
        }
      }

      final weatherService = WeatherService();
      final weather = await weatherService.fetchWeather(lat, lng);
      if (!mounted) return;
      final updated = FrontmatterEditorHelper.updateWeather(
        documentText: currentDoc,
        weather: weather,
      );
      widget.onDocumentChanged(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch weather: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingWeather = false);
      }
    }
  }

  void _removeWeather() {
    if (widget.readOnly) return;
    final updated = FrontmatterEditorHelper.removeWeather(
      documentText: widget.rawDocument,
    );
    widget.onDocumentChanged(updated);
  }

  void _showMomentPicker() {
    if (widget.readOnly) return;
    MomentPickerSheet.show(
      context: context,
      currentMoment: widget.frontmatter.moment,
      onMomentSelected: (momentKey) {
        final updated = FrontmatterEditorHelper.updateMoment(
          documentText: widget.rawDocument,
          moment: momentKey,
        );
        widget.onDocumentChanged(updated);
      },
      onMomentCleared: () {
        final updated = FrontmatterEditorHelper.removeMoment(
          documentText: widget.rawDocument,
        );
        widget.onDocumentChanged(updated);
      },
    );
  }

  void _removeMoment() {
    if (widget.readOnly) return;
    final updated = FrontmatterEditorHelper.removeMoment(
      documentText: widget.rawDocument,
    );
    widget.onDocumentChanged(updated);
  }

  void _showMoodPicker() {
    if (widget.readOnly) return;
    MoodPickerSheet.show(
      context: context,
      currentMood: widget.frontmatter.mood,
      onMoodSelected: (level) {
        final updated = FrontmatterEditorHelper.updateMood(
          documentText: widget.rawDocument,
          mood: level,
        );
        widget.onDocumentChanged(updated);
      },
      onMoodCleared: () {
        final updated = FrontmatterEditorHelper.removeMood(
          documentText: widget.rawDocument,
        );
        widget.onDocumentChanged(updated);
      },
    );
  }

  void _removeMood() {
    if (widget.readOnly) return;
    final updated = FrontmatterEditorHelper.removeMood(
      documentText: widget.rawDocument,
    );
    widget.onDocumentChanged(updated);
  }

  void _showActivityPicker() {
    if (widget.readOnly) return;
    ActivityPickerSheet.show(
      context: context,
      selectedIds: widget.frontmatter.activities,
      onActivitiesChanged: (newActivities) {
        final updated = FrontmatterEditorHelper.updateActivities(
          documentText: widget.rawDocument,
          activities: newActivities,
        );
        widget.onDocumentChanged(updated);
      },
    );
  }

  void _removeActivity(String activityId) {
    if (widget.readOnly) return;
    final current = List<String>.from(widget.frontmatter.activities);
    current.removeWhere((id) => id.toLowerCase() == activityId.toLowerCase());
    final updated = FrontmatterEditorHelper.updateActivities(
      documentText: widget.rawDocument,
      activities: current,
    );
    widget.onDocumentChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final doc = widget.frontmatter;

    if (!doc.hasFrontmatter) {
      return const SizedBox.shrink();
    }

    if (doc.isMalformed) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: colors.divider.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'YAML frontmatter could not be parsed. Use Edit Markdown to inspect.',
                style: AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final hasAnyDisplayable = doc.hasMatchingSectionProperties;
    if (!hasAnyDisplayable) {
      return const SizedBox.shrink();
    }

    final isDiary = widget.isJournal || doc.isJournal;
    final showAuthor = !isDiary
        ? (doc.author != null || !widget.readOnly)
        : (doc.author != null && doc.author!.trim().isNotEmpty);
    final showSource = !isDiary
        ? (doc.source != null || !widget.readOnly)
        : (doc.source != null && doc.source!.trim().isNotEmpty);
    final showDescription = !isDiary
        ? (doc.description != null || !widget.readOnly)
        : (doc.description != null && doc.description!.trim().isNotEmpty);
    final showLocation = isDiary
        ? (!widget.readOnly || doc.location != null)
        : (doc.location != null);
    final showMoment = isDiary
        ? (!widget.readOnly || (doc.moment != null && doc.moment!.isNotEmpty))
        : (doc.moment != null && doc.moment!.isNotEmpty);
    final showMood = isDiary
        ? (!widget.readOnly || doc.mood != null)
        : (doc.mood != null);
    final showWeather = isDiary
        ? (!widget.readOnly || doc.weather != null)
        : (doc.weather != null);
    final showActivities = isDiary
        ? (!widget.readOnly || doc.activities.isNotEmpty)
        : (doc.activities.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with toggle
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'PROPERTIES',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (!_isExpanded)
                    Text(
                      _buildSummaryLabel(doc),
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          // Collapsible properties list
          if (_isExpanded) ...[
            Divider(height: 1, color: colors.divider.withValues(alpha: 0.4)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  // Author property
                  if (showAuthor)
                    _PropertyRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Author',
                      child: TextField(
                        controller: _authorController,
                        readOnly: widget.readOnly,
                        cursorColor: colors.accent,
                        style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, 'Add author...'),
                        onSubmitted: (val) => _onPropertySubmitted('author', val),
                      ),
                    ),

                  // Created property
                  if (doc.created != null || !widget.readOnly)
                    _PropertyRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created',
                      child: TextField(
                        controller: _createdController,
                        readOnly: widget.readOnly,
                        cursorColor: colors.accent,
                        style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, 'YYYY-MM-DD'),
                        onSubmitted: (val) => _onPropertySubmitted('created', val),
                      ),
                    ),

                  // Moment property
                  if (showMoment)
                    _PropertyRow(
                      icon: JournalMoment.fromKey(doc.moment)?.icon ?? Icons.auto_awesome_outlined,
                      label: 'Moment',
                      child: _buildMomentField(colors, doc.moment),
                    ),

                  // Mood property
                  if (showMood)
                    _PropertyRow(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      label: 'Mood',
                      child: _buildMoodField(colors, doc.mood),
                    ),

                  // Weather property
                  if (showWeather)
                    _PropertyRow(
                      icon: doc.weather?.icon ?? Icons.wb_sunny_outlined,
                      label: 'Weather',
                      child: _buildWeatherField(colors, doc.weather),
                    ),

                  // Location property
                  if (showLocation)
                    _PropertyRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      child: _buildLocationField(colors, doc.location),
                    ),

                  // Activities property
                  if (showActivities)
                    _PropertyRow(
                      icon: Icons.directions_run_rounded,
                      label: 'Activities',
                      child: _buildActivitiesField(colors, doc.activities),
                    ),

                  // Source property
                  if (showSource)
                    _PropertyRow(
                      icon: Icons.link_rounded,
                      label: 'Source',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sourceController,
                              readOnly: widget.readOnly,
                              cursorColor: colors.accent,
                              style: AppTypography.bodySmall.copyWith(
                                color: (doc.source?.startsWith('http://') == true ||
                                        doc.source?.startsWith('https://') == true)
                                    ? colors.accent
                                    : colors.textPrimary,
                              ),
                              decoration: _inputDecoration(colors, 'Add source URL or text...'),
                              onSubmitted: (val) => _onPropertySubmitted('source', val),
                            ),
                          ),
                          if (doc.source?.startsWith('http://') == true ||
                              doc.source?.startsWith('https://') == true)
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              color: colors.accent,
                              tooltip: 'Open link',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () {
                                LinkLauncherHelper.handleLinkTap(context, doc.source!);
                              },
                            ),
                        ],
                      ),
                    ),

                  // Description property
                  if (showDescription)
                    _PropertyRow(
                      icon: Icons.notes_rounded,
                      label: 'Description',
                      child: TextField(
                        controller: _descriptionController,
                        readOnly: widget.readOnly,
                        cursorColor: colors.accent,
                        maxLines: null,
                        style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                        decoration: _inputDecoration(colors, 'Add description...'),
                        onSubmitted: (val) => _onPropertySubmitted('description', val),
                      ),
                    ),

                  // Tags property
                  if (doc.tags.isNotEmpty || !widget.readOnly)
                    _PropertyRow(
                      icon: Icons.tag_rounded,
                      label: 'Tags',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TagEditorBar(
                          tags: doc.tags,
                          showAddButton: !widget.readOnly,
                          padding: EdgeInsets.zero,
                          onAddTag: _onAddTag,
                          onRemoveTag: _onRemoveTag,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationField(AppColors colors, JournalLocation? location) {
    if (_isFetchingLocation) {
      return Padding(
        padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Fetching current location...',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (location != null && location.isNotEmpty) {
      final hasAddress = location.address.trim().isNotEmpty;
      final hasCoords = location.coordinatesString.isNotEmpty;

      Widget actionButtons() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            color: colors.accent,
            tooltip: 'Open in Maps',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              LocationService().openInMaps(
                location.latitude,
                location.longitude,
                address: location.address,
              );
            },
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 4.0),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 14),
              color: colors.textSecondary,
              tooltip: 'Re-fetch location',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: _fetchLocation,
            ),
            const SizedBox(width: 4.0),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              color: colors.textTertiary,
              tooltip: 'Remove location',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: _removeLocation,
            ),
          ],
        ],
      );

      if (hasAddress) {
        return Padding(
          padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                location.displayString,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                  height: 1.35,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3.0),
                child: Row(
                  children: [
                    if (hasCoords)
                      Expanded(
                        child: Text(
                          location.coordinatesString,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    actionButtons(),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  location.displayString,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              actionButtons(),
            ],
          ),
        );
      }
    }

    if (!widget.readOnly) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: _fetchLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, size: 13, color: colors.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Fetch Location',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMomentField(AppColors colors, String? momentKey) {
    if (momentKey != null && momentKey.trim().isNotEmpty) {
      final moment = JournalMoment.fromKey(momentKey);
      final label = moment?.label ?? momentKey;
      final icon = moment?.icon ?? Icons.auto_awesome_outlined;

      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: widget.readOnly ? null : _showMomentPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: colors.accent),
                    const SizedBox(width: 6.0),
                    Text(
                      label,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: 6.0),
                      InkWell(
                        onTap: _removeMoment,
                        borderRadius: BorderRadius.circular(999),
                        child: Icon(Icons.close_rounded, size: 13, color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!widget.readOnly) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: _showMomentPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 13, color: colors.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Choose Moment',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMoodField(AppColors colors, int? moodLevel) {
    if (moodLevel != null) {
      final mood = JournalMood.fromLevel(moodLevel);

      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: widget.readOnly ? null : _showMoodPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood?.emoji ?? '😊',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      mood != null ? '${mood.label} (${mood.level}/10)' : '$moodLevel/10',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: 6.0),
                      InkWell(
                        onTap: _removeMood,
                        borderRadius: BorderRadius.circular(999),
                        child: Icon(Icons.close_rounded, size: 13, color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!widget.readOnly) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: _showMoodPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 13, color: colors.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Choose Mood',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildWeatherField(AppColors colors, JournalWeather? weather) {
    if (_isFetchingWeather) {
      return Padding(
        padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Fetching current weather...',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (weather != null && weather.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(weather.icon, size: 14, color: colors.accent),
                  const SizedBox(width: 6.0),
                  Text(
                    '${weather.temperatureString}, ${weather.condition}',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(width: 4.0),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                color: colors.textSecondary,
                tooltip: 'Refresh weather',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _fetchWeather,
              ),
              const SizedBox(width: 4.0),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 14),
                color: colors.textTertiary,
                tooltip: 'Remove weather',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _removeWeather,
              ),
            ],
          ],
        ),
      );
    }

    if (!widget.readOnly) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: _fetchWeather,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_outlined, size: 13, color: colors.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Fetch Weather',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActivitiesField(AppColors colors, List<String> activities) {
    if (activities.isEmpty && widget.readOnly) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Wrap(
        spacing: 6.0,
        runSpacing: 4.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...activities.map((actId) {
            final activity = ActivityStorageService.findActivitySync(actId);
            final label = activity?.label ??
                (actId.isNotEmpty
                    ? actId[0].toUpperCase() + actId.substring(1)
                    : actId);
            final icon = activity?.icon ?? Icons.label_outline_rounded;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12.0, color: colors.textSecondary),
                  const SizedBox(width: 4.0),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(width: 4.0),
                    InkWell(
                      onTap: () => _removeActivity(actId),
                      borderRadius: BorderRadius.circular(999),
                      child: Icon(Icons.close_rounded, size: 12, color: colors.textTertiary),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (!widget.readOnly)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: _showActivityPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 12.0, color: colors.accent),
                      const SizedBox(width: 3.0),
                      Text(
                        activities.isEmpty ? 'Add Activities' : 'Add',
                        style: AppTypography.caption.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildSummaryLabel(FrontmatterDocument doc) {
    final parts = <String>[];
    if (doc.author != null && doc.author!.isNotEmpty) parts.add(doc.author!);
    if (doc.created != null && doc.created!.isNotEmpty) parts.add(doc.created!);
    if (doc.moment != null && doc.moment!.isNotEmpty) {
      final moment = JournalMoment.fromKey(doc.moment);
      parts.add(moment?.label ?? doc.moment!);
    }
    if (doc.mood != null) {
      final mood = JournalMood.fromLevel(doc.mood);
      parts.add(mood != null ? '${mood.emoji} ${mood.level}/10' : 'Mood ${doc.mood}/10');
    }
    if (doc.weather != null && doc.weather!.isNotEmpty) {
      parts.add('${doc.weather!.temperatureString} ${doc.weather!.condition}');
    }
    if (doc.location != null && doc.location!.isNotEmpty) parts.add(doc.location!.displayString);
    if (doc.activities.isNotEmpty) parts.add('${doc.activities.length} activities');
    if (doc.tags.isNotEmpty) parts.add('${doc.tags.length} tags');
    return parts.join(' · ');
  }

  InputDecoration _inputDecoration(AppColors colors, String hint) {
    return InputDecoration(
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
      hintText: hint,
      hintStyle: AppTypography.bodySmall.copyWith(
        color: colors.textTertiary.withValues(alpha: 0.5),
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: colors.textTertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
