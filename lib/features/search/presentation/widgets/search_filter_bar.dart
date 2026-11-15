import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/search_provider.dart';

/// Content-width category tabs shared by phone, tablet, and desktop search.
class SearchFilterBar extends ConsumerStatefulWidget {
  const SearchFilterBar({super.key, required this.results});

  final GlobalSearchResults results;

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar>
    with SingleTickerProviderStateMixin {
  static const _order = [
    SearchFilter.all,
    SearchFilter.notes,
    SearchFilter.documents,
    SearchFilter.tags,
  ];

  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _order.length,
      initialIndex: _order.indexOf(ref.read(searchFilterProvider)),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    ref.listen(searchFilterProvider, (_, filter) {
      final index = _order.indexOf(filter);
      if (_controller.index != index) _controller.animateTo(index);
    });
    final results = widget.results;
    final tabs = [
      ('All', results.totalCount, 'search_filter_all'),
      ('Notes', results.notesCount, 'search_filter_notes'),
      ('Docs', results.documentsCount, 'search_filter_documents'),
      ('Tags', results.tagsCount, 'search_filter_tags'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: colors.accent,
        indicatorWeight: 2,
        dividerColor: colors.divider,
        dividerHeight: 1,
        labelColor: colors.textPrimary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: AppTypography.caption.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.caption.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
        onTap: (index) =>
            ref.read(searchFilterProvider.notifier).state = _order[index],
        tabs: [
          for (final (label, count, keyId) in tabs)
            Tab(
              key: ValueKey(keyId),
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(label),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
