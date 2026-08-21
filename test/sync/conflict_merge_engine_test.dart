import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/sync/conflict/markdown_merge_engine.dart';
import 'package:quitepaper/core/sync/conflict/merge_result.dart';
import 'package:quitepaper/core/sync/conflict/metadata_merge_engine.dart';

void main() {
  group('MetadataMergeEngine Tests', () {
    const engine = MetadataMergeEngine();

    test('Title merge: remote wins when local is unchanged', () {
      final res = engine.mergeTitle(
        base: 'Meeting Notes',
        local: 'Meeting Notes',
        remote: 'Team Sync Notes',
      );
      expect(res.isClean, isTrue);
      expect(res.mergedValue, 'Team Sync Notes');
    });

    test('Title merge: local wins when remote is unchanged', () {
      final res = engine.mergeTitle(
        base: 'Meeting Notes',
        local: 'Project Meeting Notes',
        remote: 'Meeting Notes',
      );
      expect(res.isClean, isTrue);
      expect(res.mergedValue, 'Project Meeting Notes');
    });

    test('Title merge: identical change merges cleanly', () {
      final res = engine.mergeTitle(
        base: 'Old Title',
        local: 'New Title',
        remote: 'New Title',
      );
      expect(res.isClean, isTrue);
      expect(res.mergedValue, 'New Title');
    });

    test('Title merge: conflicting changes flag manual conflict', () {
      final res = engine.mergeTitle(
        base: 'Old Title',
        local: 'Local Title Edit',
        remote: 'Remote Title Edit',
      );
      expect(res.isClean, isFalse);
      expect(res.conflictType, ConflictType.title);
      expect(res.requiresManual, isTrue);
    });

    test('Tags merge: combines independent additions from both devices', () {
      final res = engine.mergeTags(
        base: ['work', 'project'],
        local: ['work', 'project', 'urgent'],
        remote: ['work', 'project', 'q3'],
      );
      expect(res.isClean, isTrue);
      expect(res.mergedValue, ['project', 'q3', 'urgent', 'work']);
    });

    test('Tags merge: preserves independent removals relative to base', () {
      final res = engine.mergeTags(
        base: ['work', 'project', 'draft'],
        local: ['work', 'project'], // Removed 'draft'
        remote: ['work', 'project', 'draft', 'finance'], // Added 'finance'
      );
      expect(res.isClean, isTrue);
      expect(res.mergedValue, ['finance', 'project', 'work']);
      expect(res.mergedValue.contains('draft'), isFalse);
    });

    test('Lifecycle merge: flags delete-vs-edit conflict when one device deletes and other edits', () {
      final localEdited = engine.mergeDeleteVsEdit(
        baseDeleted: false,
        localDeleted: false,
        remoteDeleted: true,
        localHasEdits: true,
        remoteHasEdits: false,
      );
      expect(localEdited.isClean, isFalse);
      expect(localEdited.conflictType, ConflictType.deleteVsEdit);

      final remoteEdited = engine.mergeDeleteVsEdit(
        baseDeleted: false,
        localDeleted: true,
        remoteDeleted: false,
        localHasEdits: false,
        remoteHasEdits: true,
      );
      expect(remoteEdited.isClean, isFalse);
      expect(remoteEdited.conflictType, ConflictType.deleteVsEdit);
    });

    test('Lifecycle merge: cleanly deletes when both delete or when non-editing side is deleted', () {
      final bothDeleted = engine.mergeDeleteVsEdit(
        baseDeleted: false,
        localDeleted: true,
        remoteDeleted: true,
        localHasEdits: false,
        remoteHasEdits: false,
      );
      expect(bothDeleted.isClean, isTrue);
      expect(bothDeleted.mergedValue, isTrue);

      final uneditedDeleted = engine.mergeDeleteVsEdit(
        baseDeleted: false,
        localDeleted: false,
        remoteDeleted: true,
        localHasEdits: false,
        remoteHasEdits: false,
      );
      expect(uneditedDeleted.isClean, isTrue);
      expect(uneditedDeleted.mergedValue, isTrue);
    });
  });

  group('MarkdownMergeEngine Tests', () {
    const engine = MarkdownMergeEngine();

    test('Clean merge: independent paragraph additions at top and bottom', () {
      const base = 'Middle Section\nContent here.';
      const local = '# Top Header\n\nMiddle Section\nContent here.';
      const remote = 'Middle Section\nContent here.\n\n## Footer Note';

      final res = engine.merge(base: base, local: local, remote: remote);
      expect(res.isClean, isTrue);
      expect(res.mergedValue, '# Top Header\n\nMiddle Section\nContent here.\n\n## Footer Note');
    });

    test('Clean merge: independent edits in disjoint sections', () {
      const base = 'Section 1\nAlpha\n\nSection 2\nBeta\n\nSection 3\nGamma';
      const local = 'Section 1\nAlpha Edited\n\nSection 2\nBeta\n\nSection 3\nGamma';
      const remote = 'Section 1\nAlpha\n\nSection 2\nBeta\n\nSection 3\nGamma Updated';

      final res = engine.merge(base: base, local: local, remote: remote);
      expect(res.isClean, isTrue);
      expect(
        res.mergedValue,
        'Section 1\nAlpha Edited\n\nSection 2\nBeta\n\nSection 3\nGamma Updated',
      );
    });

    test('Clean merge: checklist state toggles on different items', () {
      const base = '- [ ] Buy groceries\n- [ ] Pay rent\n- [ ] Clean desk';
      const local = '- [x] Buy groceries\n- [ ] Pay rent\n- [ ] Clean desk';
      const remote = '- [ ] Buy groceries\n- [ ] Pay rent\n- [x] Clean desk';

      final res = engine.merge(base: base, local: local, remote: remote);
      expect(res.isClean, isTrue);
      expect(res.mergedValue, '- [x] Buy groceries\n- [ ] Pay rent\n- [x] Clean desk');
    });

    test('Preserves markdown code fences and internal references', () {
      const base = '```typescript\nconst x = 1;\n```\n![Doc](qp://asset/11111111-1111-1111-1111-111111111111)';
      const local = '```typescript\nconst x = 1;\nconst y = 2;\n```\n![Doc](qp://asset/11111111-1111-1111-1111-111111111111)';
      const remote = '```typescript\nconst x = 1;\n```\n![Doc](qp://asset/11111111-1111-1111-1111-111111111111)\n[Doc Scan](qp://document/22222222-2222-2222-2222-222222222222)';

      final res = engine.merge(base: base, local: local, remote: remote);
      expect(res.isClean, isTrue);
      expect(res.mergedValue.contains('const y = 2;'), isTrue);
      expect(res.mergedValue.contains('qp://asset/11111111-1111-1111-1111-111111111111'), isTrue);
      expect(res.mergedValue.contains('qp://document/22222222-2222-2222-2222-222222222222'), isTrue);
    });

    test('Detects overlapping conflicts and creates focused ConflictRegion', () {
      const base = 'Quarterly Strategy\nTarget: 100 users';
      const local = 'Quarterly Strategy\nTarget: 500 enterprise users';
      const remote = 'Quarterly Strategy\nTarget: 1000 active users';

      final res = engine.merge(base: base, local: local, remote: remote);
      expect(res.isClean, isFalse);
      expect(res.conflictType, ConflictType.content);
      expect(res.conflictRegions.length, 1);

      final region = res.conflictRegions.first;
      expect(region.baseText.contains('Target: 100 users'), isTrue);
      expect(region.localText.contains('Target: 500 enterprise users'), isTrue);
      expect(region.remoteText.contains('Target: 1000 active users'), isTrue);
    });
  });
}
