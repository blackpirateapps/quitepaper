import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/whatsapp_formatter/application/whatsapp_parser.dart';

void main() {
  group('WhatsAppParser', () {
    const userSample = '''
[21/10, 11:04\u202Fpm] Sam 3: Yeshh
[21/10, 11:04\u202Fpm] Sam 3: That's so sexyyy
[21/10, 11:04\u202Fpm] Sam 3: 😭😭😭😭 you're using her voice note
[21/10, 11:14\u202Fpm] BlackPirate: Shes goat
[21/10, 11:14\u202Fpm] BlackPirate: Yessh
[21/10, 11:17\u202Fpm] BlackPirate: im starting to understand why iphone apps take more space than their android counterpart.
[21/10, 11:51\u202Fpm] Sam 3: I agree
[21/10, 11:51\u202Fpm] Sam 3: And what did you understand
[22/10, 5:06\u202Fam] BlackPirate: IPhone apps have attention to detail so they have much more code than usual
[22/10, 5:18\u202Fam] BlackPirate: Lemme do the public site of urs first.
''';

    test('parses exact user supplied sample with narrow non-breaking spaces', () {
      final res = WhatsAppParser.parse(userSample);
      expect(res.isWhatsAppChat, isTrue);
      expect(res.messageCount, equals(10));
      expect(res.participants, equals(['Sam 3', 'BlackPirate']));
      expect(res.dateRangeLabel, equals('OCTOBER 21–22'));
      expect(res.suggestedTitle, equals('Conversation with Sam 3 & BlackPirate'));

      final first = res.messages.first;
      expect(first.date, equals('21/10'));
      expect(first.time, equals('11:04 pm'));
      expect(first.sender, equals('Sam 3'));
      expect(first.body, equals('Yeshh'));

      final last = res.messages.last;
      expect(last.date, equals('22/10'));
      expect(last.time, equals('5:18 am'));
      expect(last.sender, equals('BlackPirate'));
      expect(last.body, equals('Lemme do the public site of urs first.'));
    });

    test('detects WhatsApp chat fast without full parsing', () {
      expect(WhatsAppParser.isWhatsAppChat(userSample), isTrue);
      expect(WhatsAppParser.isWhatsAppChat('Ordinary note with [brackets]'), isFalse);
      expect(WhatsAppParser.isWhatsAppChat('Hello world\nThis is just a note'), isFalse);
      expect(WhatsAppParser.isWhatsAppChat(''), isFalse);
    });

    test('parses 24-hour bracketed and android dash exports', () {
      const androidChat = '''
21/10/2024, 23:14 - Alice: Hey there!
21/10/2024, 23:15 - Bob: Hello!
22/10/2024, 08:30 - Alice: Good morning
''';
      final res = WhatsAppParser.parse(androidChat);
      expect(res.isWhatsAppChat, isTrue);
      expect(res.messageCount, equals(3));
      expect(res.participants, containsAll(['Alice', 'Bob']));
      expect(res.messages[0].time, equals('23:14'));
    });

    test('parses optional year and seconds in timestamps', () {
      const withSeconds = '''
[21/10/24, 11:04:15 PM] Sam 3: First
[21/10/24, 11:04:30 PM] Sam 3: Second
''';
      final res = WhatsAppParser.parse(withSeconds);
      expect(res.isWhatsAppChat, isTrue);
      expect(res.messages.first.time, equals('11:04:15 PM'));
    });

    test('parses multi-line messages and preserves line breaks', () {
      const multiline = '''
[21/10, 11:04 pm] Sam: Line 1
Line 2
Line 3
[21/10, 11:05 pm] Bob: Reply
''';
      final res = WhatsAppParser.parse(multiline);
      expect(res.messages.first.body, equals('Line 1\nLine 2\nLine 3'));
      expect(res.messages.length, equals(2));
    });

    test('preserves colons, URLs, emojis, and punctuation inside message body', () {
      const complexMsg = '''
[21/10, 11:04 pm] Sam 3: Check this: https://example.com/test?q=1:2 🔥
[21/10, 11:05 pm] Sam 3: Special punctuation: -- ... [test] {test} :thumbsup:
''';
      final res = WhatsAppParser.parse(complexMsg);
      expect(res.messages[0].body, equals('Check this: https://example.com/test?q=1:2 🔥'));
      expect(res.messages[1].body, equals('Special punctuation: -- ... [test] {test} :thumbsup:'));
    });

    test('recognizes system messages and media omissions', () {
      const withSystem = '''
[21/10, 11:00 pm] Messages and calls are end-to-end encrypted. No one outside of this chat can read or listen to them.
[21/10, 11:04 pm] Sam 3: Yeshh
[21/10, 11:05 pm] Sam 3: <Media omitted>
''';
      final res = WhatsAppParser.parse(withSystem);
      expect(res.messages[0].isSystemMessage, isTrue);
      expect(res.messages[0].sender, isNull);
      expect(res.messages[1].isSystemMessage, isFalse);
      expect(res.messages[2].body, equals('<Media omitted>'));
    });

    test('preserves unrecognized lines before messages', () {
      const withHeader = '''
Notes from chat export:
Some extra notes here
[21/10, 11:04 pm] Sam: Hello
[21/10, 11:05 pm] Bob: Hi
''';
      final res = WhatsAppParser.parse(withHeader);
      expect(res.hasUnrecognizedLines, isTrue);
      expect(res.unrecognizedLines.length, equals(2));
      expect(res.messages.length, equals(4)); // 2 unrecognized + 2 chat
      expect(res.messages[0].isUnrecognized, isTrue);
      expect(res.messages[0].body, equals('Notes from chat export:'));
    });

    test('handles CRLF line endings cleanly', () {
      const crlfSample = '[21/10, 11:04 pm] Sam: Line 1\r\n[21/10, 11:05 pm] Bob: Line 2\r\n';
      final res = WhatsAppParser.parse(crlfSample);
      expect(res.isWhatsAppChat, isTrue);
      expect(res.messageCount, equals(2));
    });

    test('empty or single message input has low confidence or is not whatsapp chat', () {
      expect(WhatsAppParser.parse('').isWhatsAppChat, isFalse);
      expect(WhatsAppParser.parse('Just one line [21/10, 11:04 pm] Sam: Hello').isWhatsAppChat, isFalse);
    });
  });
}
