import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/application/phosphor_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleJson = jsonEncode([
    {
      'id': 'book-open',
      'name': 'Book Open',
      'pascalName': 'BookOpen',
      'camelName': 'bookOpen',
      'codePoint': 59001,
      'categories': ['education', 'media'],
      'tags': ['read', 'novel', 'literature']
    },
    {
      'id': 'book',
      'name': 'Book',
      'pascalName': 'Book',
      'camelName': 'book',
      'codePoint': 59002,
      'categories': ['education'],
      'tags': ['read', 'study']
    },
    {
      'id': 'bookmark',
      'name': 'Bookmark',
      'pascalName': 'Bookmark',
      'camelName': 'bookmark',
      'codePoint': 59003,
      'categories': ['education'],
      'tags': ['favorite', 'save', 'tag']
    },
    {
      'id': 'camera',
      'name': 'Camera',
      'pascalName': 'Camera',
      'camelName': 'camera',
      'codePoint': 59004,
      'categories': ['media'],
      'tags': ['photo', 'picture', 'shot']
    },
    {
      'id': 'heart',
      'name': 'Heart',
      'pascalName': 'Heart',
      'camelName': 'heart',
      'codePoint': 59005,
      'categories': ['health'],
      'tags': ['like', 'love', 'favorite']
    },
  ]);

  late ByteData sampleByteData;

  setUp(() {
    sampleByteData = ByteData.view(Uint8List.fromList(utf8.encode(sampleJson)).buffer);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      return sampleByteData;
    });
  });

  group('PhosphorCatalogService Tests', () {
    test('getCatalog parses JSON correctly into PhosphorIconDefinition', () async {
      final service = PhosphorCatalogService();
      final catalog = await service.getCatalog();

      expect(catalog.length, 5);
      expect(catalog.first.id, 'book-open');
      expect(catalog.first.name, 'Book Open');
      expect(catalog.first.categories, ['education', 'media']);
      expect(service.isLoaded, isTrue);
    });

    test('search ranks exact match higher than prefix and substring match', () async {
      final service = PhosphorCatalogService();

      // Query "book" should rank "book" exact match (score 1000) first,
      // followed by "book-open" / "bookmark" (prefix score 800)
      final results = await service.search(query: 'book');

      expect(results.length, 3);
      expect(results[0].id, 'book');
      expect(results[1].id, 'bookmark');
      expect(results[2].id, 'book-open');
    });

    test('search finds icons by tag alias keyword', () async {
      final service = PhosphorCatalogService();

      final results = await service.search(query: 'photo');
      expect(results.length, 1);
      expect(results.first.id, 'camera');
    });

    test('search filters by category correctly', () async {
      final service = PhosphorCatalogService();

      final educationIcons = await service.search(query: '', category: 'education');
      expect(educationIcons.length, 3);
      expect(educationIcons.map((i) => i.id).toList(), ['book-open', 'book', 'bookmark']);

      final healthIcons = await service.search(query: '', category: 'health');
      expect(healthIcons.length, 1);
      expect(healthIcons.first.id, 'heart');
    });

    test('search filters by favorites and recents correctly', () async {
      final service = PhosphorCatalogService();

      final favorites = await service.search(
        query: '',
        category: 'favorites',
        favoriteIds: {'heart', 'camera'},
      );
      expect(favorites.length, 2);
      expect(favorites.map((i) => i.id).toSet(), {'heart', 'camera'});

      final recents = await service.search(
        query: '',
        category: 'recent',
        recentIds: ['camera', 'book'],
      );
      expect(recents.length, 2);
      // Preserves MRU order
      expect(recents[0].id, 'camera');
      expect(recents[1].id, 'book');
    });

    test('generation token drops stale search results', () async {
      final service = PhosphorCatalogService();

      // Fire query generation 2
      await service.search(query: 'heart', generation: 2);

      // Now query generation 1 (stale, should return empty)
      final staleResults = await service.search(query: 'camera', generation: 1);
      expect(staleResults, isEmpty);
    });
  });
}
