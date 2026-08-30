import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'attachment_type_resolver.dart';

/// Centralized icon and color resolver for attachments and generic files.
class AttachmentIconResolver {
  const AttachmentIconResolver._();

  /// Resolves an appropriate [IconData] for the given MIME type, filename, or kind.
  static IconData resolveIcon({
    required String mimeType,
    required String fileName,
    String? kind,
  }) {
    if (kind == 'image' || AttachmentTypeResolver.isImageMime(mimeType)) {
      return Icons.image_outlined;
    }
    if (kind == 'document' || AttachmentTypeResolver.isPdfMime(mimeType)) {
      return Icons.picture_as_pdf_outlined;
    }

    final ext = AttachmentTypeResolver.inferExtension(fileName, mimeType: mimeType).toLowerCase();
    final normMime = mimeType.toLowerCase().trim();

    // 1. Extension-based icon mapping
    switch (ext) {
      case 'docx':
      case 'doc':
      case 'rtf':
      case 'odt':
        return Icons.description_outlined;
      case 'xlsx':
      case 'xls':
      case 'csv':
      case 'tsv':
      case 'ods':
        return Icons.table_chart_outlined;
      case 'pptx':
      case 'ppt':
      case 'key':
      case 'odp':
        return Icons.slideshow_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'tgz':
      case '7z':
      case 'rar':
      case 'bz2':
        return Icons.folder_zip_outlined;
      case 'txt':
      case 'md':
      case 'markdown':
      case 'log':
        return Icons.article_outlined;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
      case 'html':
      case 'htm':
      case 'css':
        return Icons.data_object_rounded;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
      case 'java':
      case 'kt':
      case 'kts':
      case 'swift':
      case 'go':
      case 'rs':
      case 'sh':
      case 'bash':
      case 'sql':
        return Icons.code_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'aac':
        return Icons.audio_file_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return Icons.video_file_outlined;
      case 'ttf':
      case 'otf':
      case 'woff':
      case 'woff2':
        return Icons.font_download_outlined;
      case 'sqlite':
      case 'db':
        return Icons.storage_rounded;
      case 'bin':
      case 'dat':
      case 'iso':
      case 'dmg':
      case 'exe':
      case 'apk':
        return Icons.inventory_2_outlined;
    }

    // 2. MIME fallback
    if (normMime.startsWith('audio/')) {
      return Icons.audio_file_outlined;
    }
    if (normMime.startsWith('video/')) {
      return Icons.video_file_outlined;
    }
    if (normMime.startsWith('text/')) {
      return Icons.article_outlined;
    }
    if (normMime.contains('zip') || normMime.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  /// Resolves an accent color badge background for the attachment icon.
  static Color resolveIconTint({
    required String mimeType,
    required String fileName,
    required AppColors colors,
    String? kind,
  }) {
    if (kind == 'image' || AttachmentTypeResolver.isImageMime(mimeType)) {
      return colors.accent;
    }
    if (kind == 'document' || AttachmentTypeResolver.isPdfMime(mimeType)) {
      return const Color(0xFFD9534F); // Crimson / PDF Red
    }

    final ext = AttachmentTypeResolver.inferExtension(fileName, mimeType: mimeType).toLowerCase();
    switch (ext) {
      case 'docx':
      case 'doc':
        return const Color(0xFF2B579A); // Word Blue
      case 'xlsx':
      case 'xls':
      case 'csv':
        return const Color(0xFF217346); // Excel Green
      case 'pptx':
      case 'ppt':
        return const Color(0xFFD24726); // PowerPoint Orange
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return const Color(0xFF8E44AD); // Archive Purple
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'rs':
      case 'go':
      case 'html':
      case 'css':
        return const Color(0xFF00979D); // Code Cyan / Teal
      case 'json':
      case 'yaml':
      case 'yml':
      case 'xml':
        return const Color(0xFFE67E22); // Amber
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'flac':
        return const Color(0xFFE91E63); // Audio Pink
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return const Color(0xFF9C27B0); // Video Purple
      default:
        return colors.accent;
    }
  }
}
