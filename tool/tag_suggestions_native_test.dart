import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/application/tag_suggestions.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/watched_import/native/api/tags.dart'
    as native;
import 'package:quitepaper/features/watched_import/native/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Rust bridge matches portable ranking for all picker modes',
    () async {
      final library = Platform.environment['QP_WATCHED_NATIVE_LIBRARY'];
      if (library == null) {
        throw StateError('Set QP_WATCHED_NATIVE_LIBRARY to the built .so');
      }
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(File(library).absolute.path),
      );
      addTearDown(RustLib.dispose);
      final names = [
        'work',
        'work/project',
        'work/project/deep',
        'home/project',
        'journal/2026',
        'বাংলা/নোট',
        'বাংলা/কাজ',
        'apple',
        'pineapple',
        ...List.generate(120, (i) => 'tag$i'),
      ];
      final tags = [
        for (var i = 0; i < names.length; i++)
          Tag(
            id: names[i],
            name: names[i],
            noteCount: i % 9,
            isPinned: i % 5 == 0,
            pinnedOrder: i % 3,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
      ];
      final recent = ['apple', 'work/project/deep', 'tag20', 'work'];
      final inputs = tags
          .map(
            (t) => native.TagSuggestionInput(
              name: t.name,
              noteCount: t.noteCount,
              pinned: t.isPinned,
              pinnedOrder: t.pinnedOrder,
              recentOrder: recent.indexOf(t.name),
            ),
          )
          .toList();
      final portable = TagSuggestionService(useNative: false);
      for (final sort in TagSuggestionSort.values) {
        for (final query in [
          '',
          'work/',
          'work/pro',
          'proj',
          'work//',
          'বাংলা/',
          'apple',
          'tag',
          '???',
        ]) {
          for (final excluded in [
            <String>{},
            {'work/project', 'apple', 'tag20'},
          ]) {
            for (final limit in [0, 1, 40, 150]) {
              final expected = await portable.search(
                tags: tags,
                query: query,
                recent: recent,
                excluded: excluded,
                sort: sort,
                limit: limit,
              );
              final actual = await native.rankTagSuggestions(
                tags: inputs,
                query: query,
                excluded: excluded.toList(),
                order: switch (sort) {
                  TagSuggestionSort.suggested =>
                    native.TagSuggestionOrder.suggested,
                  TagSuggestionSort.recent => native.TagSuggestionOrder.recent,
                  TagSuggestionSort.mostUsed =>
                    native.TagSuggestionOrder.mostUsed,
                  TagSuggestionSort.pinned => native.TagSuggestionOrder.pinned,
                },
                limit: limit,
              );
              expect(
                actual,
                expected,
                reason: '$sort / $query / $excluded / $limit',
              );
            }
          }
        }
      }
    },
  );
}
