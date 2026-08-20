import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';

void main() {
  group('QuietPaperUri Tests', () {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    test('Parses valid qp://asset/<UUID> URI correctly', () {
      final uri = QuietPaperUri.parse('qp://asset/$validUuid');
      expect(uri.resourceType, QuietPaperResourceType.asset);
      expect(uri.isAsset, isTrue);
      expect(uri.isNote, isFalse);
      expect(uri.resourceId, validUuid);
      expect(uri.toUriString(), 'qp://asset/$validUuid');
    });

    test('Parses valid qp://document/<UUID> URI correctly', () {
      final uri = QuietPaperUri.parse('qp://document/$validUuid');
      expect(uri.resourceType, QuietPaperResourceType.document);
      expect(uri.isDocument, isTrue);
      expect(uri.isAsset, isFalse);
      expect(uri.isNote, isFalse);
      expect(uri.resourceId, validUuid);
      expect(uri.toUriString(), 'qp://document/$validUuid');
    });

    test('Parses valid qp://note/<UUID> URI correctly', () {
      final uri = QuietPaperUri.parse('qp://note/$validUuid');
      expect(uri.resourceType, QuietPaperResourceType.note);
      expect(uri.isNote, isTrue);
      expect(uri.isDocument, isFalse);
      expect(uri.isAsset, isFalse);
      expect(uri.resourceId, validUuid);
      expect(uri.toUriString(), 'qp://note/$validUuid');
    });

    test('Parses URI with query parameters', () {
      final uri = QuietPaperUri.parse('qp://asset/$validUuid?variant=preview&w=400');
      expect(uri.resourceType, QuietPaperResourceType.asset);
      expect(uri.resourceId, validUuid);
      expect(uri.parameters['variant'], 'preview');
      expect(uri.parameters['w'], '400');
      expect(uri.toUriString(), contains('variant=preview'));
      expect(uri.toUriString(), contains('w=400'));
    });

    test('tryParse returns null for invalid formats', () {
      expect(QuietPaperUri.tryParse(''), isNull);
      expect(QuietPaperUri.tryParse('http://example.com'), isNull);
      expect(QuietPaperUri.tryParse('qp://unknown/$validUuid'), isNull);
      expect(QuietPaperUri.tryParse('qp://asset/not-a-uuid'), isNull);
      expect(QuietPaperUri.tryParse('qp://document/not-a-uuid'), isNull);
      expect(QuietPaperUri.tryParse('qp://asset/'), isNull);
      expect(QuietPaperUri.tryParse('qp://document/'), isNull);
    });

    test('isValidUri static method accurately verifies string URIs', () {
      expect(QuietPaperUri.isValidUri('qp://asset/$validUuid'), isTrue);
      expect(QuietPaperUri.isValidUri('qp://document/$validUuid'), isTrue);
      expect(QuietPaperUri.isValidUri('qp://note/$validUuid'), isTrue);
      expect(QuietPaperUri.isValidUri('https://res.cloudinary.com/demo.png'), isFalse);
      expect(QuietPaperUri.isValidUri('invalid'), isFalse);
    });

    test('Factory constructors produce valid URIs', () {
      final assetUri = QuietPaperUri.asset(validUuid);
      expect(assetUri.toUriString(), 'qp://asset/$validUuid');

      final documentUri = QuietPaperUri.document(validUuid);
      expect(documentUri.toUriString(), 'qp://document/$validUuid');

      final noteUri = QuietPaperUri.note(validUuid);
      expect(noteUri.toUriString(), 'qp://note/$validUuid');
    });
  });
}
