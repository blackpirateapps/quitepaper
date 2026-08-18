import 'package:uuid/uuid.dart';
import '../data/notes_repository.dart';
import '../domain/note_model.dart';

abstract final class SampleNotes {
  static Future<void> populateSampleNotes(NotesRepository repository) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final sampleData = [
      Note(
        id: uuid.v4(),
        title: 'A quiet place to think',
        content: '''# Welcome to Quiet Paper

Quiet Paper is designed around a simple philosophy: **writing should feel calm, frictionless, and distraction-free**.

> Sometimes the best notes app is the one that lets you forget you are using an app.

### What makes it special:
- **Markdown-first**: Express formatting with `#`, `*`, `_`, and lists.
- **Fast tagging**: Just type `#ideas` or `#writing` anywhere in your text.
- **Instant offline storage**: Your notes stay on your device.
- **Warm aesthetics**: Gentle tones designed for long-form comfort.

Feel free to edit this note or create a new one using the **＋** button.''',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
        tags: const ['welcome', 'ideas', 'writing'],
      ),
      Note(
        id: uuid.v4(),
        title: 'Ideas for the new app',
        content: '''Exploring concepts for upcoming features:

1. **Tag hierarchy**: Support for nested tags like `#work/project` and `#personal/goals`.
2. **Keyboard shortcuts**: Quick markdown toggles for external Bluetooth keyboards.
3. **Word count goals**: Minimal word count target indicators for daily journaling.

#ideas #flutter #design''',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
        isPinned: false,
        tags: const ['ideas', 'flutter', 'design'],
      ),
      Note(
        id: uuid.v4(),
        title: 'Books I want to read',
        content: '''## Summer Reading List

- [ ] *The Design of Everyday Things* — Don Norman
- [ ] *Thinking, Fast and Slow* — Daniel Kahneman
- [ ] *Clean Architecture* — Robert C. Martin
- [ ] *The Elements of Typographic Style* — Robert Bringhurst

Tagging this for weekend visits to the library.
#books #reading''',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
        isPinned: false,
        tags: const ['books', 'reading'],
      ),
      Note(
        id: uuid.v4(),
        title: 'Morning thoughts',
        content: '''A few reflections from a quiet morning walk:

The morning light through the trees was remarkable today. 
Writing things down first thing in the morning clears cognitive space for the deeper work ahead.

- Focus on one meaningful task at a time
- Embrace subtraction over addition in software design
- Keep interfaces quiet

#journal #morning #thoughts''',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
        isPinned: false,
        tags: const ['journal', 'morning', 'thoughts'],
      ),
      Note(
        id: uuid.v4(),
        title: 'Markdown Cheat Sheet',
        content: '''# Heading 1
## Heading 2
### Heading 3

**Bold text**, *italic text*, and ~~strikethrough~~.

### Lists
- Bullet item one
- Bullet item two
  - Sub-item

### Code
Inline code: `final note = Note();`

```dart
void main() {
  runApp(const QuietPaperApp());
}
```

#markdown #guide #reference''',
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 8)),
        isPinned: false,
        tags: const ['markdown', 'guide', 'reference'],
      ),
    ];

    for (final note in sampleData) {
      await repository.saveNote(note);
    }
  }
}
