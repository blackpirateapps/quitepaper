import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/search_provider.dart';
import 'search_filter_bar.dart';
import 'search_result_preview.dart';
import 'search_result_row.dart';

/// Shared split workspace for desktop and tablets, including portrait tablets.
class SearchWorkspace extends StatefulWidget {
  const SearchWorkspace({
    super.key,
    required this.header,
    required this.initialState,
    required this.query,
    required this.results,
    required this.filter,
    required this.onOpen,
    required this.onEdit,
  });

  final Widget header;
  final Widget initialState;
  final String query;
  final AsyncValue<GlobalSearchResults> results;
  final SearchFilter filter;
  final ValueChanged<SearchResultItem> onOpen;
  final ValueChanged<NoteSearchMatch> onEdit;

  @override
  State<SearchWorkspace> createState() => _SearchWorkspaceState();
}

class _SearchWorkspaceState extends State<SearchWorkspace> {
  double _resultsFraction = 0.4;
  String? _selectedId;

  static String _id(SearchResultItem item) => switch (item) {
    NoteSearchMatch() => 'note:${item.note.id}',
    DocumentSearchMatch() => 'document:${item.id}:${item.matchedPageNumber}',
  };

  @override
  void didUpdateWidget(SearchWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.filter != widget.filter) {
      _selectedId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasQuery = widget.query.trim().isNotEmpty;
    // StreamProvider can retain the previous query's value during a refresh.
    final current = widget.results.valueOrNull;
    final results = current?.query == widget.query.trim() ? current : null;
    final items = !hasQuery || results == null
        ? <SearchResultItem>[]
        : switch (widget.filter) {
            SearchFilter.all => <SearchResultItem>[
              ...results.noteMatches,
              ...results.documentMatches,
            ],
            _ => <SearchResultItem>[
              ...results.filteredResultsForFilter(widget.filter),
            ],
          };
    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (item) => _id(item) == _selectedId,
            orElse: () => items.first,
          );
    final isSearching =
        widget.results.isLoading ||
        (results != null && results.searchPhase != SearchPhase.complete);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 12;
        // Both panes remain usable at the smallest supported tablet width.
        final minResults = available < 700 ? 280.0 : 320.0;
        final minPreview = available < 700 ? 280.0 : 340.0;
        final width = (available * _resultsFraction).clamp(
          minResults,
          available - minPreview,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('search_results_pane'),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.header,
                  if (hasQuery) ...[
                    SizedBox(
                      height: 2,
                      child: isSearching
                          ? LinearProgressIndicator(
                              color: colors.accent,
                              backgroundColor: Colors.transparent,
                            )
                          : null,
                    ),
                    if (results != null) SearchFilterBar(results: results),
                  ],
                  Expanded(
                    child: !hasQuery
                        ? widget.initialState
                        : items.isNotEmpty
                        ? ListView.builder(
                            key: ValueKey(
                              'search-results-${widget.query}-${widget.filter.name}',
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return SearchResultRow(
                                key: ValueKey(_id(item)),
                                result: item,
                                query: widget.query,
                                selected: _id(item) == _id(selected!),
                                onTap: () =>
                                    setState(() => _selectedId = _id(item)),
                              );
                            },
                          )
                        : _message(
                            widget.results.hasError
                                ? 'Search could not be completed. Try again.'
                                : isSearching
                                ? 'Searching…'
                                : 'No results found',
                          ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Resize search results and preview',
              onIncrease: () => setState(
                () => _resultsFraction = ((width + 32) / available).clamp(0, 1),
              ),
              onDecrease: () => setState(
                () => _resultsFraction = ((width - 32) / available).clamp(0, 1),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  key: const ValueKey('search_pane_divider'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(() {
                    _resultsFraction =
                        ((width + details.delta.dx).clamp(
                          minResults,
                          available - minPreview,
                        )) /
                        available;
                  }),
                  child: SizedBox(
                    width: 12,
                    child: Center(
                      child: Container(width: 1, color: colors.divider),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              key: const ValueKey('search_preview_pane'),
              child: selected == null
                  ? _message(
                      hasQuery
                          ? 'No result to preview'
                          : 'Search to preview a result',
                    )
                  : SearchResultPreview(
                      key: ValueKey(_id(selected)),
                      result: selected,
                      query: widget.query,
                      onOpen: () => widget.onOpen(selected),
                      onEdit: selected is NoteSearchMatch
                          ? () => widget.onEdit(selected)
                          : null,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _message(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appColors.textTertiary),
      ),
    ),
  );
}
