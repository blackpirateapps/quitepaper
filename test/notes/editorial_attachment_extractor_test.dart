import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/editorial_attachment_extractor.dart';
import 'package:quitepaper/features/notes/domain/editorial_attachment_item.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  final now = DateTime(2026, 9, 6, 12, 0);

  setUp(() {
    EditorialAttachmentExtractor.clearCache();
  });

  group('EditorialAttachmentExtractor Tests', () {
    test('returns empty list for notes without attachments', () {
      final note = Note(
        id: 'note-plain',
        title: 'Plain Note',
        content: 'This is just a regular text note without any attachments.',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments, isEmpty);
    });

    test('extracts single image correctly', () {
      final note = Note(
        id: 'note-polar',
        title: 'Polar Bears',
        content: '''The largest #bear in the world and the Arctic's top predator.
![Polar bear on snow](qp://asset/polar-123)
Polar bears are powerful symbols.''',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments.length, 1);
      expect(attachments.first.kind, EditorialAttachmentKind.image);
      expect(attachments.first.uri, 'qp://asset/polar-123');
      expect(attachments.first.title, 'Polar bear on snow');
      expect(attachments.first.isImage, true);
    });

    test('extracts mixed image and scanned document attachments', () {
      final note = Note(
        id: 'note-green',
        title: 'My green friends',
        content: '''Plant tracker 🌱 Plant 🪣 Watered last Spider Plant.
![Plant Collection](qp://asset/plant-img-1)
[Ultimate guide to](qp://document/guide-doc-2)
Just now.''',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments.length, 2);

      // Image
      expect(attachments[0].kind, EditorialAttachmentKind.image);
      expect(attachments[0].uri, 'qp://asset/plant-img-1');
      expect(attachments[0].isImage, true);

      // Document (PDF)
      expect(attachments[1].kind, EditorialAttachmentKind.pdf);
      expect(attachments[1].uri, 'qp://document/guide-doc-2');
      expect(attachments[1].title, 'Ultimate guide to');
      expect(attachments[1].label, 'PDF');
      expect(attachments[1].isPdf, true);
    });

    test('extracts PDF file link with clean title and PDF label', () {
      final note = Note(
        id: 'note-pdf',
        title: 'Architecture Spec',
        content: 'Check out the [System Whitepaper](https://example.com/spec.pdf) for details.',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments.length, 1);
      expect(attachments.first.kind, EditorialAttachmentKind.pdf);
      expect(attachments.first.uri, 'https://example.com/spec.pdf');
      expect(attachments.first.title, 'System Whitepaper');
      expect(attachments.first.label, 'PDF');
    });

    test('extracts code/text file asset with proper label', () {
      final note = Note(
        id: 'note-code',
        title: 'Script',
        content: 'Here is the helper script: [deploy.sh](qp://asset/sh-script-99)',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments.length, 1);
      expect(attachments.first.kind, EditorialAttachmentKind.textFile);
      expect(attachments.first.uri, 'qp://asset/sh-script-99');
      expect(attachments.first.label, 'SH');
    });

    test('returns empty list for password protected notes', () {
      final note = Note(
        id: 'note-secret',
        title: 'Secret',
        content: '<!-- quiet-paper-encrypted-note-v1: secret_payload_here -->',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments, isEmpty);
    });

    test('returns empty list for encrypted note envelope v1', () {
      final note = Note(
        id: 'note-encrypted',
        title: '',
        content: '<!-- quiet-paper-encrypted-note-v1: ciphertext data here -->',
        createdAt: now,
        updatedAt: now,
      );

      final attachments = EditorialAttachmentExtractor.extract(note);
      expect(attachments, isEmpty);
    });

    test('LRU caching and cache invalidation', () {
      final note = Note(
        id: 'note-cache',
        title: 'Cache Note',
        content: '![Img](qp://asset/img-1)',
        createdAt: now,
        updatedAt: now,
      );

      expect(EditorialAttachmentExtractor.cacheSize, 0);
      final res1 = EditorialAttachmentExtractor.extract(note);
      expect(EditorialAttachmentExtractor.cacheSize, 1);

      final res2 = EditorialAttachmentExtractor.extract(note);
      expect(identical(res1, res2), true);

      EditorialAttachmentExtractor.invalidate(note.id);
      expect(EditorialAttachmentExtractor.cacheSize, 0);
    });
  });
}
