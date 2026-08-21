import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/tag_parser.dart';
import '../../../core/web_clipper/web_clipper_models.dart';
import '../../../core/web_clipper/web_clipper_provider.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../editor/presentation/editor_screen.dart';

/// Bottom modal sheet presenting the pre-scanned article preview,
/// dynamic storage breakdown (Markdown, HTML snapshot, images), CupertinoSwitch toggles,
/// tag editor, and clip commitment action.
class WebClipPreviewSheet extends ConsumerStatefulWidget {
  const WebClipPreviewSheet({
    super.key,
    required this.scanResult,
  });

  final WebClipScanResult scanResult;

  static Future<void> show(
    BuildContext context, {
    required WebClipScanResult scanResult,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WebClipPreviewSheet(scanResult: scanResult),
    );
  }

  @override
  ConsumerState<WebClipPreviewSheet> createState() =>
      _WebClipPreviewSheetState();
}

class _WebClipPreviewSheetState extends ConsumerState<WebClipPreviewSheet> {
  late TextEditingController _titleController;
  late bool _saveHtmlSnapshot;
  late bool _downloadImages;
  late List<String> _tags;
  bool _isImagesExpanded = false;
  bool _isClipping = false;
  WebClipProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.scanResult.metadata.title);
    _saveHtmlSnapshot = true;
    _downloadImages = widget.scanResult.images.isNotEmpty;
    _tags = <String>[
      'clipped',
      if (widget.scanResult.metadata.domain.isNotEmpty)
        widget.scanResult.metadata.domain,
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _computedTotalSize {
    var size = widget.scanResult.markdownSizeEstimate;
    if (_saveHtmlSnapshot) {
      size += widget.scanResult.htmlSnapshotSizeEstimate;
    }
    if (_downloadImages) {
      size += widget.scanResult.totalImagesSizeEstimate;
    }
    return size;
  }

  Future<void> _commitClip() async {
    if (_isClipping) return;

    setState(() {
      _isClipping = true;
    });

    try {
      final clipperService = ref.read(webClipperServiceProvider);
      final options = WebClipperOptions(
        customTitle: _titleController.text.trim(),
        saveHtmlSnapshot: _saveHtmlSnapshot,
        downloadImages: _downloadImages,
        tags: _tags,
      );

      final result = await clipperService.clipArticle(
        scanResult: widget.scanResult,
        options: options,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _currentProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close sheet

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Article clipped: ${result.note.title}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Open note in editor
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditorScreen(note: result.note),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClipping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clip article: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _addTag(String raw) {
    final sanitized = TagParser.normalizeTag(raw);
    if (sanitized.isNotEmpty && !_tags.contains(sanitized)) {
      setState(() {
        _tags.add(sanitized);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final meta = widget.scanResult.metadata;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle & Navigation Header
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _isClipping
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Clip Webpage',
                      style: AppTypography.headline.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    QuietButton(
                      label: 'Clip',
                      variant: QuietButtonVariant.primary,
                      isLoading: _isClipping,
                      onPressed: _isClipping ? null : _commitClip,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Live Progress Indicator (if clipping)
                if (_isClipping && _currentProgress != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _currentProgress!.displayMessage,
                            style: AppTypography.body.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Section 1: Article Preview
                _buildSectionHeader('ARTICLE PREVIEW', colors),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (meta.leadImageUrl != null &&
                              meta.leadImageUrl!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                meta.leadImageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 56,
                                  height: 56,
                                  color: colors.background,
                                  child: Icon(Icons.language_rounded,
                                      color: colors.textTertiary, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  style: AppTypography.body.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText: 'Article Title',
                                    hintStyle: TextStyle(color: colors.textTertiary),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${meta.domain}${meta.author != null ? ' • By ${meta.author}' : ''}',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (meta.description != null &&
                          meta.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          meta.description!,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Section 2: Storage & Ingestion Options (iOS Grouped Table)
                _buildSectionHeader('STORAGE & INGESTION OPTIONS', colors),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    children: [
                      // Row 1: Core Markdown Body
                      _buildOptionRow(
                        icon: Icons.text_snippet_outlined,
                        title: 'Markdown Note (Core Body)',
                        subtitle: 'Distraction-free, editable note',
                        sizeStr: _formatBytes(
                            widget.scanResult.markdownSizeEstimate),
                        trailing: Icon(Icons.check_rounded,
                            size: 20, color: colors.accent),
                        colors: colors,
                      ),
                      _buildDivider(colors),

                      // Row 2: Web Snapshot Toggle
                      _buildOptionRow(
                        icon: Icons.web_rounded,
                        title: 'Save Web Snapshot',
                        subtitle: 'Captures exact HTML layout & styles',
                        sizeStr: _formatBytes(
                            widget.scanResult.htmlSnapshotSizeEstimate),
                        trailing: CupertinoSwitch(
                          value: _saveHtmlSnapshot,
                          activeTrackColor: colors.accent,
                          onChanged: _isClipping
                              ? null
                              : (val) {
                                  setState(() => _saveHtmlSnapshot = val);
                                },
                        ),
                        colors: colors,
                      ),

                      // Row 3: Images Download Toggle (if images exist)
                      if (widget.scanResult.images.isNotEmpty) ...[
                        _buildDivider(colors),
                        _buildOptionRow(
                          icon: Icons.image_outlined,
                          title: 'Download Images Locally',
                          subtitle:
                              'Save ${widget.scanResult.images.length} encrypted images & enable OCR',
                          sizeStr: _formatBytes(
                              widget.scanResult.totalImagesSizeEstimate),
                          trailing: CupertinoSwitch(
                            value: _downloadImages,
                            activeTrackColor: colors.accent,
                            onChanged: _isClipping
                                ? null
                                : (val) {
                                    setState(() => _downloadImages = val);
                                  },
                          ),
                          colors: colors,
                        ),
                        // Expandable Tray for Individual Images
                        if (_downloadImages) ...[
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isImagesExpanded = !_isImagesExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isImagesExpanded
                                        ? 'Hide image list ▴'
                                        : 'Show all ${widget.scanResult.images.length} images ▾',
                                    style: AppTypography.caption.copyWith(
                                      color: colors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatBytes(widget.scanResult
                                        .totalImagesSizeEstimate),
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isImagesExpanded) ...[
                            const Divider(height: 1, indent: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: widget.scanResult.images.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 48),
                              itemBuilder: (context, idx) {
                                final img = widget.scanResult.images[idx];
                                return ListTile(
                                  dense: true,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      img.resolvedUrl,
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 28,
                                        height: 28,
                                        color: colors.background,
                                        child: Icon(Icons.broken_image_outlined,
                                            size: 14,
                                            color: colors.textTertiary),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    img.altText.isNotEmpty
                                        ? img.altText
                                        : (img.isLeadImage
                                            ? 'Lead Image'
                                            : 'Image ${idx + 1}'),
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _formatBytes(img.estimatedSizeBytes),
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Section 3: Tags
                _buildSectionHeader('TAGS', colors),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ..._tags.map((tag) => Chip(
                            label: Text('#$tag'),
                            labelStyle: AppTypography.caption.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor:
                                colors.accent.withValues(alpha: 0.12),
                            side: BorderSide(
                                color: colors.accent.withValues(alpha: 0.25)),
                            deleteIcon: Icon(Icons.close_rounded,
                                size: 14, color: colors.textSecondary),
                            onDeleted:
                                _isClipping ? null : () => _removeTag(tag),
                          )),
                      ActionChip(
                        avatar: Icon(Icons.add_rounded,
                            size: 16, color: colors.accent),
                        label: Text('Add Tag',
                            style: AppTypography.caption
                                .copyWith(color: colors.accent)),
                        backgroundColor: colors.background,
                        side: BorderSide(color: colors.divider),
                        onPressed: _isClipping ? null : _showAddTagDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Total Estimated Storage Badge & Commit Action Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Storage Footprint',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatBytes(_computedTotalSize),
                        style: AppTypography.caption.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: QuietButton(
                    label: 'Clip Note (${_formatBytes(_computedTotalSize)})',
                    variant: QuietButtonVariant.primary,
                    isLoading: _isClipping,
                    onPressed: _isClipping ? null : _commitClip,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String sizeStr,
    required Widget trailing,
    required AppColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 20, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            sizeStr,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 48,
      color: colors.divider,
    );
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Add Tag', style: TextStyle(color: colors.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. technology, research',
              hintStyle: TextStyle(color: colors.textTertiary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            QuietButton(
              label: 'Add',
              onPressed: () => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      _addTag(result.trim());
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
