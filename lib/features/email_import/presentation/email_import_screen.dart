import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/security/sensitive_preview_registry.dart';
import '../../../core/note_links/note_link_search_service.dart';
import '../../notes/domain/note_model.dart';
import '../application/email_import_gateway.dart';
import '../application/email_parser.dart';
import '../domain/email_message.dart';

class EmailImportScreen extends ConsumerStatefulWidget {
  const EmailImportScreen({super.key, required this.request});
  final EmailImportRequest request;
  @override
  ConsumerState<EmailImportScreen> createState() => _EmailImportScreenState();
}

class _ReviewItem {
  _ReviewItem({
    required this.index,
    required this.title,
    required this.sender,
    required this.size,
    required this.count,
    required this.duplicates,
    required this.sourceFingerprint,
    this.sourceHash,
  });
  final int index, size, count;
  final String sourceFingerprint;
  final String? sourceHash;
  String title;
  final String sender;
  final List<({String noteId, bool exact})> duplicates;
  bool included = true;
}

class _EmailImportScreenState extends ConsumerState<EmailImportScreen> {
  final _title = TextEditingController();
  final _tags = TextEditingController(text: 'email');
  final _sender = TextEditingController();
  final _recipients = TextEditingController();
  final _date = TextEditingController();
  final _items = <_ReviewItem>[];
  final _errors = <String>[];
  final _saved = <Note>[];
  EmailMessage? _email;
  Note? _destination;
  List<NoteLinkSearchResultItem> _destinations = [];
  EmailImportMode _mode = EmailImportMode.editable;
  int _selected = 0, _generation = 0, _searchGeneration = 0;
  int _failed = 0, _completed = 0, _batchTotal = 0, _invalidCount = 0;
  bool _loading = true,
      _saving = false,
      _cancel = false,
      _allowDuplicate = false,
      _done = false,
      _locked = false;
  String? _error;
  EmailImportGateway get gateway => ref.read(emailImportGatewayProvider);

  @override
  void initState() {
    super.initState();
    SensitivePreviewRegistry.revision.addListener(_invalidate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _invalidate() {
    _generation++;
    _cancel = true;
    widget.request.clear();
    _email = null;
    _errors.clear();
    _error = null;
    _items.clear();
    _destinations = [];
    _saved.clear();
    _destination = null;
    for (final controller in [_title, _tags, _sender, _recipients, _date]) {
      controller.clear();
    }
    if (mounted) {
      setState(() {
        _locked = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancel = true;
    SensitivePreviewRegistry.revision.removeListener(_invalidate);
    widget.request.clear();
    _email = null;
    for (final controller in [_title, _tags, _sender, _recipients, _date]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await gateway.initialize();
      if (!mounted || generation != _generation) return;
      if (!gateway.isUnlocked) {
        _invalidate();
        return;
      }
      final count = widget.request.sharedContent == null
          ? widget.request.inputs.length
          : 1;
      if (count > EmailLimits.batchSize) {
        throw const EmailImportException(
          'batch_size',
          'Select at most 100 emails per import.',
        );
      }
      final fingerprints = <String>{};
      for (var index = 0; index < count; index++) {
        if (!mounted || generation != _generation) return;
        var fileLabel = 'Shared content';
        if (widget.request.sharedContent == null) {
          final input = widget.request.inputs[index];
          fileLabel = EmailParser.sanitizeFileName(
            input.name ?? input.path.replaceAll('\\', '/').split('/').last,
          );
        }
        try {
          final email =
              widget.request.sharedContent ??
              await gateway.parse(widget.request.inputs[index]);
          final duplicates = await gateway.duplicates(email);
          if (!fingerprints.add(email.fingerprint)) {
            duplicates.add((noteId: '', exact: true));
          }
          if (!mounted || generation != _generation || !gateway.isUnlocked) {
            return;
          }
          _items.add(
            _ReviewItem(
              index: index,
              title: email.subject,
              sourceFingerprint: email.fingerprint,
              sourceHash: email.rawHash,
              sender: email.sender,
              size: email.attachmentSize,
              count: email.attachments.length,
              duplicates: duplicates,
            ),
          );
          if (_email == null) {
            _email = email;
            _updateFields(email);
          }
        } on EmailImportException catch (e) {
          _invalidCount++;
          _errors.add('Item ${index + 1}: $fileLabel — ${e.message}');
        } catch (_) {
          _invalidCount++;
          _errors.add(
            'Item ${index + 1}: $fileLabel — Could not read this email.',
          );
        }
        if (mounted) setState(() {});
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = 'No valid emails are available to import.';
      });
      await _searchDestinations('');
    } on EmailImportException catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error =
              'Could not prepare email import. Retry after checking storage.';
        });
      }
    }
  }

  void _updateFields(EmailMessage email) {
    _title.text = email.subject;
    _sender.text = email.sender == 'Unknown sender' ? '' : email.sender;
    _recipients.text = email.to;
    _date.text = email.originalDate;
  }

  Future<void> _select(int index) async {
    _items[_selected].title = _title.text;
    final generation = ++_generation;
    setState(() {
      _selected = index;
      _loading = true;
      _email = null;
    });
    try {
      final email =
          widget.request.sharedContent ??
          await gateway.parse(widget.request.inputs[_items[index].index]);
      if (!mounted || generation != _generation || _locked) return;
      setState(() {
        _email = email;
        _updateFields(email);
        _title.text = _items[index].title;
        _loading = false;
      });
    } on EmailImportException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not reopen this email.';
        });
      }
    }
  }

  Future<void> _searchDestinations(String query) async {
    final generation = ++_searchGeneration;
    try {
      final results = await gateway.search(query);
      if (!mounted || generation != _searchGeneration || _locked) return;
      final currentId = widget.request.currentNoteId;
      if (currentId != null) {
        final current = await gateway.note(currentId);
        if (current != null &&
            !current.isTrashed &&
            !current.isPasswordProtected &&
            !results.any((n) => n.id == currentId)) {
          results.insert(
            0,
            NoteLinkSearchResultItem(
              id: current.id,
              title: current.title,
              snippet: 'Current note',
              tags: current.tags,
              updatedAt: current.updatedAt,
            ),
          );
        } else {
          results.sort(
            (a, b) => a.id == currentId
                ? -1
                : b.id == currentId
                ? 1
                : 0,
          );
        }
      }
      if (mounted && generation == _searchGeneration && !_locked) {
        setState(
          () => _destinations = results
              .where((n) => !n.isPasswordProtected)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not search destinations. Try again.');
      }
    }
  }

  Future<void> _chooseDestination(String id) async {
    setState(() => _destination = null);
    try {
      final note = await gateway.note(id);
      if (mounted && !_locked) {
        setState(() {
          _destination = note;
          if (note == null) {
            _error = 'The destination is unavailable. Choose another note.';
          }
        });
      }
    } catch (_) {
      if (mounted && !_locked) {
        setState(
          () => _error =
              'Could not load the destination. Try selecting it again.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _items.isEmpty || _email == null || _locked) {
      return;
    }
    _items[_selected].title = _title.text;
    setState(() {
      _saving = true;
      _error = null;
      _cancel = false;
      _failed = 0;
      _completed = 0;
    });
    final active = _items.where((i) => i.included).toList();
    _batchTotal = active.length;
    for (final item in active) {
      if (_cancel || !mounted || _locked) break;
      EmailMessage? savingEmail;
      try {
        var email = item.index == _items[_selected].index
            ? _email!
            : await gateway.parse(widget.request.inputs[item.index]);
        if (email.rawHash != item.sourceHash ||
            email.fingerprint != item.sourceFingerprint) {
          throw const EmailImportException(
            'source_changed',
            'The source changed since preview. Select it again to review.',
          );
        }
        if (widget.request.sharedContent != null) {
          email = const EmailParser().sharedText(
            text: widget.request.sharedContent!.markdown,
            subject: _title.text,
            sender: _sender.text,
            to: _recipients.text,
            date: _date.text,
          );
          // The input is already safely converted; avoid escaping it again.
          email = EmailMessage(
            subject: email.subject,
            sender: email.sender,
            to: email.to,
            originalDate: email.originalDate,
            sentAt: email.sentAt,
            markdown: widget.request.sharedContent!.markdown,
            fingerprint: EmailParser.fingerprint(
              email.sender,
              email.subject,
              _date.text,
              widget.request.sharedContent!.markdown,
            ),
          );
        }
        savingEmail = email;
        final saved = await gateway.save(
          email: email,
          mode: _mode,
          title: item.title,
          tags: _tags.text
              .split(RegExp(r'[,\s]+'))
              .map((t) => t.replaceFirst(RegExp(r'^#'), ''))
              .where((t) => t.isNotEmpty)
              .toList(),
          destination: _destination,
          allowDuplicate: _allowDuplicate,
          isCancelled: () => _cancel || !mounted || _locked,
        );
        widget.request.committedNoteIds.add(saved.id);
        if (_locked || !mounted) break;
        _saved.add(saved);
        _errors.removeWhere(
          (message) => message.startsWith('Item ${item.index + 1}:'),
        );
        item.included = false;
        if (_mode == EmailImportMode.append) _destination = saved;
      } on EmailImportException catch (e) {
        if (e.code == 'cancelled') break;
        if (e.code == 'duplicate' && savingEmail != null) {
          try {
            final matches = await gateway.duplicates(savingEmail);
            item.duplicates
              ..clear()
              ..addAll(matches);
          } catch (_) {
            /* Keep the original, readable duplicate error. */
          }
        }
        _failed++;
        _errors.add('Item ${item.index + 1}: ${e.message}');
      } catch (_) {
        _failed++;
        _errors.add('Item ${item.index + 1}: Could not save this email.');
      }
      _completed++;
      if (mounted && !_locked) setState(() {});
    }
    if (!mounted || _locked) return;
    setState(() {
      _saving = false;
      _done = true;
    });
    if (_items.length == 1 && _saved.length == 1 && _failed == 0) {
      Navigator.of(context).pop(_saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final email = _email;
    final hasExact = _items.any(
      (i) => i.included && i.duplicates.any((d) => d.exact),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_saving) {
            Navigator.of(context).pop();
          } else {
            setState(() => _cancel = true);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _cancel = true);
          },
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              title: const Text('Import Email'),
              actions: [
                TextButton(
                  onPressed: _saving
                      ? () => setState(() => _cancel = true)
                      : () => Navigator.of(context).pop(),
                  child: Text(_saving ? 'Cancel remaining import' : 'Cancel'),
                ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _locked
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Preview cleared. Unlock your notebook and select the email again.',
                        ),
                      )
                    : Column(
                        children: [
                          if (_loading || _saving)
                            LinearProgressIndicator(
                              semanticsLabel: _saving
                                  ? 'Saving emails'
                                  : 'Parsing emails',
                            ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                if (_saving)
                                  Text(
                                    'Importing emails — ${(_completed + 1).clamp(1, _batchTotal)} of $_batchTotal',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                if (_done) ...[
                                  Text(
                                    'Imported: ${_saved.length} • Skipped: ${_items.length - _saved.length - _failed + _invalidCount} • Duplicates: ${_items.where((i) => i.duplicates.isNotEmpty).length} • Failed: $_failed',
                                  ),
                                  if (_saved.isNotEmpty)
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(_saved),
                                      child: const Text('View imported notes'),
                                    ),
                                  if (_failed > 0)
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _done = false),
                                      child: const Text(
                                        'Review and retry failed emails',
                                      ),
                                    ),
                                ],
                                if (_error != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                if (_error != null &&
                                    _items.isEmpty &&
                                    _errors.isEmpty)
                                  TextButton(
                                    onPressed: _initialize,
                                    child: const Text('Retry'),
                                  ),
                                if (_errors.isNotEmpty) ...[
                                  const Text('Unsupported or failed items'),
                                  ..._errors.map((e) => Text(e)),
                                ],
                                if (!_done && _items.isNotEmpty) ...[
                                  Text(
                                    '${widget.request.sharedContent != null ? 1 : widget.request.inputs.length} selected • ${_items.length} valid • ${_errors.length} invalid • ${_items.where((i) => i.duplicates.any((d) => d.exact)).length} exact duplicates • ${_items.where((i) => i.duplicates.any((d) => !d.exact)).length} related • ${(_items.fold<int>(0, (sum, i) => sum + i.size) / 1024).toStringAsFixed(1)} KiB attachments',
                                  ),
                                  if (_items.length > 1)
                                    ..._items.asMap().entries.map(
                                      (entry) => CheckboxListTile(
                                        value: entry.value.included,
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => entry.value.included =
                                                    value ?? false,
                                              ),
                                        title: Text(
                                          entry.value.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        secondary: IconButton(
                                          tooltip:
                                              'Review email ${entry.key + 1}',
                                          onPressed: _saving
                                              ? null
                                              : () => _select(entry.key),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (email != null) ...[
                                    TextField(
                                      controller: _title,
                                      enabled: !_saving,
                                      decoration: const InputDecoration(
                                        labelText: 'Note title',
                                      ),
                                    ),
                                    if (email.isSharedContent) ...[
                                      const Text(
                                        'Shared content — original email and missing headers are unavailable.',
                                      ),
                                      TextField(
                                        controller: _sender,
                                        enabled: !_saving,
                                        decoration: const InputDecoration(
                                          labelText: 'Sender (optional)',
                                        ),
                                      ),
                                      TextField(
                                        controller: _recipients,
                                        enabled: !_saving,
                                        decoration: const InputDecoration(
                                          labelText: 'Recipients (optional)',
                                        ),
                                      ),
                                      TextField(
                                        controller: _date,
                                        enabled: !_saving,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Date (optional, ISO 8601)',
                                        ),
                                      ),
                                    ] else ...[
                                      Text('From: ${email.sender}'),
                                      if (email.to.isNotEmpty)
                                        Text('To: ${email.to}'),
                                      if (email.cc.isNotEmpty)
                                        Text('Cc: ${email.cc}'),
                                      Text(
                                        email.sentAt == null
                                            ? 'Date unavailable'
                                            : email.originalDate,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    SelectableText(
                                      email.markdown.isEmpty
                                          ? 'No readable email body was provided.'
                                          : email.markdown,
                                    ),
                                    const Divider(),
                                    Text(
                                      '${email.attachments.length} attachments',
                                    ),
                                    ...email.attachments.map(
                                      (a) => Text(
                                        '${a.fileName} • ${a.mimeType} • ${a.bytes.length} bytes',
                                      ),
                                    ),
                                    ...email.warnings.map((w) => Text(w)),
                                    if ((email.rawBytes?.length ?? 0) >
                                            10000000 ||
                                        email.attachments.any(
                                          (a) => a.bytes.length > 10000000,
                                        ))
                                      const Text(
                                        'Large assets are preserved locally and in backups. The current cloud upload limit is 10 MB per asset; larger assets will remain pending.',
                                      ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<EmailImportMode>(
                                      isExpanded: true,
                                      initialValue: _mode,
                                      decoration: const InputDecoration(
                                        labelText: 'Import mode',
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: EmailImportMode.editable,
                                          child: Text(
                                            'Editable note + original',
                                          ),
                                        ),
                                        if (!email.isSharedContent)
                                          const DropdownMenuItem(
                                            value: EmailImportMode.archive,
                                            child: Text(
                                              'Original archive only',
                                            ),
                                          ),
                                        const DropdownMenuItem(
                                          value: EmailImportMode.append,
                                          child: Text(
                                            'Append to existing note',
                                          ),
                                        ),
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (value) =>
                                                setState(() => _mode = value!),
                                    ),
                                    if (_mode == EmailImportMode.append) ...[
                                      TextField(
                                        enabled: !_saving,
                                        decoration: const InputDecoration(
                                          labelText: 'Search destination notes',
                                        ),
                                        onChanged: _searchDestinations,
                                      ),
                                      if (_destination != null)
                                        Text(
                                          'Destination: ${_destination!.displayTitle}',
                                        ),
                                      ..._destinations
                                          .take(8)
                                          .map(
                                            (n) => ListTile(
                                              title: Text(n.displayTitle),
                                              subtitle:
                                                  n.id ==
                                                      widget
                                                          .request
                                                          .currentNoteId
                                                  ? const Text('Current note')
                                                  : null,
                                              selected:
                                                  _destination?.id == n.id,
                                              onTap: _saving
                                                  ? null
                                                  : () => _chooseDestination(
                                                      n.id,
                                                    ),
                                            ),
                                          ),
                                    ],
                                    TextField(
                                      controller: _tags,
                                      enabled: !_saving,
                                      decoration: const InputDecoration(
                                        labelText: 'Tags (comma separated)',
                                      ),
                                    ),
                                    if (_items[_selected]
                                        .duplicates
                                        .isNotEmpty) ...[
                                      Text(
                                        _items[_selected].duplicates.any(
                                              (d) => d.exact,
                                            )
                                            ? 'This email is already saved.'
                                            : 'A related email may already be saved',
                                      ),
                                      ..._items[_selected].duplicates
                                          .where((d) => d.noteId.isNotEmpty)
                                          .take(3)
                                          .map(
                                            (d) => TextButton(
                                              onPressed: _saving
                                                  ? null
                                                  : () async {
                                                      final note = await gateway
                                                          .note(d.noteId);
                                                      if (mounted &&
                                                          !_locked &&
                                                          note != null) {
                                                        Navigator.of(
                                                          this.context,
                                                        ).pop([note]);
                                                      }
                                                    },
                                              child: const Text(
                                                'Open existing note',
                                              ),
                                            ),
                                          ),
                                    ],
                                    if (hasExact)
                                      CheckboxListTile(
                                        value: _allowDuplicate,
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(
                                                () => _allowDuplicate =
                                                    v ?? false,
                                              ),
                                        title: const Text(
                                          'Import another copy of duplicate emails',
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed:
                                          _saving ||
                                              _loading ||
                                              (_mode ==
                                                      EmailImportMode.append &&
                                                  _destination == null) ||
                                              (hasExact && !_allowDuplicate) ||
                                              !_items.any((i) => i.included)
                                          ? null
                                          : _save,
                                      child: Text(
                                        _errors.isNotEmpty
                                            ? 'Continue with valid emails'
                                            : 'Import email${_items.length > 1 ? 's' : ''}',
                                      ),
                                    ),
                                  ],
                                ],
                                if (_loading) const Text('Parsing emails…'),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
