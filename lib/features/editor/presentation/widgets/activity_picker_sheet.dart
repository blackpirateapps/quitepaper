import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/application/activity_storage_service.dart';
import '../../../../core/journal/domain/journal_activity.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';

/// Modal bottom sheet allowing users to multi-select activities and add custom activities with icons.
class ActivityPickerSheet extends StatefulWidget {
  const ActivityPickerSheet({
    super.key,
    required this.selectedIds,
    required this.onActivitiesChanged,
    this.storageService,
  });

  final List<String> selectedIds;
  final ValueChanged<List<String>> onActivitiesChanged;
  final ActivityStorageService? storageService;

  static Future<void> show({
    required BuildContext context,
    required List<String> selectedIds,
    required ValueChanged<List<String>> onActivitiesChanged,
    ActivityStorageService? storageService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ActivityPickerSheet(
        selectedIds: selectedIds,
        onActivitiesChanged: onActivitiesChanged,
        storageService: storageService,
      ),
    );
  }

  @override
  State<ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends State<ActivityPickerSheet> {
  late final ActivityStorageService _storageService;
  late final Set<String> _currentSelected;
  List<JournalActivity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? ActivityStorageService();
    _currentSelected = Set<String>.from(
      widget.selectedIds.map((s) => s.trim().toLowerCase()),
    );
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final list = await _storageService.getAllActivities();
    if (mounted) {
      setState(() {
        _activities = list;
        _isLoading = false;
      });
    }
  }

  void _toggleActivity(String id) {
    final normalized = id.trim().toLowerCase();
    setState(() {
      if (_currentSelected.contains(normalized)) {
        _currentSelected.remove(normalized);
      } else {
        _currentSelected.add(normalized);
      }
    });
    widget.onActivitiesChanged(_currentSelected.toList());
  }

  Future<void> _showAddCustomActivityDialog() async {
    final colors = context.appColors;
    final nameController = TextEditingController();

    const availableIcons = <({String id, IconData icon})>[
      (id: 'star', icon: PhosphorIconsRegular.star),
      (id: 'barbell', icon: PhosphorIconsRegular.barbell),
      (id: 'bicycle', icon: PhosphorIconsRegular.bicycle),
      (id: 'swimming-pool', icon: PhosphorIconsRegular.swimmingPool),
      (id: 'mountains', icon: PhosphorIconsRegular.mountains),
      (id: 'sparkle', icon: PhosphorIconsRegular.sparkle),
      (id: 'plant', icon: PhosphorIconsRegular.plant),
      (id: 'paw-print', icon: PhosphorIconsRegular.pawPrint),
      (id: 'paint-brush', icon: PhosphorIconsRegular.paintBrush),
      (id: 'wrench', icon: PhosphorIconsRegular.wrench),
      (id: 'book-bookmark', icon: PhosphorIconsRegular.bookBookmark),
      (id: 'headphones', icon: PhosphorIconsRegular.headphones),
      (id: 'camera', icon: PhosphorIconsRegular.camera),
      (id: 'game-controller', icon: PhosphorIconsRegular.gameController),
      (id: 'cake', icon: PhosphorIconsRegular.cake),
      (id: 'heart', icon: PhosphorIconsRegular.heart),
      (id: 'sun', icon: PhosphorIconsRegular.sun),
      (id: 'moon', icon: PhosphorIconsRegular.moon),
    ];

    var selectedIcon = availableIcons.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              title: Text(
                'New Activity',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Activity Name',
                        hintText: 'e.g. Gardening, Swimming',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          borderSide: BorderSide(color: colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          borderSide: BorderSide(color: colors.accent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Choose Icon',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: availableIcons.map((item) {
                        final isPicked = selectedIcon.id == item.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = item;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isPicked
                                  ? colors.accent.withValues(alpha: 0.2)
                                  : colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              border: Border.all(
                                color: isPicked ? colors.accent : colors.divider,
                                width: isPicked ? 1.5 : 0.8,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: isPicked ? colors.accent : colors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colors.accent),
                  onPressed: () async {
                    final rawName = nameController.text.trim();
                    if (rawName.isEmpty) return;

                    final cleanId = rawName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
                    final newActivity = JournalActivity(
                      id: cleanId,
                      label: rawName,
                      icon: selectedIcon.icon,
                      iconKey: selectedIcon.id,
                      isCustom: true,
                    );

                    await _storageService.saveCustomActivity(newActivity);
                    if (!dialogCtx.mounted) return;
                    Navigator.of(dialogCtx).pop();

                    await _loadActivities();
                    _toggleActivity(newActivity.id);
                  },
                  child: const Text('Add Activity'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        border: Border(
          top: BorderSide(color: colors.divider.withValues(alpha: 0.7), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                Icon(Icons.directions_run_rounded, size: 18, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Record Activities',
                  style: AppTypography.headline.copyWith(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddCustomActivityDialog,
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Custom'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _activities.map((act) {
                      final isSelected = _currentSelected.contains(act.id.toLowerCase());
                      return InkWell(
                        borderRadius: AppRadii.borderMd,
                        onTap: () => _toggleActivity(act.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.accent.withValues(alpha: 0.15)
                                : colors.surfaceSubtle.withValues(alpha: 0.5),
                            borderRadius: AppRadii.borderMd,
                            border: Border.all(
                              color: isSelected
                                  ? colors.accent
                                  : colors.divider.withValues(alpha: 0.5),
                              width: isSelected ? 1.3 : 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                act.icon,
                                size: 15,
                                color: isSelected ? colors.accent : colors.textSecondary,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                act.label,
                                style: AppTypography.caption.copyWith(
                                  color: isSelected ? colors.accent : colors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 4.0),
                                Icon(Icons.check_rounded, size: 13, color: colors.accent),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
