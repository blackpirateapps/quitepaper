import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/whatsapp_formatter/application/whatsapp_markdown_formatter.dart';
import 'package:quitepaper/features/whatsapp_formatter/application/whatsapp_parser.dart';
import 'package:quitepaper/features/whatsapp_formatter/domain/whatsapp_format_options.dart';

void main() {
  group('WhatsAppMarkdownFormatter', () {
    const userSample = '''
[21/10, 11:04\u202Fpm] Sam 3: Yeshh
[21/10, 11:04\u202Fpm] Sam 3: That's so sexyyy
[21/10, 11:04\u202Fpm] Sam 3: 😭😭😭😭 you're using her voice note
[21/10, 11:14\u202Fpm] BlackPirate: Shes goat
[21/10, 11:14\u202Fpm] BlackPirate: Yessh
''';

    test('generates expected structure with date headings and sender grouping', () {
      final parsed = WhatsAppParser.parse(userSample);
      final md = WhatsAppMarkdownFormatter.format(parsed);

      expect(md, contains('### 21/10'));
      expect(md, contains('**Sam 3**'));
      expect(md, contains('_11:04 pm_ · Yeshh'));
      expect(md, contains('_11:04 pm_ · That\'s so sexyyy'));
      expect(md, contains('**BlackPirate**'));
      expect(md, contains('_11:14 pm_ · Shes goat'));
    });

    test('respects showSenderNames option', () {
      final parsed = WhatsAppParser.parse(userSample);
      final md = WhatsAppMarkdownFormatter.format(
        parsed,
        options: const WhatsAppFormatOptions(showSenderNames: false),
      );

      expect(md, isNot(contains('**Sam 3**')));
      expect(md, isNot(contains('**BlackPirate**')));
      expect(md, contains('_11:04 pm_ · Yeshh'));
    });

    test('respects preserveTimestamps option', () {
      final parsed = WhatsAppParser.parse(userSample);
      final md = WhatsAppMarkdownFormatter.format(
        parsed,
        options: const WhatsAppFormatOptions(preserveTimestamps: false),
      );

      expect(md, isNot(contains('_11:04 pm_ · ')));
      expect(md, contains('Yeshh'));
      expect(md, contains('That\'s so sexyyy'));
    });

    test('respects groupConsecutiveMessages = false', () {
      final parsed = WhatsAppParser.parse(userSample);
      final md = WhatsAppMarkdownFormatter.format(
        parsed,
        options: const WhatsAppFormatOptions(groupConsecutiveMessages: false),
      );

      // When consecutive messages are not grouped, Sam 3 appears for each message
      final samCount = RegExp(r'\*\*Sam 3\*\*').allMatches(md).length;
      expect(samCount, equals(3));
    });

    test('escapes Markdown characters in message bodies to protect document hierarchy', () {
      const markdownLookingChat = '''
[21/10, 11:04 pm] Sam: # Important Announcement
[21/10, 11:05 pm] Sam: - [ ] Checklist item
[21/10, 11:06 pm] Sam: - Unordered item
[21/10, 11:07 pm] Sam: 1. Ordered item
[21/10, 11:08 pm] Sam: > Blockquote text
[21/10, 11:09 pm] Sam: ```code fence```
''';
      final parsed = WhatsAppParser.parse(markdownLookingChat);
      final md = WhatsAppMarkdownFormatter.format(parsed);

      expect(md, contains(r'\# Important Announcement'));
      expect(md, contains(r'\- [ ] Checklist item'));
      expect(md, contains(r'\- Unordered item'));
      expect(md, contains(r'1\. Ordered item'));
      expect(md, contains(r'\> Blockquote text'));
      expect(md, contains(r'\```code fence```'));
    });

    test('handles date transitions properly', () {
      const multiDay = '''
[21/10, 11:59 pm] Sam: Good night
[22/10, 06:00 am] Sam: Good morning
''';
      final parsed = WhatsAppParser.parse(multiDay);
      final md = WhatsAppMarkdownFormatter.format(parsed);

      expect(md, contains('### 21/10'));
      expect(md, contains('### 22/10'));
    });

    test('preserves system messages and unrecognized content', () {
      const withSys = '''
Preamble line
[21/10, 11:00 pm] Messages and calls are end-to-end encrypted
[21/10, 11:01 pm] Sam: Hi
''';
      final parsed = WhatsAppParser.parse(withSys);
      final md = WhatsAppMarkdownFormatter.format(parsed);

      expect(md, contains('Preamble line'));
      expect(md, contains('_Messages and calls are end-to-end encrypted_'));
      expect(md, contains('**Sam**'));
    });
  });
}
