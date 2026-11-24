import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../application/tag_providers.dart';
import '../../application/tag_suggestions.dart';

/// Stages additions until Apply; dismissing the picker never mutates a note.
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
  }) => QuietAdaptiveModal.show<List<String>>(
    context: context,
    maxWidth: 440,
    showCloseButton: false,
    backgroundColor: context.appColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
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
    final existing = _existing.toList()..sort();
    final excluded = {...existing, ..._selected};
    TagSuggestionRequest request(String query) => (
      query: query,
      sort: TagSuggestionSort.suggested,
      excluded: existing.join('\n'),
    );
    // Keep the unfiltered list warm so choosing a search result can clear the
    // input immediately. Staging/removing chips never starts a ranking request.
    final defaults = ref.watch(tagSuggestionsProvider(request('')));
    final suggestions = query.isEmpty
        ? defaults
        : ref.watch(tagSuggestionsProvider(request(query)));
    // A catalogue refresh during sync retains this query's last ranked results.
    // Different queries have separate providers, so stale matches cannot leak
    // into a new search. Only the first load needs a progress indicator.
    final names = (suggestions.valueOrNull ?? const <String>[])
        .where((name) => !excluded.contains(name))
        .toList();
    final initialLoading = suggestions.isLoading && !suggestions.hasValue;
    final canCreate =
        !tags.isLoading &&
        !tags.hasError &&
        TagParser.isValidTag(query) &&
        !excluded.contains(query) &&
        !names.contains(query) &&
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
      final name = options[_highlighted];
      // Reveal the active option for keyboard users, including long catalogues.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _optionKeys[name]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 100),
          );
        }
      });
    }

    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
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
      child: SizedBox(
        key: const ValueKey('tag-picker-content'),
        width: 440,
        height: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('tag-picker-input'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
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
                                    _controller.text.split(RegExp(r'[,\n\r]')),
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
                    // Reserve one compact selection row so the search field
                    // and suggestions do not jump when the first tag is staged.
                    SizedBox(
                      height: 40 * MediaQuery.textScalerOf(context).scale(1),
                      child: _selected.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Separate new tags with commas',
                                style: AppTypography.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final name in _selected)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InputChip(
                                        key: ValueKey('selected-tag-$name'),
                                        label: Text('#$name'),
                                        labelStyle: AppTypography.caption,
                                        visualDensity: VisualDensity.compact,
                                        onDeleted: () => setState(
                                          () => _selected.remove(name),
                                        ),
                                        deleteButtonTooltipMessage:
                                            'Remove #$name from selection',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    if (parent != null && parent.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.subdirectory_arrow_right, size: 16),
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
                    Text(
                      'Suggestions',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (initialLoading)
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
                    if (!initialLoading &&
                        !suggestions.hasError &&
                        options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          excluded.contains(query)
                              ? 'Already added or selected.'
                              : query.isNotEmpty
                              ? 'No matching tags. Type a complete tag to create it.'
                              : 'Type a tag to get started.',
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
              padding: const EdgeInsets.all(8),
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
    );
    if (PlatformLayoutHelper.isDesktop(context)) return content;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (media.size.height -
                        media.viewInsets.bottom -
                        media.viewPadding.vertical)
                    .clamp(0, 460),
          ),
          child: content,
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
        dense: true,
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.only(left: 8),
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
          style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
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
