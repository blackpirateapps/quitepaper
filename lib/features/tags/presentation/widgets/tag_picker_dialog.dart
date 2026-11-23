import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../application/tag_providers.dart';
import '../../application/tag_suggestions.dart';

/// Stages additions until Apply; dismissing the dialog never mutates a note.
class TagPickerDialog extends ConsumerStatefulWidget {
  const TagPickerDialog({
    super.key,
    this.existingTags = const [],
    this.title = 'Add tags',
  });

  final List<String> existingTags;
  final String title;

  static Future<List<String>?> show(
    BuildContext context, {
    List<String> existingTags = const [],
    String title = 'Add tags',
  }) => showDialog<List<String>>(
    context: context,
    builder: (_) => TagPickerDialog(existingTags: existingTags, title: title),
  );

  @override
  ConsumerState<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends ConsumerState<TagPickerDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _selected = <String>{};
  TagSuggestionSort _sort = TagSuggestionSort.suggested;
  String? _error;
  int _highlighted = 0;
  String get _query => TagParser.normalizeTag(_controller.text);
  Set<String> get _existing =>
      widget.existingTags.map(TagParser.normalizeTag).toSet();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _edit(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _error = null;
      _highlighted = 0;
    });
    _focusNode.requestFocus();
  }

  /// Validate the entire batch before staging any part of a paste.
  bool _stage(Iterable<String> raw) {
    final names = raw
        .map(TagParser.normalizeTag)
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.any((name) => !TagParser.isValidTag(name))) {
      setState(
        () => _error =
            'Use letters, numbers, hyphens or underscores. Separate subtags with /; '
            'each path segment must be complete.',
      );
      return false;
    }
    setState(() {
      _selected.addAll(names.where((name) => !_existing.contains(name)));
      _error = null;
      _highlighted = 0;
    });
    return true;
  }

  void _changed(String text) {
    setState(() {
      _error = null;
      _highlighted = 0;
    });
    // Let the IME finish composing before treating delimiters as commands.
    if (_controller.value.composing.isValid) return;
    final parts = text.split(RegExp(r'[,\n\r]'));
    if (parts.length > 1 && _stage(parts.take(parts.length - 1))) {
      _edit(parts.last);
    }
  }

  void _choose(String name) {
    if (_stage([name])) _edit('');
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty &&
        !_stage(_controller.text.split(RegExp(r'[,\n\r]')))) {
      return;
    }
    if (_selected.isEmpty) {
      setState(
        () => _error = _existing.contains(_query)
            ? 'This note already has that tag.'
            : 'Choose or type a tag first.',
      );
      return;
    }
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final query = _query;
    final tags = ref.watch(allTagsProvider);
    final catalogue = tags.valueOrNull ?? const [];
    final tagsByName = {for (final tag in catalogue) tag.name: tag};
    final excluded = {..._existing, ..._selected}.toList()..sort();
    final suggestions = ref.watch(
      tagSuggestionsProvider((
        query: query,
        sort: _sort,
        excluded: excluded.join('\n'),
      )),
    );
    // Never display results retained from an earlier query while loading.
    final names = suggestions.isLoading
        ? const <String>[]
        : suggestions.valueOrNull ?? const <String>[];
    final canCreate =
        !tags.isLoading &&
        !tags.hasError &&
        TagParser.isValidTag(query) &&
        !excluded.contains(query) &&
        !tagsByName.containsKey(query);
    final options = [...names, if (canCreate) query];
    final additionCount = {
      ..._selected,
      ..._controller.text
          .split(RegExp(r'[,\n\r]'))
          .map(TagParser.normalizeTag)
          .where(
            (name) => TagParser.isValidTag(name) && !_existing.contains(name),
          ),
    }.length;
    final active = _highlighted.clamp(
      0,
      options.isEmpty ? 0 : options.length - 1,
    );
    final slash = query.lastIndexOf('/');
    final parent = slash < 0 ? null : query.substring(0, slash);

    void move(int delta) {
      if (options.isEmpty) return;
      setState(() => _highlighted = (active + delta) % options.length);
      // Reveal the active option for keyboard users, including long catalogues.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _optionKeys[options[_highlighted]]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 100),
          );
        }
      });
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.tab): () {
          if (_focusNode.hasFocus && options.isNotEmpty && query.isNotEmpty) {
            _edit(options[active]);
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
      },
      child: Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.headline.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose several tags, or type new ones separated by commas.',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final name in _selected)
                              InputChip(
                                key: ValueKey('selected-tag-$name'),
                                label: Text('#$name'),
                                onDeleted: () =>
                                    setState(() => _selected.remove(name)),
                                deleteButtonTooltipMessage:
                                    'Remove #$name from selection',
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        key: const ValueKey('tag-picker-input'),
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.next,
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Search or create tags',
                          hintText: 'ideas, work/project',
                          prefixText: '#',
                          errorText: _error,
                          errorMaxLines: 4,
                          filled: true,
                          fillColor: colors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Select typed tag',
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    if (_stage(
                                      _controller.text.split(
                                        RegExp(r'[,\n\r]'),
                                      ),
                                    )) {
                                      _edit('');
                                    }
                                  },
                                ),
                        ),
                        onChanged: _changed,
                        onEditingComplete: () {},
                        onSubmitted: (_) {
                          if (options.isNotEmpty) {
                            _choose(options[active]);
                          } else if (_stage([_controller.text])) {
                            _edit('');
                          }
                        },
                      ),
                      if (parent != null && parent.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.subdirectory_arrow_right,
                              size: 16,
                            ),
                            Text(' Subtags of ', style: AppTypography.caption),
                            for (var i = 0; i < parent.split('/').length; i++)
                              TextButton(
                                onPressed: () => _edit(
                                  '${parent.split('/').take(i + 1).join('/')}/',
                                ),
                                child: Text(parent.split('/')[i]),
                              ),
                            IconButton(
                              tooltip: 'All tags',
                              onPressed: () => _edit(''),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final sort in TagSuggestionSort.values)
                            ChoiceChip(
                              label: Text(sort.label),
                              selected: _sort == sort,
                              onSelected: (_) => setState(() {
                                _sort = sort;
                                _highlighted = 0;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (suggestions.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(),
                        ),
                      if (suggestions.hasError)
                        TextButton.icon(
                          onPressed: () => ref.invalidate(allTagsProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Could not load tags. Retry'),
                        ),
                      for (var index = 0; index < options.length; index++)
                        _option(
                          options[index],
                          isNew: canCreate && index == options.length - 1,
                          highlighted: index == active,
                          parent: parent,
                          noteCount: tagsByName[options[index]]?.noteCount ?? 0,
                          pinned: tagsByName[options[index]]?.isPinned ?? false,
                        ),
                      if (!suggestions.isLoading &&
                          !suggestions.hasError &&
                          options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            excluded.contains(query)
                                ? 'Already added or selected.'
                                : query.isNotEmpty
                                ? 'No matching tags. Type a complete tag to create it.'
                                : switch (_sort) {
                                    TagSuggestionSort.recent =>
                                      'Tags you add will appear here.',
                                    TagSuggestionSort.pinned =>
                                      'Pin tags in the tag browser to see them here.',
                                    _ => 'Type a tag to get started.',
                                  },
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: colors.divider),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: QuietButton(
                        label: 'Cancel',
                        variant: QuietButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: QuietButton(
                        key: const ValueKey('tag-picker-apply'),
                        label: additionCount == 0
                            ? 'Add tags'
                            : 'Add $additionCount ${additionCount == 1 ? 'tag' : 'tags'}',
                        variant: QuietButtonVariant.primary,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final _optionKeys = <String, GlobalKey>{};

  Widget _option(
    String name, {
    required bool isNew,
    required bool highlighted,
    required String? parent,
    required int noteCount,
    required bool pinned,
  }) {
    final colors = context.appColors;
    final segments = name.split('/');
    return Material(
      key: _optionKeys.putIfAbsent(name, GlobalKey.new),
      color: highlighted
          ? colors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        key: ValueKey('tag-option-$name'),
        contentPadding: const EdgeInsets.only(left: 10, right: 4),
        leading: Icon(
          isNew
              ? Icons.add
              : pinned
              ? Icons.push_pin_outlined
              : Icons.tag,
          size: 20,
          color: colors.accent,
        ),
        title: Text(
          isNew
              ? 'Create #$name'
              : parent != null && name.startsWith('$parent/')
              ? name.substring(parent.length + 1)
              : '#$name',
          style: AppTypography.body.copyWith(color: colors.textPrimary),
        ),
        subtitle: segments.length > 1
            ? Text(
                segments.sublist(0, segments.length - 1).join(' / '),
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              )
            : null,
        onTap: () => _choose(name),
        trailing: isNew
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$noteCount',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Browse subtags of #$name',
                    onPressed: () => _edit('$name/'),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
      ),
    );
  }
}
