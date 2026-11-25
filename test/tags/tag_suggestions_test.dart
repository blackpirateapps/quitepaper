import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/application/tag_suggestions.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Tag sampleTag(
  String name, {
  int count = 0,
  bool pinned = false,
  int order = 0,
}) => Tag(
  id: name,
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  noteCount: count,
  isPinned: pinned,
  pinnedOrder: order,
);

void main() {
  final service = TagSuggestionService(useNative: false);
  final tags = [
    sampleTag('popular', count: 90),
    sampleTag('recent', count: 1),
    sampleTag('pinned', pinned: true),
    sampleTag('unused'),
    sampleTag('work/project'),
    sampleTag('work/project/deep', pinned: true, count: 50),
    sampleTag('home/project'),
    sampleTag('বাংলা/নোট'),
  ];
  Future<List<String>> search({
    String query = '',
    TagSuggestionSort sort = TagSuggestionSort.suggested,
    Set<String> excluded = const {},
    int limit = 40,
  }) => service.search(
    tags: tags,
    query: query,
    recent: ['recent'],
    excluded: excluded,
    sort: sort,
    limit: limit,
  );

  test(
    'suggested combines pins, actual recency and usage deterministically',
    () async {
      expect((await search()).take(4), [
        'work/project/deep',
        'pinned',
        'recent',
        'popular',
      ]);
      expect(await search(sort: TagSuggestionSort.recent), ['recent']);
      expect(await search(sort: TagSuggestionSort.mostUsed), [
        'popular',
        'work/project/deep',
        'recent',
      ]);
      expect(await search(sort: TagSuggestionSort.pinned), [
        'pinned',
        'work/project/deep',
      ]);
    },
  );

  test(
    'nested queries prefer direct children and stay inside their parent',
    () async {
      expect(await search(query: '#Work/'), [
        'work/project',
        'work/project/deep',
      ]);
      expect(await search(query: 'work/proj'), [
        'work/project',
        'work/project/deep',
      ]);
      expect(await search(query: 'proj'), [
        'home/project',
        'work/project',
        'work/project/deep',
      ]);
      expect(await search(query: 'বাংলা/'), ['বাংলা/নোট']);
      expect(await search(query: 'work//'), isEmpty);
    },
  );

  test(
    'excludes current selections, bounds results and handles unknown text',
    () async {
      expect(await search(query: 'work/', excluded: {'work/project'}), [
        'work/project/deep',
      ]);
      expect(await search(query: 'unknown'), isEmpty);
      expect(await search(query: '???'), isEmpty);
      expect(await search(limit: 0), isEmpty);
      expect(await search(limit: 1), ['work/project/deep']);
    },
  );

  test('pinned sort honors manual pinned order', () async {
    expect(
      await service.search(
        tags: [
          sampleTag('a', pinned: true, order: 2),
          sampleTag('b', pinned: true, order: 1),
        ],
        query: '',
        recent: [],
        excluded: {},
      ),
      ['b', 'a'],
    );
  });

  test(
    'recency persists actual additions and never treats metadata updates as use',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final history = RecentTagNames(prefs);
      await history.record(['#Work/Project', 'ideas', 'work/project', '???']);
      expect(history.state, ['ideas', 'work/project']);
      await history.record(['work/project']);
      expect(RecentTagNames(prefs).state, ['work/project', 'ideas']);
      await history.record(List.generate(70, (i) => 'tag$i'));
      expect(history.state, hasLength(50));
      expect(history.state.first, 'tag69');
      history.dispose();
    },
  );
}
