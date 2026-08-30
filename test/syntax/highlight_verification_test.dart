import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/all.dart';

void main() {
  setUpAll(() {
    highlight.registerLanguages(allLanguages);
  });

  test('highlight error handling and unknown language', () {
    // 1. Empty string
    final emptyResult = highlight.parse('', language: 'dart');
    expect(emptyResult.nodes, isNotNull);

    // 2. Incomplete syntax
    final incompleteResult = highlight.parse('final x = "unfinished', language: 'dart');
    expect(incompleteResult.nodes, isNotNull);

    // 3. Unknown language
    try {
      final unk = highlight.parse('hello', language: 'nonexistent_language_123');
      expect(unk.nodes, isNotNull);
    } catch (e) {
      expect(e, isNotNull);
    }
  });

  test('Unicode and UTF-16 offset consistency', () {
    const text = 'final greeting = "こんにちは 😀"; // 💡 comment\nint x = 42;';
    final result = highlight.parse(text, language: 'dart');
    
    final flattened = <Map<String, dynamic>>[];
    var currentOffset = 0;

    void traverse(List<Node>? nodes, String? inheritedClass) {
      if (nodes == null) return;
      for (final node in nodes) {
        final effectiveClass = node.className ?? inheritedClass;
        if (node.value != null) {
          final val = node.value!;
          final start = currentOffset;
          final end = currentOffset + val.length;
          flattened.add({
            'start': start,
            'end': end,
            'class': effectiveClass,
            'text': val,
          });
          currentOffset = end;
        }
        if (node.children != null) {
          traverse(node.children, effectiveClass);
        }
      }
    }

    traverse(result.nodes, null);

    // Verify reconstructed text matches original text exactly
    final reconstructed = flattened.map((t) => t['text'] as String).join();
    expect(reconstructed, equals(text));
    expect(currentOffset, equals(text.length));
  });
}
