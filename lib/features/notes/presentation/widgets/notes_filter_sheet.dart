import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../application/notes_provider.dart';
import '../../application/notes_query_provider.dart';
import '../../application/saved_filters_provider.dart';
import '../../domain/notes_filter.dart';

/// Modal bottom sheet for configuring advanced note query filters
class NotesFilterSheet extends ConsumerStatefulWidget {
  const NotesFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotesFilterSheet(),
    );
  }

  @override
  ConsumerState<NotesFilterSheet> createState() => _NotesFilterSheetState();
}

class _NotesFilterSheetState extends ConsumerState<NotesFilterSheet> {
  late NotesFilter _draftFilter;
  String _tagSearchQuery = '';
  final TextEditingController _tagSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final query = ref.read(notesQueryProvider);
    _draftFilter = query.filter;
  }

  @override
  void dispose() {
    _tagSearchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    ref.read(notesQueryProvider.notifier).setFilters(_draftFilter);
    Navigator.of(context).pop();
  }

  void _clearAll() {
    setState(() {
      _draftFilter = NotesFilter.empty;
    });
  }

  Future<void> _saveAsSmartView() async {
    final nameController = TextEditingController(text: 'My Smart View');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLg,
            side: BorderSide(color: colors.divider, width: 0.8),
          ),
          title: Text(
            'Save as Smart View',
            style: AppTypography.headline.copyWith(color: colors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a name for this saved query:',
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'View Name',
                  hintStyle: AppTypography.body.copyWith(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider, width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ),
            QuietButton(
              label: 'Save',
              variant: QuietButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final name = nameController.text.trim();
      final currentQuery = ref.read(notesQueryProvider);
      final queryToSave = currentQuery.copyWith(filter: _draftFilter);
      await ref.read(savedFiltersProvider.notifier).create(
            name: name.isNotEmpty ? name : 'Smart View',
            query: queryToSave,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Smart view "$name" saved'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectCustomDateRange(bool isCreated) async {
    final currentRange = isCreated ? _draftFilter.createdRange : _draftFilter.modifiedRange;
    final initialDateRange = DateTimeRange(
      start: currentRange?.customFrom ?? DateTime.now().subtract(const Duration(days: 7)),
      end: currentRange?.customTo ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
    );

    if (picked != null) {
      setState(() {
        final newRange = DateFilterRange(
          type: DateFilterType.custom,
          customFrom: picked.start,
          customTo: picked.end,
        );
        if (isCreated) {
          _draftFilter = _draftFilter.copyWith(createdRange: newRange);
        } else {
          _draftFilter = _draftFilter.copyWith(modifiedRange: newRange);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final allTagsAsync = ref.watch(allTagsStreamProvider);
    final query = ref.watch(notesQueryProvider);
    final activeCount = _draftFilter.activeFilterCount;
    final isTrash = query.context == NotesContext.trash;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
            border: Border.all(color: colors.divider, width: 0.8),
          ),
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sheet Header
                  Row(
                    children: [
                      Text(
                        'FILTERS',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      if (activeCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$activeCount active',
                            style: AppTypography.caption.copyWith(
                              color: colors.accentDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (activeCount > 0)
                        TextButton(
                          onPressed: _clearAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            'Clear all',
                            style: AppTypography.caption.copyWith(
                              color: colors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      QuietIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close filter menu',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 1. TAGS SECTION
                  _buildSectionHeader(colors, 'TAGS'),
                  _FilterContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Untagged option
                        _FilterToggleRow(
                          title: 'Untagged Notes',
                          subtitle: 'Notes with no tags attached',
                          value: _draftFilter.untaggedOnly,
                          onChanged: (val) {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(
                                untaggedOnly: val,
                                tags: val ? const {} : _draftFilter.tags,
                              );
                            });
                          },
                        ),
                        if (!_draftFilter.untaggedOnly) ...[
                          Divider(color: colors.divider, height: 1, indent: 16),
                          // Tag Search & Chips
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Match Mode Toggle (All vs Any)
                                if (_draftFilter.tags.length > 1) ...[
                                  Row(
                                    children: [
                                      Text(
                                        'Match Mode:',
                                        style: AppTypography.caption.copyWith(
                                          color: colors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      _TonalPill(
                                        label: 'All (AND)',
                                        isSelected: _draftFilter.tagMatchMode == TagMatchMode.all,
                                        onTap: () {
                                          setState(() {
                                            _draftFilter = _draftFilter.copyWith(
                                              tagMatchMode: TagMatchMode.all,
                                            );
                                          });
                                        },
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      _TonalPill(
                                        label: 'Any (OR)',
                                        isSelected: _draftFilter.tagMatchMode == TagMatchMode.any,
                                        onTap: () {
                                          setState(() {
                                            _draftFilter = _draftFilter.copyWith(
                                              tagMatchMode: TagMatchMode.any,
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],

                                // Tag Search Field
                                TextField(
                                  controller: _tagSearchController,
                                  onChanged: (val) {
                                    setState(() {
                                      _tagSearchQuery = val.trim().toLowerCase();
                                    });
                                  },
                                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'Search tags...',
                                    hintStyle: AppTypography.caption.copyWith(color: colors.textTertiary),
                                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: colors.textTertiary),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    isDense: true,
                                    filled: true,
                                    fillColor: colors.surface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadii.borderSm,
                                      borderSide: BorderSide(color: colors.divider, width: 0.8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: AppRadii.borderSm,
                                      borderSide: BorderSide(color: colors.divider, width: 0.8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: AppRadii.borderSm,
                                      borderSide: BorderSide(color: colors.accent, width: 1.2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Tag Chips List
                                allTagsAsync.when(
                                  data: (tags) {
                                    final filtered = tags.where((t) {
                                      if (_tagSearchQuery.isEmpty) return true;
                                      return t.tag.name.toLowerCase().contains(_tagSearchQuery);
                                    }).toList();

                                    if (filtered.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                        child: Text(
                                          'No tags found',
                                          style: AppTypography.caption.copyWith(color: colors.textTertiary),
                                        ),
                                      );
                                    }

                                    return Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children: filtered.map((tagWithCount) {
                                        final tagName = tagWithCount.tag.name;
                                        final isSelected = _draftFilter.tags.contains(tagName);

                                        return _TagSelectionChip(
                                          label: '#$tagName',
                                          count: tagWithCount.noteCount,
                                          isSelected: isSelected,
                                          onTap: () {
                                            setState(() {
                                              final newTags = Set<String>.of(_draftFilter.tags);
                                              if (isSelected) {
                                                newTags.remove(tagName);
                                              } else {
                                                newTags.add(tagName);
                                              }
                                              _draftFilter = _draftFilter.copyWith(tags: newTags);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. STATE (PINNED) SECTION
                  if (!isTrash && query.context == NotesContext.active) ...[
                    _buildSectionHeader(colors, 'STATE'),
                    _FilterContainer(
                      child: _FilterToggleRow(
                        title: 'Pinned Only',
                        subtitle: 'Show only pinned notes',
                        value: _draftFilter.pinnedOnly,
                        onChanged: (val) {
                          setState(() {
                            _draftFilter = _draftFilter.copyWith(pinnedOnly: val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 3. DATE FILTERS SECTION
                  _buildSectionHeader(colors, 'DATE FILTERS'),
                  _FilterContainer(
                    child: Column(
                      children: [
                        // Modified Date Row
                        _DateFilterMenuRow(
                          title: 'Date Modified',
                          selectedRange: _draftFilter.modifiedRange,
                          onSelected: (type) {
                            if (type == DateFilterType.custom) {
                              _selectCustomDateRange(false);
                            } else {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  modifiedRange: DateFilterRange(type: type),
                                );
                              });
                            }
                          },
                          onCleared: () {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(clearModifiedRange: true);
                            });
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        // Created Date Row
                        _DateFilterMenuRow(
                          title: 'Date Created',
                          selectedRange: _draftFilter.createdRange,
                          onSelected: (type) {
                            if (type == DateFilterType.custom) {
                              _selectCustomDateRange(true);
                            } else {
                              setState(() {
                                _draftFilter = _draftFilter.copyWith(
                                  createdRange: DateFilterRange(type: type),
                                );
                              });
                            }
                          },
                          onCleared: () {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(clearCreatedRange: true);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. CONTENT FILTERS SECTION
                  _buildSectionHeader(colors, 'CONTENT'),
                  _FilterContainer(
                    child: Column(
                      children: [
                        _ContentToggleRow(
                          title: 'Has Code',
                          icon: Icons.code_rounded,
                          value: _draftFilter.contentFilters.contains(ContentFilter.hasCode),
                          onChanged: (val) => _toggleContentFilter(ContentFilter.hasCode, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Checklists',
                          icon: Icons.checklist_rounded,
                          value: _draftFilter.contentFilters.contains(ContentFilter.hasChecklist),
                          onChanged: (val) => _toggleContentFilter(ContentFilter.hasChecklist, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Incomplete Tasks',
                          icon: Icons.check_box_outline_blank_rounded,
                          value: _draftFilter.contentFilters.contains(ContentFilter.hasIncompleteTasks),
                          onChanged: (val) => _toggleContentFilter(ContentFilter.hasIncompleteTasks, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Completed Tasks',
                          icon: Icons.check_box_rounded,
                          value: _draftFilter.contentFilters.contains(ContentFilter.hasCompletedTasks),
                          onChanged: (val) => _toggleContentFilter(ContentFilter.hasCompletedTasks, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Links',
                          icon: Icons.link_rounded,
                          value: _draftFilter.contentFilters.contains(ContentFilter.hasLinks),
                          onChanged: (val) => _toggleContentFilter(ContentFilter.hasLinks, val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. ATTACHMENTS SECTION
                  _buildSectionHeader(colors, 'ATTACHMENTS & MEDIA'),
                  _FilterContainer(
                    child: Column(
                      children: [
                        _ContentToggleRow(
                          title: 'Has Attachments',
                          icon: Icons.attach_file_rounded,
                          value: _draftFilter.attachmentFilters.contains(AttachmentFilter.hasAttachments),
                          onChanged: (val) => _toggleAttachmentFilter(AttachmentFilter.hasAttachments, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Images',
                          icon: Icons.image_outlined,
                          value: _draftFilter.attachmentFilters.contains(AttachmentFilter.hasImages),
                          onChanged: (val) => _toggleAttachmentFilter(AttachmentFilter.hasImages, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has Documents (PDF)',
                          icon: Icons.picture_as_pdf_outlined,
                          value: _draftFilter.attachmentFilters.contains(AttachmentFilter.hasDocuments),
                          onChanged: (val) => _toggleAttachmentFilter(AttachmentFilter.hasDocuments, val),
                        ),
                        Divider(color: colors.divider, height: 1, indent: 48),
                        _ContentToggleRow(
                          title: 'Has OCR Text Available',
                          icon: Icons.document_scanner_outlined,
                          value: _draftFilter.attachmentFilters.contains(AttachmentFilter.hasOcr),
                          onChanged: (val) => _toggleAttachmentFilter(AttachmentFilter.hasOcr, val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. SECURITY SECTION
                  _buildSectionHeader(colors, 'SECURITY'),
                  _FilterContainer(
                    child: Column(
                      children: [
                        _SecurityRadioRow(
                          title: 'All Notes',
                          isSelected: _draftFilter.securityFilter == SecurityFilter.all,
                          onTap: () {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(securityFilter: SecurityFilter.all);
                            });
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        _SecurityRadioRow(
                          title: 'Password Protected Only',
                          isSelected: _draftFilter.securityFilter == SecurityFilter.protectedOnly,
                          onTap: () {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(securityFilter: SecurityFilter.protectedOnly);
                            });
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        _SecurityRadioRow(
                          title: 'Unprotected Only',
                          isSelected: _draftFilter.securityFilter == SecurityFilter.unprotectedOnly,
                          onTap: () {
                            setState(() {
                              _draftFilter = _draftFilter.copyWith(securityFilter: SecurityFilter.unprotectedOnly);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // BOTTOM ACTIONS
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                        label: const Text('Save as view'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _saveAsSmartView,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QuietButton(
                            label: 'Cancel',
                            variant: QuietButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          QuietButton(
                            label: 'Apply Filters',
                            variant: QuietButtonVariant.primary,
                            onPressed: _applyFilter,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleContentFilter(ContentFilter filter, bool active) {
    setState(() {
      final newSet = Set<ContentFilter>.of(_draftFilter.contentFilters);
      if (active) {
        newSet.add(filter);
      } else {
        newSet.remove(filter);
      }
      _draftFilter = _draftFilter.copyWith(contentFilters: newSet);
    });
  }

  void _toggleAttachmentFilter(AttachmentFilter filter, bool active) {
    setState(() {
      final newSet = Set<AttachmentFilter>.of(_draftFilter.attachmentFilters);
      if (active) {
        newSet.add(filter);
      } else {
        newSet.remove(filter);
      }
      _draftFilter = _draftFilter.copyWith(attachmentFilters: newSet);
    });
  }

  Widget _buildSectionHeader(AppColors colors, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 2),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _FilterContainer extends StatelessWidget {
  const _FilterContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FilterToggleRow extends StatelessWidget {
  const _FilterToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: colors.accent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentToggleRow extends StatelessWidget {
  const _ContentToggleRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: value ? colors.accent : colors.textTertiary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: value ? colors.textPrimary : colors.textSecondary,
                    fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: colors.accent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityRadioRow extends StatelessWidget {
  const _SecurityRadioRow({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: isSelected ? colors.accentDark : colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateFilterMenuRow extends StatelessWidget {
  const _DateFilterMenuRow({
    required this.title,
    required this.selectedRange,
    required this.onSelected,
    required this.onCleared,
  });

  final String title;
  final DateFilterRange? selectedRange;
  final ValueChanged<DateFilterType> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSet = selectedRange != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isSet ? selectedRange!.displayName : 'Any time',
                  style: AppTypography.caption.copyWith(
                    color: isSet ? colors.accent : colors.textTertiary,
                    fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (isSet)
            GestureDetector(
              onTap: onCleared,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.close_rounded, size: 18, color: colors.textTertiary),
              ),
            ),
          PopupMenuButton<DateFilterType>(
            tooltip: 'Select date range',
            icon: Icon(Icons.calendar_today_rounded, size: 18, color: colors.textSecondary),
            onSelected: onSelected,
            itemBuilder: (ctx) => [
              for (final type in DateFilterType.values)
                PopupMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagSelectionChip extends StatelessWidget {
  const _TagSelectionChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = isSelected ? colors.accentSoft : colors.surface;
    final fg = isSelected ? colors.accentDark : colors.textSecondary;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderSm,
        side: BorderSide(
          color: isSelected ? colors.accent.withValues(alpha: 0.5) : colors.divider,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.tag.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TonalPill extends StatelessWidget {
  const _TonalPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: isSelected ? colors.accent : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? colors.accent : colors.divider,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
