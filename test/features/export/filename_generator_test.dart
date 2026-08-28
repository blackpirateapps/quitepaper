import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/export/application/filename_generator.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

void main() {
  group('FilenameGenerator', () {
    test('sanitizes standard note title correctly', () {
      final name = FilenameGenerator.generateFilename(
        title: 'Project Roadmap 2026',
        format: ExportFormat.markdown,
      );
      expect(name, equals('Project Roadmap 2026.md'));
    });

    test('replaces invalid characters with safe separators', () {
      final name = FilenameGenerator.generateFilename(
        title: 'Meeting: Q1 / Review *Important* ?',
        format: ExportFormat.pdf,
      );
      expect(name, equals('Meeting - Q1 - Review Important.pdf'));
    });

    test('handles path separators and directory traversal characters safely', () {
      final name = FilenameGenerator.generateFilename(
        title: '../../etc/passwd',
        format: ExportFormat.plainText,
      );
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('\\')));
      expect(name, isNot(startsWith('..')));
    });

    test('handles Windows reserved filenames safely', () {
      final reserved = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM9', 'LPT1', 'LPT9'];
      for (final r in reserved) {
        final sanitized = FilenameGenerator.sanitizeBaseName(r);
        expect(sanitized, isNot(equals(r)));
        expect(sanitized, equals('${r}_Note'));
      }
    });

    test('falls back to Untitled when title is null or whitespace', () {
      expect(
        FilenameGenerator.generateFilename(
          title: null,
          format: ExportFormat.html,
        ),
        equals('Untitled.html'),
      );

      expect(
        FilenameGenerator.generateFilename(
          title: '   \n\t  ',
          format: ExportFormat.docx,
        ),
        equals('Untitled.docx'),
      );
    });

    test('truncates titles exceeding maximum length safely', () {
      final longTitle = 'A' * 200;
      final sanitized = FilenameGenerator.sanitizeBaseName(longTitle);
      expect(sanitized.length, lessThanOrEqualTo(FilenameGenerator.maxBaseLength));
    });

    test('generates unique collision-resistant filenames', () {
      final existing = {'meeting notes.md', 'meeting notes (2).md'};
      final unique = FilenameGenerator.generateUniqueFilename(
        title: 'Meeting Notes',
        format: ExportFormat.markdown,
        existingFilenames: existing,
      );
      expect(unique, equals('Meeting Notes (3).md'));
    });

    test('sanitizes attachment filenames with extension', () {
      final attName = FilenameGenerator.sanitizeAttachmentFilename(
        'photo: /scan/invoice: 001.PNG',
      );
      expect(attName, equals('photo - scan - invoice - 001.png'));
    });
  });
}
