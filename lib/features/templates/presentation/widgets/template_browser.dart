import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _search,
                              focusNode: _searchFocus,
                              autofocus: !widget.management,
                              decoration: const InputDecoration(
                                hintText: 'Search templates',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
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
            icon: const Icon(Icons.arrow_back),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected?.displayName ??
                    (widget.management ? 'Templates' : 'Choose a Template'),
                style: AppTypography.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                selected == null
                    ? (widget.management
                          ? 'Reusable starting points for your notes.'
                          : 'Start with a reusable structure.')
                    : selected.isBuiltIn
                    ? 'Built-in'
                    : 'My Template',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        if (!widget.management)
          IconButton(
            tooltip: 'Close templates',
            onPressed: _creating ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );

  Widget _catalogSliver(List<NoteTemplate> templates) {
    final sections = templateSections(templates, _search.text);
    if (sections.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Text('No templates found')),
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
            child: Text(row, style: AppTypography.caption),
          );
        }
        return _row(row as NoteTemplate);
      },
    );
  }

  Widget _row(NoteTemplate template) {
    final service = ref.read(templateServiceProvider);
    final busy = _busy.contains(template.id);
    final snippet = templateListSnippet(template);
    return ListTile(
      key: ValueKey('template-${template.id}'),
      leading: const Icon(Icons.description_outlined),
      title: Text(
        template.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${template.isBuiltIn ? 'Built-in' : 'My Template'} · $snippet',
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
                    () => service.favorite(template.id, !template.isFavorite),
                  ),
            icon: Icon(
              template.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: template.isFavorite ? context.appColors.accent : null,
            ),
          ),
          if (widget.management && !template.isBuiltIn)
            PopupMenuButton<String>(
              tooltip: 'Template actions',
              enabled: !busy,
              onSelected: (action) async {
                if (action == 'rename') {
                  await showTemplateNameDialog(
                    context: context,
                    initialName: template.displayName,
                    rename: true,
                    onSave: (name) => service.rename(template.id, name),
                  );
                } else if (await confirmDeleteTemplate(context) && mounted) {
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
    );
  }
}
