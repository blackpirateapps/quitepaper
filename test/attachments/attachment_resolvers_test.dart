import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/attachments/attachment_capability_resolver.dart';
import 'package:quitepaper/core/attachments/attachment_icon_resolver.dart';
import 'package:quitepaper/core/attachments/attachment_models.dart';
import 'package:quitepaper/core/attachments/attachment_type_resolver.dart';

void main() {
  group('AttachmentTypeResolver Tests', () {
    test('resolves human-readable labels for common formats', () {
      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          fileName: 'Quarterly_Report.docx',
        ),
        'Microsoft Word',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: 'budget_2026.xlsx',
        ),
        'Microsoft Excel',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/zip',
          fileName: 'source_archive.zip',
        ),
        'ZIP Archive',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'text/x-python',
          fileName: 'script.py',
        ),
        'Python Source',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/vnd.dart',
          fileName: 'main.dart',
        ),
        'Dart Source',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/pdf',
          fileName: 'contract.pdf',
        ),
        'PDF Document',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/octet-stream',
          fileName: 'firmware.bin',
        ),
        'Binary File',
      );

      expect(
        AttachmentTypeResolver.resolveDisplayName(
          mimeType: 'application/octet-stream',
          fileName: 'unknown_file_without_ext',
        ),
        'Unknown File',
      );
    });

    test('infers MIME types accurately from filenames', () {
      expect(AttachmentTypeResolver.inferMimeType('photo.png'), 'image/png');
      expect(AttachmentTypeResolver.inferMimeType('photo.jpg'), 'image/jpeg');
      expect(AttachmentTypeResolver.inferMimeType('doc.docx'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(AttachmentTypeResolver.inferMimeType('sheet.xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(AttachmentTypeResolver.inferMimeType('archive.zip'), 'application/zip');
      expect(AttachmentTypeResolver.inferMimeType('data.json'), 'application/json');
      expect(AttachmentTypeResolver.inferMimeType('config.yaml'), 'text/yaml');
      expect(AttachmentTypeResolver.inferMimeType('song.mp3'), 'audio/mpeg');
      expect(AttachmentTypeResolver.inferMimeType('video.mp4'), 'video/mp4');
      expect(AttachmentTypeResolver.inferMimeType('binary.dat'), 'application/octet-stream');
    });

    test('strictly sanitizes filenames against path traversal and forbidden characters', () {
      expect(
        AttachmentTypeResolver.sanitizeFileName('../../secret.docx'),
        'secret.docx',
      );

      expect(
        AttachmentTypeResolver.sanitizeFileName('..\\..\\windows\\system32\\config.sys'),
        'config.sys',
      );

      expect(
        AttachmentTypeResolver.sanitizeFileName('/etc/shadow'),
        'shadow',
      );

      expect(
        AttachmentTypeResolver.sanitizeFileName('foo:bar*baz?.txt'),
        'foo_bar_baz_.txt',
      );

      expect(
        AttachmentTypeResolver.sanitizeFileName('   ...   '),
        'attachment',
      );

      expect(
        AttachmentTypeResolver.sanitizeFileName(''),
        'attachment',
      );
    });

    test('detects path traversal attempts', () {
      expect(AttachmentTypeResolver.isPathTraversal('../../passwords.txt'), isTrue);
      expect(AttachmentTypeResolver.isPathTraversal('folder/sub/file.pdf'), isTrue);
      expect(AttachmentTypeResolver.isPathTraversal(r'c:\windows\file.txt'), isTrue);
      expect(AttachmentTypeResolver.isPathTraversal('.hidden'), isTrue);
      expect(AttachmentTypeResolver.isPathTraversal('clean_document.pdf'), isFalse);
    });
  });

  group('AttachmentIconResolver Tests', () {
    test('resolves icons for different file types', () {
      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          fileName: 'doc.docx',
        ),
        Icons.description_outlined,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: 'sheet.xlsx',
        ),
        Icons.table_chart_outlined,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'application/zip',
          fileName: 'bundle.zip',
        ),
        Icons.folder_zip_outlined,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'text/x-python',
          fileName: 'app.py',
        ),
        Icons.code_rounded,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'audio/mpeg',
          fileName: 'recording.mp3',
        ),
        Icons.audio_file_outlined,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'video/mp4',
          fileName: 'movie.mp4',
        ),
        Icons.video_file_outlined,
      );

      expect(
        AttachmentIconResolver.resolveIcon(
          mimeType: 'image/png',
          fileName: 'pic.png',
          kind: 'image',
        ),
        Icons.image_outlined,
      );
    });

    test('resolves appropriate tint colors', () {
      final colors = AppColors.light;
      final wordTint = AttachmentIconResolver.resolveIconTint(
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        fileName: 'report.docx',
        colors: colors,
      );
      expect(wordTint, const Color(0xFF2B579A));

      final excelTint = AttachmentIconResolver.resolveIconTint(
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileName: 'report.xlsx',
        colors: colors,
      );
      expect(excelTint, const Color(0xFF217346));
    });
  });

  group('AttachmentCapabilityResolver Tests', () {
    test('verifies capabilities for non-previewable binary files', () {
      final caps = AttachmentCapabilityResolver.getCapabilities(
        mimeType: 'application/zip',
        fileName: 'bundle.zip',
        kind: AttachmentKind.file,
      );

      expect(caps.contains(AttachmentCapability.storage), isTrue);
      expect(caps.contains(AttachmentCapability.openExternally), isTrue);
      expect(caps.contains(AttachmentCapability.share), isTrue);
      expect(caps.contains(AttachmentCapability.rename), isTrue);
      expect(caps.contains(AttachmentCapability.delete), isTrue);
      expect(caps.contains(AttachmentCapability.download), isTrue);
      expect(caps.contains(AttachmentCapability.ocr), isFalse);
      expect(caps.contains(AttachmentCapability.preview), isFalse);
      expect(caps.contains(AttachmentCapability.createNote), isFalse);
    });

    test('verifies capabilities for Markdown text attachments', () {
      final caps = AttachmentCapabilityResolver.getCapabilities(
        mimeType: 'text/markdown',
        fileName: 'README.md',
        kind: AttachmentKind.file,
      );

      expect(caps.contains(AttachmentCapability.preview), isTrue);
      expect(caps.contains(AttachmentCapability.renderMarkdown), isTrue);
      expect(caps.contains(AttachmentCapability.search), isTrue);
      expect(caps.contains(AttachmentCapability.selectText), isTrue);
      expect(caps.contains(AttachmentCapability.createNote), isTrue);
      expect(caps.contains(AttachmentCapability.wrapToggle), isTrue);
    });

    test('verifies capabilities for CSV spreadsheet attachments', () {
      final caps = AttachmentCapabilityResolver.getCapabilities(
        mimeType: 'text/csv',
        fileName: 'sales.csv',
        kind: AttachmentKind.file,
      );

      expect(caps.contains(AttachmentCapability.preview), isTrue);
      expect(caps.contains(AttachmentCapability.tableView), isTrue);
      expect(caps.contains(AttachmentCapability.search), isTrue);
      expect(caps.contains(AttachmentCapability.selectText), isTrue);
      expect(caps.contains(AttachmentCapability.createNote), isTrue);
    });

    test('verifies capabilities for source code attachments', () {
      final caps = AttachmentCapabilityResolver.getCapabilities(
        mimeType: 'application/vnd.dart',
        fileName: 'server.dart',
        kind: AttachmentKind.file,
      );

      expect(caps.contains(AttachmentCapability.preview), isTrue);
      expect(caps.contains(AttachmentCapability.lineNumbers), isTrue);
      expect(caps.contains(AttachmentCapability.search), isTrue);
      expect(caps.contains(AttachmentCapability.selectText), isTrue);
      expect(caps.contains(AttachmentCapability.createNote), isTrue);
      expect(caps.contains(AttachmentCapability.wrapToggle), isTrue);
    });

    test('verifies capabilities for images', () {
      final caps = AttachmentCapabilityResolver.getCapabilities(
        mimeType: 'image/png',
        fileName: 'sample.png',
        kind: AttachmentKind.image,
      );

      expect(caps.contains(AttachmentCapability.storage), isTrue);
      expect(caps.contains(AttachmentCapability.ocr), isTrue);
      expect(caps.contains(AttachmentCapability.preview), isTrue);
      expect(caps.contains(AttachmentCapability.thumbnail), isTrue);
    });
  });
}
