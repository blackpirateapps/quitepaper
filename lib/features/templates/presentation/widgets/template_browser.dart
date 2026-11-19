import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../notes/domain/note_model.dart';
import '../../application/template_providers.dart';
import '../../application/template_service.dart';
import '../../domain/note_template.dart';
import '../template_preview.dart';
import 'template_dialogs.dart';

class TemplateBrowser extends ConsumerStatefulWidget {
  const TemplateBrowser({
    super.key,
    required this.onCreated,
    this.activeTag,
    this.onManage,
    this.management = false,
  });
  final FutureOr<void> Function(Note) onCreated;
  final String? activeTag;
  final VoidCallback? onManage;
  final bool management;
  @override
  ConsumerState<TemplateBrowser> createState() => _TemplateBrowserState();
}

class _TemplateBrowserState extends ConsumerState<TemplateBrowser> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _busy = <String>{};
  NoteTemplate? _selected;
  Note? _committedNote;
  bool _creating = false;
  String? _error;
  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _mutate(
    String id,
    Future<void> Function() action, {
    String? success,
  }) async {
    if (_busy.contains(id)) return;
    setState(() {
      _busy.add(id);
      _error = null;
    });
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = templateErrorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(id);
        });
      }
    }
  }

  Future<void> _use() async {
    if (_creating || _selected == null) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    var completed = false;
    try {
      final note = _committedNote ??= await ref
          .read(templateServiceProvider)
          .instantiate(_selected!.id, activeTag: widget.activeTag);
      if (mounted) {
        await widget.onCreated(note);
        completed = true;
        _committedNote = null;
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _committedNote == null
              ? templateErrorMessage(error)
              : 'The note was created, but could not be opened. Try opening it again.';
        });
      }
    } finally {
      if (mounted && (!completed || widget.management)) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  void _back() {
    if (_creating) return;
    setState(() {
      _selected = null;
      _committedNote = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(templateCatalogProvider);
    final selected = _selected;
    return PopScope(
      canPop: !_creating && selected == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && selected != null) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_creating) return;
            if (_selected != null) {
              _back();
            } else {
              Navigator.maybePop(context);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(child: _header(selected)),
                      if (_error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: context.appColors.error),
                            ),
                          ),
                        ),
                      if (selected != null)
                        SliverFillRemaining(
                          child: TemplatePreview(
                            key: ValueKey(selected.id),
                            template: selected,
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(child: _searchField()),
                        catalog.when(
                          loading: () => const SliverToBoxAdapter(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, _) => SliverToBoxAdapter(
                            child: Center(
                              child: Text(templateErrorMessage(error)),
                            ),
                          ),
                          data: _catalogSliver,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: _creating ? null : _use,
                      child: Text(
                        _creating
                            ? 'Creating…'
                            : _committedNote != null
                            ? 'Open Created Note'
                            : 'Use Template',
                      ),
                    ),
                  )
                else if (widget.onManage != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: widget.onManage,
                      child: const Text('Manage Templates'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(NoteTemplate? selected) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
    child: Row(
      children: [
        if (selected != null)
          IconButton(
            tooltip: 'Back to templates',
            onPressed: _creating ? null : _back,
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected != null || !widget.management)
                Text(
                  selected?.displayName ?? 'Choose a Template',
                  style: AppTypography.headline.copyWith(
                    color: context.appColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (selected != null || !widget.management)
                const SizedBox(height: 4),
              Text(
                selected == null
                    ? (widget.management
                          ? 'Reusable starting points for your notes.'
                          : 'Start with a reusable structure.')
                    : selected.isBuiltIn
                    ? 'Built-in'
                    : 'My Template',
                style: AppTypography.bodySmall.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!widget.management)
          IconButton(
            tooltip: 'Close templates',
            onPressed: _creating ? null : () => Navigator.pop(context),
            icon: const Icon(PhosphorIconsRegular.x),
          ),
      ],
    ),
  );

  Widget _searchField() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        autofocus: !widget.management,
        style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        cursorColor: colors.accent,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search templates',
          hintStyle: AppTypography.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 19,
            color: colors.textSecondary,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    PhosphorIconsRegular.x,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  onPressed: () => setState(() {
                    _search.clear();
                  }),
                ),
          filled: true,
          fillColor: colors.surfaceSubtle,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadii.borderMd,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.borderMd,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.borderMd,
            borderSide: BorderSide(color: colors.accent, width: 1),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _catalogSliver(List<NoteTemplate> templates) {
    final sections = templateSections(templates, _search.text);
    if (sections.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 28,
                color: context.appColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'No templates found',
                style: AppTypography.bodyMedium.copyWith(
                  color: context.appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try a different name.',
                style: AppTypography.bodySmall.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final rows = <Object>[
      for (final section in sections) ...[section.title, ...section.templates],
    ];
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              row,
              style: AppTypography.caption.copyWith(
                color: context.appColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          );
        }
        return _row(row as NoteTemplate);
      },
    );
  }

  Widget _row(NoteTemplate template) {
    final service = ref.read(templateServiceProvider);
    final busy = _busy.contains(template.id);
    final colors = context.appColors;
    final snippet =
        _builtInDescriptions[template.id] ?? templateListSnippet(template);
    return Column(
      children: [
        ListTile(
          key: ValueKey('template-${template.id}'),
          contentPadding: const EdgeInsets.only(left: 20, right: 8),
          minLeadingWidth: 20,
          horizontalTitleGap: 12,
          minVerticalPadding: 12,
          leading: Icon(
            PhosphorIconsRegular.fileText,
            size: 22,
            color: colors.textSecondary,
          ),
          title: Text(
            template.displayName,
            style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            snippet,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => setState(() {
            _selected = template;
            _committedNote = null;
            _error = null;
          }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: template.isFavorite
                    ? 'Unfavorite ${template.displayName}'
                    : 'Favorite ${template.displayName}',
                onPressed: busy
                    ? null
                    : () => _mutate(
                        template.id,
                        () =>
                            service.favorite(template.id, !template.isFavorite),
                      ),
                icon: Icon(
                  template.isFavorite
                      ? PhosphorIconsFill.star
                      : PhosphorIconsRegular.star,
                  size: 20,
                  color: template.isFavorite
                      ? colors.accent
                      : colors.textTertiary,
                ),
              ),
              if (widget.management && !template.isBuiltIn)
                PopupMenuButton<String>(
                  tooltip: 'Template actions',
                  icon: Icon(
                    PhosphorIconsRegular.dotsThree,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  enabled: !busy,
                  onSelected: (action) async {
                    if (action == 'rename') {
                      await showTemplateNameDialog(
                        context: context,
                        initialName: template.displayName,
                        rename: true,
                        onSave: (name) => service.rename(template.id, name),
                      );
                    } else if (await confirmDeleteTemplate(context) &&
                        mounted) {
                      await _mutate(
                        template.id,
                        () => service.delete(template.id),
                        success: 'Template deleted',
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 54, right: 20),
          child: Divider(height: 1, thickness: 0.6, color: colors.divider),
        ),
      ],
    );
  }
}

const _builtInDescriptions = <String, String>{
  'builtin.daily_planner.v1':
      'Make room for priorities, tasks, and reflection.',
  'builtin.meeting_notes.v1':
      'Capture the discussion, decisions, and next steps.',
  'builtin.study_notes.v1':
      'Keep concepts, definitions, and questions together.',
  'builtin.reading_notes.v1':
      'Remember ideas, quotes, and your own reflections.',
  'builtin.project_brief.v1':
      'Outline the problem, goals, and scope of your work.',
  'builtin.bug_report.v1': 'Record what happened and how to reproduce it.',
  'builtin.weekly_review.v1': 'Reflect on the week and plan what comes next.',
  'builtin.decision_log.v1':
      'Keep the context and reasoning behind a decision.',
};
