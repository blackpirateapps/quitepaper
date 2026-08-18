import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../application/markdown_import_scanner.dart';
import '../application/markdown_import_service.dart';
import '../domain/markdown_import_item.dart';
import 'widgets/add_tag_modal.dart';
import 'widgets/import_item_card.dart';

class MarkdownImportScreen extends ConsumerStatefulWidget {
  const MarkdownImportScreen({
    super.key,
    required this.initialFolderPath,
    this.initialItems,
  });

  final String initialFolderPath;
  final List<MarkdownImportItem>? initialItems;

  @override
  ConsumerState<MarkdownImportScreen> createState() => _MarkdownImportScreenState();
}

class _MarkdownImportScreenState extends ConsumerState<MarkdownImportScreen> {
  late String _currentFolderPath;
  List<MarkdownImportItem> _items = [];
  bool _isLoading = true;
  bool _isImporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentFolderPath = widget.initialFolderPath;
    if (widget.initialItems != null) {
      _items = List.from(widget.initialItems!);
      _isLoading = false;
    } else {
      _scanDirectory(_currentFolderPath);
    }
  }

  Future<void> _scanDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentFolderPath = path;
    });

    try {
      final items = await MarkdownImportScanner.scanFolder(path);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error reading folder: $e';
        });
      }
    }
  }

  Future<void> _pickAnotherFolder() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath != null && mounted) {
        _scanDirectory(selectedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open folder picker: $e')),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown'],
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        final items = await MarkdownImportScanner.processPickedFiles(result.files);
        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
            _currentFolderPath = 'Selected Files';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  int get _selectedCount => _items.where((i) => i.isSelected).length;

  bool get _areAllSelected => _items.isNotEmpty && _selectedCount == _items.length;

  void _toggleSelectAll(bool? selectAll) {
    final shouldSelect = selectAll ?? !_areAllSelected;
    setState(() {
      for (final item in _items) {
        item.isSelected = shouldSelect;
      }
    });
  }

  void _addTagToAllSelected() async {
    final newTag = await AddTagDialog.show(
      context,
      title: 'Add Tag to Selected Notes',
      hintText: 'e.g. imported, archive',
    );

    if (newTag != null && newTag.isNotEmpty) {
      setState(() {
        for (final item in _items) {
          if (item.isSelected) {
            item.addTag(newTag);
          }
        }
      });
    }
  }

  Future<void> _performImport() async {
    final selectedItems = _items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final service = ref.read(markdownImportServiceProvider);
      final count = await service.importNotes(selectedItems);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported $count ${count == 1 ? 'note' : 'notes'}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final folderName = p.basename(_currentFolderPath);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Markdown',
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
            Text(
              folderName.isNotEmpty ? folderName : _currentFolderPath,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.file_open_outlined,
              color: colors.textSecondary,
            ),
            tooltip: 'Pick markdown files',
            onPressed: _isLoading || _isImporting ? null : _pickFiles,
          ),
          IconButton(
            icon: Icon(
              Icons.folder_open_rounded,
              color: colors.textSecondary,
            ),
            tooltip: 'Choose different folder',
            onPressed: _isLoading || _isImporting ? null : _pickAnotherFolder,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: _buildBody(colors),
      ),
      bottomNavigationBar: _buildBottomBar(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scanning directory for Markdown files...',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
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
              Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              QuietButton(
                label: 'Choose another folder',
                icon: Icons.folder_open_rounded,
                variant: QuietButtonVariant.primary,
                onPressed: _pickAnotherFolder,
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 48, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Markdown Files Found',
                style: AppTypography.title.copyWith(color: colors.textPrimary, fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No .md or .markdown files were found in the chosen folder or its subdirectories.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  QuietButton(
                    label: 'Choose another folder',
                    icon: Icons.folder_open_rounded,
                    variant: QuietButtonVariant.primary,
                    onPressed: _pickAnotherFolder,
                  ),
                  QuietButton(
                    label: 'Select markdown files',
                    icon: Icons.file_open_outlined,
                    variant: QuietButtonVariant.secondary,
                    onPressed: _pickFiles,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Control Header: Select All & Bulk Actions
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _areAllSelected,
                  tristate: _selectedCount > 0 && !_areAllSelected,
                  onChanged: _toggleSelectAll,
                  activeColor: colors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$_selectedCount of ${_items.length} selected',
                  style: AppTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_selectedCount > 0)
                InkWell(
                  onTap: _addTagToAllSelected,
                  borderRadius: AppRadii.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.label_outline_rounded, size: 16, color: colors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Tag selected',
                          style: AppTypography.caption.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // List of found files
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return ImportItemCard(
                key: ValueKey(item.id),
                item: item,
                onToggleSelect: (val) {
                  setState(() {
                    item.isSelected = val ?? false;
                  });
                },
                onAddTag: (tag) {
                  setState(() {
                    item.addTag(tag);
                  });
                },
                onRemoveTag: (tag) {
                  setState(() {
                    item.removeTag(tag);
                  });
                },
                onEditTitle: (title) {
                  setState(() {
                    item.title = title;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar(AppColors colors) {
    if (_isLoading || _items.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: QuietButton(
                label: _isImporting
                    ? 'Importing...'
                    : 'Import $_selectedCount ${_selectedCount == 1 ? 'Note' : 'Notes'}',
                icon: _isImporting ? null : Icons.download_rounded,
                variant: _selectedCount > 0
                    ? QuietButtonVariant.primary
                    : QuietButtonVariant.secondary,
                isFullWidth: true,
                onPressed: (_selectedCount > 0 && !_isImporting) ? _performImport : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
