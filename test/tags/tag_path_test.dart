import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/domain/tag_path.dart';

void main() {
  group('TagPath.parse', () {
    test('normalizes case, leading hash, and surrounding whitespace', () {
      final path = TagPath.parse('  #Work/Projects/Alpha  ');

      expect(path.value, equals('work/projects/alpha'));
      expect(path.segments, equals(['work', 'projects', 'alpha']));
      expect(path.leaf, equals('alpha'));
      expect(path.depth, equals(3));
      expect(path.isNested, isTrue);
    });

    test('supports Unicode letters and marks per segment', () {
      final path = TagPath.parse('#বাংলা/লেখা');

      expect(path.value, equals('বাংলা/লেখা'));
      expect(path.segments, equals(['বাংলা', 'লেখা']));
      expect(path.leaf, equals('লেখা'));
      expect(path.breadcrumb, equals('#বাংলা / লেখা'));
    });

    test('accepts single-segment tags', () {
      final path = TagPath.parse('work');

      expect(path.value, equals('work'));
      expect(path.segments, equals(['work']));
      expect(path.leaf, equals('work'));
      expect(path.depth, equals(1));
      expect(path.isNested, isFalse);
      expect(path.parent, isNull);
      expect(path.ancestors, isEmpty);
    });

    test('rejects empty, leading, trailing, and doubled separators', () {
      for (final invalid in [
        '',
        '   ',
        '/',
        '/work',
        'work/',
        'work//projects',
      ]) {
        expect(
          () => TagPath.parse(invalid),
          throwsArgumentError,
          reason: 'Expected "$invalid" to be rejected',
        );
        expect(TagPath.tryParse(invalid), isNull, reason: invalid);
        expect(TagPath.isValid(invalid), isFalse, reason: invalid);
      }
    });

    test('rejects segments that violate flat tag rules', () {
      for (final invalid in [
        '123/projects',
        'work/-projects',
        'work/projects-',
        'work/_projects',
        'work/projects_',
        'work/pro jects',
      ]) {
        expect(TagPath.tryParse(invalid), isNull, reason: invalid);
      }
    });

    test('permits numeric child segments in nested tag paths', () {
      final path = TagPath.parse('journal/2026');
      expect(path.segments, equals(['journal', '2026']));
      expect(path.leaf, equals('2026'));
      expect(path.parentValue, equals('journal'));
      expect(path.ancestorValues, equals(['journal']));
      expect(path.token, equals('#journal/2026'));
      expect(path.breadcrumb, equals('#journal / 2026'));
    });

    test('normalizes an already normalized path idempotently', () {
      final first = TagPath.parse('#Work/Projects');
      final second = TagPath.parse(first.value);

      expect(second, equals(first));
      expect(second.hashCode, equals(first.hashCode));
    });
  });

  group('TagPath hierarchy', () {
    final root = TagPath.parse('work');
    final projects = TagPath.parse('work/projects');
    final alpha = TagPath.parse('work/projects/alpha');

    test(
      'exposes parent, ancestors, and ancestor values in top-down order',
      () {
        expect(alpha.parent, equals(projects));
        expect(alpha.parentValue, equals('work/projects'));
        expect(alpha.ancestors, equals([root, projects]));
        expect(alpha.ancestorValues, equals(['work', 'work/projects']));

        expect(projects.parent, equals(root));
        expect(projects.ancestorValues, equals(['work']));
      },
    );

    test('builds child paths and display tokens', () {
      expect(root.child('projects'), equals(projects));
      expect(projects.child('alpha'), equals(alpha));
      expect(alpha.breadcrumb, equals('#work / projects / alpha'));
      expect(alpha.token, equals('#work/projects/alpha'));
      expect(() => root.child('../escape'), throwsArgumentError);
    });

    test('descendant checks are segment-aware', () {
      expect(alpha.isDescendantOf(root), isTrue);
      expect(alpha.isDescendantOf(projects), isTrue);
      expect(alpha.isSelfOrDescendantOf(alpha), isTrue);
      expect(root.isAncestorOf(alpha), isTrue);

      expect(root.isDescendantOf(root), isFalse);
      expect(root.isDescendantOf(alpha), isFalse);
      expect(root.isAncestorOf(root), isFalse);

      // No false matches such as work -> workflow.
      final workflow = TagPath.parse('workflow');
      final workflowAlpha = TagPath.parse('workflow/alpha');
      expect(workflow.isDescendantOf(root), isFalse);
      expect(workflowAlpha.isDescendantOf(root), isFalse);
      expect(root.isAncestorOf(workflowAlpha), isFalse);

      // A shared textual prefix is not enough.
      final workshop = TagPath.parse('work-shop/projects');
      expect(workshop.isDescendantOf(root), isFalse);
    });

    test('compares deterministically by full path', () {
      final paths = [alpha, root, projects]..sort();

      expect(
        paths.map((path) => path.value).toList(),
        equals(['work', 'work/projects', 'work/projects/alpha']),
      );
    });
  });
}
