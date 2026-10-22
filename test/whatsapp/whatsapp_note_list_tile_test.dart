import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';

void main() {
  group('WhatsApp NoteListTile Badge Tests', () {
    const sampleChat = '''
[21/10, 11:04 pm] Sam 3: Yeshh
[21/10, 11:04 pm] Sam 3: That's so sexyyy
''';

    test('NoteMetadataExtractor flags hasWhatsAppFormattingAvailable for chat notes', () {
      final now = DateTime.now();
      final chatNote = Note(
        id: 'chat-1',
        title: 'WhatsApp chat',
        content: sampleChat,
        createdAt: now,
        updatedAt: now,
      );

      final metadata = NoteMetadataExtractor.extract(chatNote);
      expect(metadata.hasWhatsAppFormattingAvailable, isTrue);

      final regularNote = Note(
        id: 'regular-1',
        title: 'Normal Note',
        content: 'This is just a regular note without timestamps.',
        createdAt: now,
        updatedAt: now,
      );

      final regularMetadata = NoteMetadataExtractor.extract(regularNote);
      expect(regularMetadata.hasWhatsAppFormattingAvailable, isFalse);
    });

    testWidgets('NoteListTile renders Formatting available badge for WhatsApp chat notes (Mockup 0)', (tester) async {
      final now = DateTime.now();
      final chatNote = Note(
        id: 'chat-2',
        title: 'WhatsApp chat',
        content: sampleChat,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteListTile(
              note: chatNote,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Formatting available'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('NoteListTile does not render Formatting available badge for regular notes', (tester) async {
      final now = DateTime.now();
      final regularNote = Note(
        id: 'regular-2',
        title: 'Normal Note',
        content: 'Just regular plain text note.',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteListTile(
              note: regularNote,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Formatting available'), findsNothing);
    });
  });
}
