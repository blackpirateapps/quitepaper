import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/note_links/note_link_search_service.dart';
import '../../../../core/utils/date_formatter.dart';

/// Result returned from the note link picker.
sealed class NoteLinkPickerResult {
  const NoteLinkPickerResult();
}

/// User selected an existing note to link.
class NoteLinkPickerSelectResult extends NoteLinkPickerResult {
  const NoteLinkPickerSelectResult({
    required this.noteId,
    required this.title,
  });

  final String noteId;
  final String title;
}

/// User chose to explicitly create a new note with [newTitle] and link to it.
class NoteLinkPickerCreateResult extends NoteLinkPickerResult {
  const NoteLinkPickerCreateResult({
    required this.newTitle,
  });

  final String newTitle;
}

/// A warm, editorial note picker modal/sheet for discovering and linking notes.
class NoteLinkPickerSheet extends StatefulWidget {
  const NoteLinkPickerSheet({
    super.key,
    required this.searchService,
    this.initialQuery = '',
    this.currentNoteId,
    this.onSelect,
    this.onCreate,
  });

  final NoteLinkSearchService searchService;
  final String initialQuery;
  final String? currentNoteId;
  final ValueChanged<NoteLinkPickerSelectResult>? onSelect;
  final ValueChanged<NoteLinkPickerCreateResult>? onCreate;

  /// Shows the note picker as an editorial modal bottom sheet.
  static Future<NoteLinkPickerResult?> show(
    BuildContext context, {
    required NoteLinkSearchService searchService,
    String initialQuery = '',
    String? currentNoteId,
  }) {
    return showModalBottomSheet<NoteLinkPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteLinkPickerSheet(
        searchService: searchService,
        initialQuery: initialQuery,
        currentNoteId: currentNoteId,
        onSelect: (res) => Navigator.of(ctx).pop(res),
        onCreate: (res) => Navigator.of(ctx).pop(res),
      ),
    );
  }

  @override
  State<NoteLinkPickerSheet> createState() => _NoteLinkPickerSheetState();
}

class _NoteLinkPickerSheetState extends State<NoteLinkPickerSheet> {
  late final TextEditingController _queryController;
  late final FocusNode _searchFocusNode;
  Timer? _debounceTimer;

  List<NoteLinkSearchResultItem> _results = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _searchFocusNode = FocusNode();
    _performSearch(widget.initialQuery);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        _performSearch(val);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.searchService.searchNotes(
        query: query,
        currentNoteId: widget.currentNoteId,
      );
      if (mounted) {
        setState(() {
          _results = items;
          _isLoading = false;
          _selectedIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectItem(NoteLinkSearchResultItem item) {
    final result = NoteLinkPickerSelectResult(
      noteId: item.id,
      title: item.displayTitle,
    );
    if (widget.onSelect != null) {
      widget.onSelect!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _createNote(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;

    final result = NoteLinkPickerCreateResult(newTitle: clean);
    if (widget.onCreate != null) {
      widget.onCreate!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _handleKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final totalItems = _results.length + (_canCreate ? 1 : 0);
    if (totalItems == 0) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % totalItems;
      });
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + totalItems) % totalItems;
      });
    } else if (key == LogicalKeyboardKey.enter) {
      if (_selectedIndex < _results.length) {
        _selectItem(_results[_selectedIndex]);
      } else if (_canCreate) {
        _createNote(_queryController.text);
      }
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  bool get _canCreate {
    final query = _queryController.text.trim();
    if (query.isEmpty) return false;
    final clean = query.toLowerCase();
    // Do not show create if an exact title match already exists
    return !_results.any((r) => r.title.trim().toLowerCase() == clean);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyDown,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: isKeyboardVisible ? mediaQuery.viewInsets.bottom + 12 : AppSpacing.xl,
              top: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.borderLg,
              border: Border.all(color: colors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Search Input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 20,
                          color: colors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Link to a note',
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: colors.textTertiary),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: colors.divider),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: colors.textTertiary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              focusNode: _searchFocusNode,
                              onChanged: _onQueryChanged,
                              cursorColor: colors.accent,
                              style: AppTypography.bodySmallMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search or type note title...',
                                hintStyle: AppTypography.bodySmall.copyWith(
                                  color: colors.textTertiary.withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_queryController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _queryController.clear();
                                _onQueryChanged('');
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 16,
                                color: colors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Divider(height: 1, color: colors.divider),

                  // Results list
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: _buildListContent(colors),
                    ),
                  ),

                  // Create action button (at bottom)
                  if (_canCreate) ...[
                    Divider(height: 1, color: colors.divider),
                    _buildCreateTile(colors, _results.length == _selectedIndex),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(AppColors colors) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 32,
                color: colors.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No matching notes',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      itemBuilder: (ctx, idx) {
        final item = _results[idx];
        final isSelected = idx == _selectedIndex;

        return _NoteResultTile(
          item: item,
          isSelected: isSelected,
          onTap: () => _selectItem(item),
        );
      },
    );
  }

  Widget _buildCreateTile(AppColors colors, bool isSelected) {
    final query = _queryController.text.trim();

    return InkWell(
      onTap: () => _createNote(query),
      child: Container(
        color: isSelected ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: AppRadii.borderSm,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Create ',
                  style: AppTypography.bodySmallMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: '“$query”',
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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

class _NoteResultTile extends StatelessWidget {
  const _NoteResultTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NoteLinkSearchResultItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final dateStr = DateFormatter.formatNoteTileTime(item.updatedAt);

    return InkWell(

      onTap: onTap,
      child: Container(
        color: isSelected ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title and lock badge
            Row(
              children: [
                if (item.isPasswordProtected) ...[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Metadata: Tags · Date
            const SizedBox(height: 2),
            Row(
              children: [
                if (item.tags.isNotEmpty) ...[
                  Text(
                    item.tags.map((t) => '#$t').join(' '),
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ' · ',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
                Text(
                  'Edited $dateStr',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            // Body preview snippet (if not empty)
            if (item.snippet.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.snippet,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
