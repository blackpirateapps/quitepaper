import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';
import 'package:quitepaper/features/tags/domain/tag_tree.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Tag tag(
    String name, {
    String? id,
    bool isPinned = false,
    int pinnedOrder = 0,
    int noteCount = 0,
    bool isImplicit = false,
    String? icon,
    String? color,
  }) {
    return Tag(
      id: id ?? TagParser.deterministicTagId(name),
      name: name,
      icon: icon,
      color: color,
      isPinned: isPinned,
      pinnedOrder: pinnedOrder,
      createdAt: now,
      updatedAt: now,
      noteCount: noteCount,
      isImplicit: isImplicit,
    );
  }

  group('TagTree.build', () {
    test('derives parent/child relationships from full paths', () {
      final tree = TagTree.build([
        tag('work'),
        tag('work/projects'),
        tag('work/projects/alpha'),
        tag('work/ideas'),
        tag('personal'),
      ]);

      expect(
        tree.roots.map((node) => node.tag.name),
        equals(['personal', 'work']),
      );
      final work = tree.nodeFor('work')!;
      expect(work.hasChildren, isTrue);
      expect(
        work.children.map((node) => node.tag.name),
        equals(['work/ideas', 'work/projects']),
      );
      final projects = tree.nodeFor('work/projects')!;
      expect(projects.children.single.tag.name, equals('work/projects/alpha'));
      expect(projects.displayName, equals('projects'));
      expect(projects.displayPath, equals('#work/projects'));
    });

    test('synthesizes missing ancestors as implicit presentation nodes', () {
      final child = tag(
        'work/projects/alpha',
        id: 'explicit-child',
        icon: 'code',
        noteCount: 4,
      );
      final tree = TagTree.build([child]);

      final root = tree.nodeFor('work');
      final projects = tree.nodeFor('work/projects');
      final alpha = tree.nodeFor('work/projects/alpha');

      expect(root, isNotNull);
      expect(root!.isImplicit, isTrue);
      expect(root.tag.id, equals(TagParser.deterministicTagId('work')));
      expect(projects, isNotNull);
      expect(projects!.isImplicit, isTrue);
      expect(alpha, isNotNull);
      expect(alpha!.isImplicit, isFalse);
      expect(alpha.tag.id, equals('explicit-child'));
      expect(alpha.tag.icon, equals('code'));

      expect(root.children.single, same(projects));
      expect(projects.children.single, same(alpha));
    });

    test(
      'keeps explicit ancestors with their metadata instead of synthesizing',
      () {
        final explicit = tag(
          'work',
          id: 'explicit-work',
          isPinned: true,
          pinnedOrder: 2,
          icon: 'briefcase',
          color: 'blue',
        );
        final tree = TagTree.build([explicit, tag('work/projects')]);

        final work = tree.nodeFor('work')!;
        expect(work.isImplicit, isFalse);
        expect(work.tag.id, equals('explicit-work'));
        expect(work.tag.icon, equals('briefcase'));
        expect(work.tag.color, equals('blue'));
      },
    );

    test('does not treat textual prefixes as hierarchy', () {
      final tree = TagTree.build([
        tag('work'),
        tag('workflow'),
        tag('workflow/automation'),
      ]);

      final work = tree.nodeFor('work')!;
      expect(work.children, isEmpty);
      expect(tree.roots.map((node) => node.tag.name), contains('workflow'));
    });

    test('keeps malformed legacy tag names as top-level rows', () {
      final tree = TagTree.build([
        tag('work/projects'),
        tag('legacy//broken'),
        tag('123//broken'),
      ]);

      expect(
        tree.roots.map((node) => node.tag.name),
        contains('legacy//broken'),
      );
      expect(tree.roots.map((node) => node.tag.name), contains('123//broken'));
      final malformed = tree.roots.firstWhere(
        (node) => node.tag.name == 'legacy//broken',
      );
      expect(malformed.path, isNull);
      expect(malformed.displayName, equals('legacy//broken'));
      expect(malformed.displayPath, equals('#legacy//broken'));
    });

    test('nests tags with numeric segments under their parent', () {
      final tree = TagTree.build([
        tag('journal/2026'),
      ]);

      expect(tree.roots.map((node) => node.tag.name), contains('journal'));
      final journal = tree.roots.firstWhere((node) => node.tag.name == 'journal');
      expect(journal.children.map((child) => child.tag.name), contains('journal/2026'));
      expect(journal.children.first.displayName, equals('2026'));
    });

    test('orders pinned siblings first and respects pinned order', () {
      final tree = TagTree.build([
        tag('zeta', isPinned: true, pinnedOrder: 2),
        tag('alpha', isPinned: true, pinnedOrder: 1),
        tag('beta'),
      ]);

      expect(
        tree.roots.map((node) => node.tag.name),
        equals(['alpha', 'zeta', 'beta']),
      );
    });

    test('supports custom sibling comparators recursively', () {
      final tree = TagTree.build([
        tag('work', noteCount: 1),
        tag('work/alpha', noteCount: 10),
        tag('work/beta', noteCount: 5),
      ], compare: (a, b) => b.noteCount.compareTo(a.noteCount));

      final work = tree.nodeFor('work')!;
      expect(
        work.children.map((node) => node.tag.name),
        equals(['work/alpha', 'work/beta']),
      );
    });

    test('looks up paths with normalization and ignores unknown paths', () {
      final tree = TagTree.build([tag('work/projects')]);

      expect(tree.nodeFor('#Work/Projects')?.tag.name, equals('work/projects'));
      expect(tree.nodeFor('missing'), isNull);
    });

    test('propagates subtree note counts to synthesized and parent tags', () {
      final child1 = tag('work/projects', noteCount: 10);
      final child2 = tag('work/ideas', noteCount: 5);
      final tree = TagTree.build([child1, child2]);

      final work = tree.nodeFor('work')!;
      expect(work.isImplicit, isTrue);
      expect(work.tag.noteCount, equals(15));
      expect(work.totalNoteCount, equals(15));
    });

    test('TagTree.compareByUsage orders pinned first, then by note count descending', () {
      final tree = TagTree.build([
        tag('c_misc', noteCount: 1),
        tag('b_pinned', noteCount: 2, isPinned: true, pinnedOrder: 1),
        tag('work', noteCount: 20),
        tag('a_notes', noteCount: 5),
      ], compare: TagTree.compareByUsage);

      expect(
        tree.roots.map((n) => n.tag.name),
        equals(['b_pinned', 'work', 'a_notes', 'c_misc']),
      );
    });
  });

  group('TagTree.flatten', () {
    final tree = TagTree.build([
      tag('work'),
      tag('work/projects'),
      tag('work/projects/alpha'),
      tag('work/ideas'),
      tag('personal'),
    ]);

    test('shows roots and only expanded children', () {
      final collapsed = TagTree.flatten(tree, expandedPaths: {});
      expect(
        collapsed.map((entry) => entry.node.tag.name),
        equals(['personal', 'work']),
      );

      final workExpanded = TagTree.flatten(tree, expandedPaths: {'work'});
      expect(
        workExpanded.map((entry) => entry.node.tag.name),
        equals(['personal', 'work', 'work/ideas', 'work/projects']),
      );
      expect(workExpanded.last.depth, equals(1));

      final allExpanded = TagTree.flatten(
        tree,
        expandedPaths: {'work', 'work/projects'},
      );
      expect(
        allExpanded.map((entry) => entry.node.tag.name),
        equals([
          'personal',
          'work',
          'work/ideas',
          'work/projects',
          'work/projects/alpha',
        ]),
      );
      expect(allExpanded.last.depth, equals(2));
    });

    test('expanding a leaf or unknown path does not add rows', () {
      final flattened = TagTree.flatten(
        tree,
        expandedPaths: {'personal', 'work/projects/alpha', 'missing'},
      );

      expect(
        flattened.map((entry) => entry.node.tag.name),
        equals(['personal', 'work']),
      );
    });

    test(
      'allNodes returns deterministic tree order regardless of expansion',
      () {
        expect(
          TagTree.allNodes(tree).map((node) => node.tag.name),
          equals([
            'personal',
            'work',
            'work/ideas',
            'work/projects',
            'work/projects/alpha',
          ]),
        );
      },
    );
  });

  group('TagTree performance', () {
    test('builds a large hierarchy without quadratic path parsing', () {
      final tags = <Tag>[];
      for (var i = 0; i < 200; i++) {
        for (var j = 0; j < 10; j++) {
          tags.add(tag('root-$i/child-$j/leaf'));
        }
      }

      final stopwatch = Stopwatch()..start();
      final tree = TagTree.build(tags);
      final flattened = TagTree.flatten(
        tree,
        expandedPaths: tree.nodesByPath.keys.toSet(),
      );
      stopwatch.stop();

      expect(tree.roots.length, equals(200));
      // 200 roots + 2000 children + 2000 leaves.
      expect(flattened.length, equals(4200));
      // Generous bound: this mainly guards against accidental exponential
      // recomputation, not absolute machine speed.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });
}
