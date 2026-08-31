import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/attachments/attachment_provider.dart';

/// Compact, non-blocking image thumbnail widget for note list tiles.
class NoteThumbnailView extends ConsumerStatefulWidget {
  const NoteThumbnailView({
    super.key,
    required this.thumbnailUri,
    this.size = 48.0,
  });

  final String thumbnailUri;
  final double size;

  @override
  ConsumerState<NoteThumbnailView> createState() => _NoteThumbnailViewState();
}

class _NoteThumbnailViewState extends ConsumerState<NoteThumbnailView> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(NoteThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailUri != widget.thumbnailUri) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final uri = widget.thumbnailUri.trim();
    if (!uri.startsWith('qp://asset/')) {
      // Network or custom URL is handled directly by Image.network
      return;
    }

    final assetId = uri.replaceFirst('qp://asset/', '').trim();
    if (assetId.isEmpty) return;

    try {
      final service = ref.read(attachmentServiceProvider);
      final resolution = await service.resolveAsset(assetId, variant: 'thumbnail');

      if (!mounted) return;
      if (resolution.isAvailable && resolution.data != null) {
        setState(() {
          _imageBytes = resolution.data;
        });
      } else {
        // Fallback to original variant if thumbnail is not available
        final origResolution = await service.resolveAsset(assetId, variant: 'original');
        if (!mounted) return;
        if (origResolution.isAvailable && origResolution.data != null) {
          setState(() {
            _imageBytes = origResolution.data;
          });
        }
      }
    } catch (_) {
      // Silent fallback to placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final uri = widget.thumbnailUri.trim();

    Widget content;

    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      content = Image.network(
        uri,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colors),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder(colors);
        },
      );
    } else if (_imageBytes != null) {
      content = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
      );
    } else {
      content = _buildPlaceholder(colors);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildPlaceholder(AppColors colors) {
    return Container(
      color: colors.surfaceSubtle,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 18,
        color: colors.textTertiary.withValues(alpha: 0.45),
      ),
    );
  }
}
