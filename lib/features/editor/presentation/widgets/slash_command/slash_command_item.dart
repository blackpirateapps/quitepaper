import 'package:flutter/widgets.dart';
import '../../../../tags/domain/phosphor_icons.dart';

enum SlashCommandType {
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  paragraph,
  todo,
  bullet,
  number,
  quote,
  code,
  table,
  divider,
  link,
  noteLink,
  tag,
}

class SlashCommandItem {
  const SlashCommandItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.shortcut,
    this.keywords = const [],
  });

  final SlashCommandType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? shortcut;
  final List<String> keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    for (final kw in keywords) {
      if (kw.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  static const List<SlashCommandItem> all = [
    SlashCommandItem(
      type: SlashCommandType.h1,
      title: 'Heading 1',
      subtitle: 'Large section heading',
      icon: PhosphorIconsRegular.textH,
      shortcut: 'Ctrl+Alt+1',
      keywords: ['h1', 'heading1', 'title', '#'],
    ),
    SlashCommandItem(
      type: SlashCommandType.h2,
      title: 'Heading 2',
      subtitle: 'Medium section heading',
      icon: PhosphorIconsRegular.textH,
      shortcut: 'Ctrl+Alt+2',
      keywords: ['h2', 'heading2', 'subtitle', '##'],
    ),
    SlashCommandItem(
      type: SlashCommandType.h3,
      title: 'Heading 3',
      subtitle: 'Small subsection heading',
      icon: PhosphorIconsRegular.textH,
      shortcut: 'Ctrl+Alt+3',
      keywords: ['h3', 'heading3', '###'],
    ),
    SlashCommandItem(
      type: SlashCommandType.todo,
      title: 'To-do List',
      subtitle: 'Track tasks with interactive checkbox',
      icon: PhosphorIconsRegular.checkSquare,
      shortcut: 'Ctrl+Shift+C',
      keywords: ['todo', 'task', 'check', 'checkbox', '[]'],
    ),
    SlashCommandItem(
      type: SlashCommandType.bullet,
      title: 'Bullet List',
      subtitle: 'Create a simple bulleted list',
      icon: PhosphorIconsRegular.listBullets,
      shortcut: 'Ctrl+Shift+8',
      keywords: ['bullet', 'list', 'unordered', 'ul', '-'],
    ),
    SlashCommandItem(
      type: SlashCommandType.number,
      title: 'Numbered List',
      subtitle: 'Create an ordered sequential list',
      icon: PhosphorIconsRegular.listNumbers,
      shortcut: 'Ctrl+Shift+7',
      keywords: ['numbered', 'order', 'ol', '1.'],
    ),
    SlashCommandItem(
      type: SlashCommandType.quote,
      title: 'Quote',
      subtitle: 'Capture quotes or highlighted context',
      icon: PhosphorIconsRegular.quotes,
      shortcut: 'Ctrl+Shift+.',
      keywords: ['quote', 'blockquote', '>'],
    ),
    SlashCommandItem(
      type: SlashCommandType.code,
      title: 'Code Block',
      subtitle: 'Code snippet with syntax formatting',
      icon: PhosphorIconsRegular.codeBlock,
      shortcut: 'Ctrl+Alt+C',
      keywords: ['code', 'block', 'snippet', '```'],
    ),
    SlashCommandItem(
      type: SlashCommandType.table,
      title: 'Table',
      subtitle: 'Insert a structured grid table',
      icon: PhosphorIconsRegular.table,
      shortcut: 'Ctrl+Alt+T',
      keywords: ['table', 'grid'],
    ),
    SlashCommandItem(
      type: SlashCommandType.divider,
      title: 'Divider',
      subtitle: 'Visually separate content sections',
      icon: PhosphorIconsRegular.minus,
      shortcut: 'Ctrl+Alt+-',
      keywords: ['divider', 'line', 'hr', '---', 'separator'],
    ),
    SlashCommandItem(
      type: SlashCommandType.link,
      title: 'Link',
      subtitle: 'Insert an external web hyperlink',
      icon: PhosphorIconsRegular.link,
      shortcut: 'Ctrl+K',
      keywords: ['link', 'url', 'href'],
    ),
    SlashCommandItem(
      type: SlashCommandType.noteLink,
      title: 'Link Note',
      subtitle: 'Reference another note with [[Note]]',
      icon: PhosphorIconsRegular.fileText,
      shortcut: 'Ctrl+Shift+L',
      keywords: ['note', 'link', 'wikilink', '[['],
    ),
    SlashCommandItem(
      type: SlashCommandType.tag,
      title: 'Tag',
      subtitle: 'Categorize with a #tag',
      icon: PhosphorIconsRegular.tag,
      shortcut: 'Ctrl+Shift+T',
      keywords: ['tag', 'category', '#'],
    ),
    SlashCommandItem(
      type: SlashCommandType.paragraph,
      title: 'Paragraph',
      subtitle: 'Standard plain body text',
      icon: PhosphorIconsRegular.paragraph,
      shortcut: 'Ctrl+Alt+0',
      keywords: ['text', 'normal', 'paragraph', 'p'],
    ),
  ];
}
