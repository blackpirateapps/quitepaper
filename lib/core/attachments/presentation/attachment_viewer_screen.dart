import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/notes/application/notes_provider.dart';
import '../../database/app_database.dart';
import '../../syntax/application/syntax_provider.dart';
import '../../syntax/presentation/language_selector_sheet.dart';
import '../attachment_icon_resolver.dart';
import '../attachment_open_service.dart';
import '../attachment_provider.dart';
import '../attachment_type_resolver.dart';
import '../text/attachment_note_creator.dart';
import '../text/attachment_text_decoder.dart';
import '../text/attachment_text_detector.dart';
import 'attachment_file_info_sheet.dart';
import 'csv_attachment_viewer.dart';
import 'markdown_attachment_viewer.dart';
import 'plain_text_viewer.dart';

/// Unified read-only viewer for Quiet Paper text, markdown, CSV, structured,
/// and generic attachments (`qp://asset/<UUID>`).
class AttachmentViewerScreen extends ConsumerStatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.attachmentId,
    this.initialEntity,
    this.initialBytes,
  });

  final String attachmentId;
  final AttachmentEntity? initialEntity;
  final Uint8List? initialBytes;

  static Future<void> open(
    BuildContext context, {
    required String attachmentId,
    AttachmentEntity? initialEntity,
    Uint8List? initialBytes,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          attachmentId: attachmentId,
          initialEntity: initialEntity,
          initialBytes: initialBytes,
        ),
      ),
    );
  }

  @override
  ConsumerState<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends ConsumerState<AttachmentViewerScreen> {
  AttachmentEntity? _entity;
  Uint8List? _rawBytes;
  DecodedTextResult? _decoded;
  TextAttachmentFormat _format = TextAttachmentFormat.plainText;

  bool _isLoading = true;
  String? _errorMessage;
  String? _overrideLanguageId;

  // View preferences
  MarkdownViewMode _markdownMode = MarkdownViewMode.rendered;
  CsvViewMode _csvMode = CsvViewMode.table;
  bool _wordWrap = true;
  bool _showLineNumbers = false;

  // Search state
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _entity = widget.initialEntity;
    _rawBytes = widget.initialBytes;
    _loadAttachment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAttachment() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(attachmentServiceProvider);
      _entity ??= await service.database.getAttachment(widget.attachmentId);

      if (_rawBytes == null) {
        final res = await service.resolveAsset(widget.attachmentId);
        if (!res.isAvailable || res.data == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = res.errorMessage ?? 'Attachment unavailable';
            });
          }
          return;
        }
        _rawBytes = res.data;
      }

      final fileName = _entity?.fileName ?? 'attachment';
      final mimeType = _entity?.mimeType;
      _format = AttachmentTextDetector.detectFormat(
        fileName: fileName,
        bytes: _rawBytes!,
        mimeType: mimeType,
      );

      _wordWrap = AttachmentTextDetector.defaultWordWrap(_format);
      _showLineNumbers = AttachmentTextDetector.supportsLineNumbers(_format);

      if (AttachmentTextDetector.isTextFormat(_format)) {
        _decoded = AttachmentTextDecoder.decode(_rawBytes!);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (_isSearchOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSearchOpen) {
            _searchFocusNode.requestFocus();
          }
        });
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
        _searchQuery = '';
        _currentMatchIndex = 0;
        _totalMatches = 0;
      }
    });
  }

  void _onSearchChanged(String val) {
    int count = 0;
    final clean = val.trim().toLowerCase();
    final text = _decoded?.text ?? '';
    if (clean.isNotEmpty && text.isNotEmpty) {
      int start = 0;
      final lowerText = text.toLowerCase();
      while (start < lowerText.length) {
        final idx = lowerText.indexOf(clean, start);
        if (idx == -1) break;
        count++;
        start = idx + clean.length;
      }
    }
    setState(() {
      _searchQuery = val;
      _currentMatchIndex = 0;
      _totalMatches = count;
    });
  }

  void _nextMatch() {
    if (_totalMatches <= 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
  }

  void _previousMatch() {
    if (_totalMatches <= 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
  }

  Future<void> _handleCreateNote() async {
    if (_entity == null || _rawBytes == null) return;

    try {
      final repo = ref.read(notesRepositoryProvider);
      final newNote = await AttachmentNoteCreator.createNoteFromAttachment(
        notesRepository: repo,
        attachment: _entity!,
        rawBytes: _rawBytes!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created note: "${newNote.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create note: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleOpenExternally() async {
    final openService = ref.read(attachmentOpenServiceProvider);
    final res = await openService.openAttachment(
      widget.attachmentId,
      fallbackFileName: _entity?.fileName,
    );

    if (res.status != AttachmentOpenStatus.opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Could not open external app'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    final shareService = ref.read(attachmentShareServiceProvider);
    final ok = await shareService.shareAttachment(
      widget.attachmentId,
      fallbackFileName: _entity?.fileName,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share attachment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSaveAs() async {
    if (_rawBytes == null) return;

    final rawName = _entity?.fileName ?? 'attachment_${widget.attachmentId}';
    final sanitizedName = AttachmentTypeResolver.sanitizeFileName(rawName);
    final ext = AttachmentTypeResolver.inferExtension(sanitizedName);

    try {
      String? selectedPath;
      try {
        selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Attachment',
          fileName: sanitizedName,
          type: ext.isNotEmpty ? FileType.custom : FileType.any,
          allowedExtensions: ext.isNotEmpty ? [ext] : null,
          bytes: _rawBytes!,
        );
      } catch (e) {
        debugPrint('FilePicker saveFile fallback: $e');
      }

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final f = File(selectedPath);
        if (!await f.exists() || (await f.length()) == 0) {
          await f.writeAsBytes(_rawBytes!, flush: true);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${p.basename(selectedPath)}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Downloads fallback
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetFile = File(p.join(targetDir.path, sanitizedName));
      await targetFile.writeAsBytes(_rawBytes!, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${targetFile.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleRename() async {
    final colors = context.appColors;
    final currentName = _entity?.fileName ?? 'attachment';
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(
          'Rename Attachment',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new filename',
            hintStyle: TextStyle(color: colors.textTertiary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(dialogCtx).pop(val);
              }
            },
            child: Text('Rename', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final service = ref.read(attachmentServiceProvider);
      await service.renameAttachment(widget.attachmentId, newName);
      final fresh = await service.database.getAttachment(widget.attachmentId);
      if (mounted) {
        setState(() {
          _entity = fresh;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final colors = context.appColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(
          'Delete Attachment',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove this attachment from the note?',
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = ref.read(attachmentServiceProvider);
      await service.deleteAttachment(widget.attachmentId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _copyAllText() async {
    final text = _decoded?.text ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${text.length} characters to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entity = _entity;
    final fileName = entity?.fileName ?? 'Attachment';
    final resolvedLang = ref.watch(syntaxLanguageResolverProvider).resolveForAttachment(
      overrideLanguageId: _overrideLanguageId,
      mimeType: entity?.mimeType,
      fileName: fileName,
    );

    final String categoryLabel;
    if (_overrideLanguageId != null) {
      categoryLabel = '${resolvedLang.name} Source';
    } else {
      categoryLabel = AttachmentTextDetector.getCategoryLabel(_format, fileName: fileName);
    }

    final sizeLabel = _formatBytes(entity?.byteSize ?? _rawBytes?.length ?? 0);

    final isText = AttachmentTextDetector.isTextFormat(_format);
    final isMarkdown = _format == TextAttachmentFormat.markdown;
    final isCsv = _format == TextAttachmentFormat.csv || _format == TextAttachmentFormat.tsv;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearchOpen) _toggleSearch();
        },
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            foregroundColor: colors.textPrimary,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$categoryLabel • $sizeLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.sm / 2),
                      ),
                      child: Text(
                        'ENC (QPA1)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Search toggle
              if (isText)
                IconButton(
                  icon: Icon(_isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded),
                  tooltip: _isSearchOpen ? 'Close search (Esc)' : 'Search within file (Ctrl+F)',
                  onPressed: _toggleSearch,
                ),

              // Markdown view toggle shortcut in appbar
              if (isMarkdown)
                IconButton(
                  icon: Icon(_markdownMode == MarkdownViewMode.rendered ? Icons.code_rounded : Icons.menu_book_rounded),
                  tooltip: _markdownMode == MarkdownViewMode.rendered ? 'View Source' : 'View Rendered Markdown',
                  onPressed: () {
                    setState(() {
                      _markdownMode = _markdownMode == MarkdownViewMode.rendered
                          ? MarkdownViewMode.source
                          : MarkdownViewMode.rendered;
                    });
                  },
                ),

              // CSV view toggle shortcut in appbar
              if (isCsv)
                IconButton(
                  icon: Icon(_csvMode == CsvViewMode.table ? Icons.code_rounded : Icons.table_chart_rounded),
                  tooltip: _csvMode == CsvViewMode.table ? 'View CSV Source' : 'View Table',
                  onPressed: () {
                    setState(() {
                      _csvMode = _csvMode == CsvViewMode.table
                          ? CsvViewMode.source
                          : CsvViewMode.table;
                    });
                  },
                ),

              // Overflow Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Viewer options',
                onSelected: (val) async {
                  switch (val) {
                    case 'toggle_search':
                      _toggleSearch();
                      break;
                    case 'toggle_wrap':
                      setState(() => _wordWrap = !_wordWrap);
                      break;
                    case 'toggle_line_numbers':
                      setState(() => _showLineNumbers = !_showLineNumbers);
                      break;
                    case 'view_as':
                      final currentLang = _overrideLanguageId ?? resolvedLang.id;
                      final selected = await LanguageSelectorSheet.show(
                        context,
                        currentLanguageId: currentLang,
                        title: 'View Attachment As',
                      );
                      if (selected != null) {
                        setState(() {
                          _overrideLanguageId = selected.id;
                        });
                      }
                      break;
                    case 'toggle_markdown_mode':
                      setState(() {
                        _markdownMode = _markdownMode == MarkdownViewMode.rendered
                            ? MarkdownViewMode.source
                            : MarkdownViewMode.rendered;
                      });
                      break;
                    case 'toggle_csv_mode':
                      setState(() {
                        _csvMode = _csvMode == CsvViewMode.table
                            ? CsvViewMode.source
                            : CsvViewMode.table;
                      });
                      break;
                    case 'create_note':
                      _handleCreateNote();
                      break;
                    case 'copy_all':
                      _copyAllText();
                      break;
                    case 'file_info':
                      if (_entity != null) {
                        AttachmentFileInfoSheet.show(
                          context,
                          entity: _entity!,
                          decodedResult: _decoded,
                          format: _format,
                        );
                      }
                      break;
                    case 'open_externally':
                      _handleOpenExternally();
                      break;
                    case 'share':
                      _handleShare();
                      break;
                    case 'save_as':
                      _handleSaveAs();
                      break;
                    case 'rename':
                      _handleRename();
                      break;
                    case 'delete':
                      _handleDelete();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  if (isText) ...[
                    PopupMenuItem(
                      value: 'toggle_search',
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(_isSearchOpen ? 'Close Search' : 'Search (Ctrl+F)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_wrap',
                      child: Row(
                        children: [
                          Icon(Icons.wrap_text_rounded, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(_wordWrap ? 'Wrap Text ✓' : 'Wrap Text')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_line_numbers',
                      child: Row(
                        children: [
                          Icon(Icons.format_list_numbered_rounded, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(_showLineNumbers ? 'Line Numbers ✓' : 'Line Numbers')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'view_as',
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(_overrideLanguageId != null
                                ? 'View as: ${resolvedLang.name} ✓'
                                : 'View as…'),
                          ),
                        ],
                      ),
                    ),
                    if (isMarkdown)
                      PopupMenuItem(
                        value: 'toggle_markdown_mode',
                        child: Row(
                          children: [
                            Icon(Icons.preview_rounded, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_markdownMode == MarkdownViewMode.rendered ? 'Source Mode' : 'Rendered Mode'),
                            ),
                          ],
                        ),
                      ),
                    if (isCsv)
                      PopupMenuItem(
                        value: 'toggle_csv_mode',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart_rounded, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_csvMode == CsvViewMode.table ? 'Source Mode' : 'Table Mode'),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'create_note',
                      child: Row(
                        children: [
                          Icon(Icons.note_add_outlined, size: 18, color: colors.accent),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            isCsv ? 'Convert to Markdown Table' : 'Create Note from File',
                            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy_all',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Copy All Text'),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'file_info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('File Information'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'open_externally',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Open With…'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Share'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'save_as',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Save As'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: AppSpacing.sm),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Header Bar (when active)
              if (_isSearchOpen) _buildSearchBar(colors),

              // Bounded / Partial preview notice banner
              if (_decoded?.isTruncated == true)
                Container(
                  color: colors.accent.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: colors.accent),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Showing first ${_formatBytes(_decoded!.loadedByteSize)} of ${_formatBytes(_decoded!.totalByteSize)}',
                          style: TextStyle(fontSize: 12, color: colors.textPrimary),
                        ),
                      ),
                      TextButton(
                        onPressed: _handleOpenExternally,
                        child: Text('Open Externally', style: TextStyle(fontSize: 12, color: colors.accent)),
                      ),
                    ],
                  ),
                ),

              // Main Viewer Content Canvas
              Expanded(
                child: _buildContent(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppColors colors) {
    final matchLabel = _searchQuery.isEmpty
        ? ''
        : (_totalMatches == 0
            ? '0 matches'
            : '${_currentMatchIndex + 1}/$_totalMatches');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search in file…',
                hintStyle: TextStyle(fontSize: 14, color: colors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (matchLabel.isNotEmpty) ...[
            Text(
              matchLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _totalMatches > 0 ? colors.accent : colors.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            tooltip: 'Previous match',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _totalMatches > 0 ? _previousMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            tooltip: 'Next match',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _totalMatches > 0 ? _nextMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Close search',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppColors colors) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Decrypting attachment…',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withValues(alpha: 0.8)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not view attachment',
                style: AppTypography.headline.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _handleOpenExternally,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Externally'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _handleSaveAs,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save As'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_decoded != null && !_decoded!.isSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.text_snippet_outlined, size: 48, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                "This file's text encoding isn't supported",
                style: AppTypography.headline.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Quiet Paper could not determine a valid text encoding for this file.',
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _handleOpenExternally,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Externally'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _handleSaveAs,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save As'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!AttachmentTextDetector.isTextFormat(_format)) {
      return _buildGenericFileFallback(colors);
    }

    final text = _decoded?.text ?? '';
    final fileName = _entity?.fileName ?? 'Attachment';

    switch (_format) {
      case TextAttachmentFormat.markdown:
        return MarkdownAttachmentViewer(
          markdownData: text,
          mode: _markdownMode,
          searchQuery: _searchQuery,
          currentMatchIndex: _currentMatchIndex,
          onMatchesCountChanged: (count) {
            if (_totalMatches != count && mounted) {
              setState(() => _totalMatches = count);
            }
          },
          wordWrap: _wordWrap,
          showLineNumbers: _showLineNumbers,
          scrollController: _scrollController,
        );

      case TextAttachmentFormat.csv:
      case TextAttachmentFormat.tsv:
        return CsvAttachmentViewer(
          rawCsvText: text,
          mode: _csvMode,
          delimiter: _format == TextAttachmentFormat.tsv ? '\t' : ',',
          searchQuery: _searchQuery,
          currentMatchIndex: _currentMatchIndex,
          onMatchesCountChanged: (count) {
            if (_totalMatches != count && mounted) {
              setState(() => _totalMatches = count);
            }
          },
          wordWrap: _wordWrap,
          showLineNumbers: _showLineNumbers,
          scrollController: _scrollController,
        );

      case TextAttachmentFormat.plainText:
      case TextAttachmentFormat.json:
      case TextAttachmentFormat.yaml:
      case TextAttachmentFormat.xml:
      case TextAttachmentFormat.toml:
      case TextAttachmentFormat.log:
      case TextAttachmentFormat.config:
      case TextAttachmentFormat.sourceCode:
      case TextAttachmentFormat.unknownText:
      case TextAttachmentFormat.binary:
        return PlainTextViewer(
          text: text,
          format: _format,
          fileName: fileName,
          mimeType: _entity?.mimeType,
          overrideLanguageId: _overrideLanguageId,
          isMonospaced: AttachmentTextDetector.isMonospaced(_format),
          showLineNumbers: _showLineNumbers,
          wordWrap: _wordWrap,
          searchQuery: _searchQuery,
          currentMatchIndex: _currentMatchIndex,
          onMatchesCountChanged: (count) {
            if (_totalMatches != count && mounted) {
              setState(() => _totalMatches = count);
            }
          },
          scrollController: _scrollController,
        );
    }
  }

  Widget _buildGenericFileFallback(AppColors colors) {
    final entity = _entity;
    final fileName = entity?.fileName ?? 'File';
    final mimeType = entity?.mimeType ?? 'application/octet-stream';
    final typeLabel = AttachmentTypeResolver.resolveDisplayName(mimeType: mimeType, fileName: fileName);
    final sizeLabel = _formatBytes(entity?.byteSize ?? _rawBytes?.length ?? 0);
    final icon = AttachmentIconResolver.resolveIcon(mimeType: mimeType, fileName: fileName, kind: entity?.kind);
    final iconTint = AttachmentIconResolver.resolveIconTint(mimeType: mimeType, fileName: fileName, colors: colors, kind: entity?.kind);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconTint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: iconTint.withValues(alpha: 0.25), width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 36, color: iconTint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              fileName,
              style: AppTypography.headline.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$typeLabel • $sizeLabel',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "This file can't be previewed directly in Quiet Paper.",
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _handleOpenExternally,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open With…'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleShare,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleSaveAs,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Save As'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
