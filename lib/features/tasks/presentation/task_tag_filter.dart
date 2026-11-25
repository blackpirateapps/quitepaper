import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/search/search_tokenizer.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../tags/domain/phosphor_icons.dart';
import 'task_modal.dart';

Future<Set<String>?> showTaskTagFilter(
  BuildContext context, {
  required List<String> available,
  required Set<String> selected,
}) => showTaskModal<Set<String>>(
  context,
  (_) => _TagFilter(available: available, selected: selected),
);

class _TagFilter extends StatefulWidget {
  const _TagFilter({required this.available, required this.selected});
  final List<String> available;
  final Set<String> selected;
  @override
  State<_TagFilter> createState() => _TagFilterState();
}

class _TagFilterState extends State<_TagFilter> {
  late final selected = {...widget.selected};
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = SearchTokenizer.tokenize(
      search.text.replaceFirst(RegExp(r'^\s*#'), ''),
    );
    final tags = {...widget.available, ...selected}.toList()..sort();
    final matches = tags.where((name) {
      final normalized = SearchTokenizer.tokenize(name).join(' ');
      return tokens.every(normalized.contains);
    }).toList();
    void toggle(String name) => setState(() {
      if (!selected.remove(name)) selected.add(name);
    });
    return TaskModal(
      title: 'Filter tags',
      subtitle: 'Show tasks with any selected tag.',
      actions: Row(
        children: [
          Expanded(
            child: QuietButton(
              label: 'Clear filters',
              variant: QuietButtonVariant.ghost,
              onPressed: selected.isEmpty
                  ? null
                  : () => setState(selected.clear),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: QuietButton(
              label: 'Apply',
              variant: QuietButtonVariant.primary,
              onPressed: () =>
                  Navigator.pop(context, Set<String>.unmodifiable(selected)),
            ),
          ),
        ],
      ),
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search tags',
                  prefixIcon: const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 20,
                  ),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear tag search',
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () => setState(search.clear),
                        ),
                  filled: true,
                  fillColor: colors.surfaceSecondary,
                  isDense: true,
                ),
              ),
            ),
            if (selected.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    for (final name in selected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: InputChip(
                          label: Text('#$name'),
                          backgroundColor: colors.accentSoft,
                          deleteIcon: const Icon(
                            PhosphorIconsRegular.x,
                            size: 14,
                          ),
                          onDeleted: () => toggle(name),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tags.isEmpty
                              ? 'Add tags to your task notes to filter them here.'
                              : 'No tags match your search.',
                          textAlign: TextAlign.center,
                          style: context.appTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final name = matches[index];
                        return CheckboxListTile(
                          key: ValueKey('task-filter-tag-$name'),
                          value: selected.contains(name),
                          onChanged: (_) => toggle(name),
                          activeColor: colors.accent,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          title: Text(
                            '#$name',
                            style: context.appTypography.body.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          secondary: Icon(
                            PhosphorIconsRegular.hash,
                            size: 18,
                            color: colors.iconSecondary,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
