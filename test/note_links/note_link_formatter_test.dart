import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_formatter.dart';

void main() {
  group('MarkdownFormatter.insertNoteLink', () {
    const noteId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('replaces autocomplete trigger span with canonical note link', () {
      const text = 'Review [[Fourier before exam';
      // Trigger start = 7, queryEnd = 16 ("[[Fourier")
      const value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 16),
      );

      final updated = MarkdownFormatter.insertNoteLink(
        value: value,
        noteId: noteId,
        targetTitle: 'Fourier Series',
        replaceStart: 7,
        replaceEnd: 16,
      );

      expect(
        updated.text,
        'Review [Fourier Series](qp://note/$noteId) before exam',
      );
      expect(
        updated.selection.baseOffset,
        7 + '[Fourier Series](qp://note/$noteId)'.length,
      );
      expect(updated.selection.isCollapsed, true);
    });

    test('wraps active selection as display text', () {
      const text = 'We need to analyze harmonic frequencies next.';
      // Select "harmonic frequencies" (offsets 19 to 39)
      const value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 19, extentOffset: 39),
      );

      final updated = MarkdownFormatter.insertNoteLink(
        value: value,
        noteId: noteId,
        targetTitle: 'Fourier Series',
      );

      expect(
        updated.text,
        'We need to analyze [harmonic frequencies](qp://note/$noteId) next.',
      );
      expect(
        updated.selection.baseOffset,
        19 + '[harmonic frequencies](qp://note/$noteId)'.length,
      );
    });

    test('inserts at cursor when no selection exists', () {
      const text = 'See also: ';
      const value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 10),
      );

      final updated = MarkdownFormatter.insertNoteLink(
        value: value,
        noteId: noteId,
        targetTitle: 'Fourier Series',
      );

      expect(
        updated.text,
        'See also: [Fourier Series](qp://note/$noteId)',
      );
    });
  });
}
