import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';

void main() {
  group('FrontmatterEditorHelper Unit Tests', () {
    const sampleDocWithFrontmatter = '''---
title: Quiet Paper Architecture
author: Elena Woods
date: 2026-09-02
source: https://example.com/spec
description: High-level architectural specifications.
tags: [mobile, editor, wysiwyg]
status: published
# This is a YAML comment
rating: 5
---

# Introduction

This is the document body.
''';

    test('parse identifies frontmatter and exact property values', () {
      final doc = FrontmatterEditorHelper.parse(sampleDocWithFrontmatter);

      expect(doc.hasFrontmatter, isTrue);
      expect(doc.isMalformed, isFalse);
      expect(doc.title, equals('Quiet Paper Architecture'));
      expect(doc.author, equals('Elena Woods'));
      expect(doc.created, equals('2026-09-02'));
      expect(doc.source, equals('https://example.com/spec'));
      expect(doc.description, equals('High-level architectural specifications.'));
      expect(doc.tags, equals(['mobile', 'editor', 'wysiwyg']));
      expect(doc.unknownProperties['status'], equals('published'));
      expect(doc.unknownProperties['rating'], equals('5'));
      expect(doc.hasDisplayableProperties, isTrue);
    });

    test('parse handles document without frontmatter cleanly', () {
      const plainDoc = '# Hello World\nJust normal markdown.';
      final doc = FrontmatterEditorHelper.parse(plainDoc);

      expect(doc.hasFrontmatter, isFalse);
      expect(doc.hasDisplayableProperties, isFalse);
      expect(doc.title, isNull);
      expect(doc.tags, isEmpty);
    });

    test('updateProperty replaces existing property value in place without modifying comments or unknown keys', () {
      final updated = FrontmatterEditorHelper.updateProperty(
        documentText: sampleDocWithFrontmatter,
        key: 'author',
        newValue: 'Marcus Vance',
      );

      final parsed = FrontmatterEditorHelper.parse(updated);
      expect(parsed.author, equals('Marcus Vance'));
      expect(parsed.title, equals('Quiet Paper Architecture'));
      expect(parsed.unknownProperties['status'], equals('published'));
      expect(parsed.unknownProperties['rating'], equals('5'));
      expect(updated, contains('# This is a YAML comment'));
      expect(updated, contains('# Introduction\n\nThis is the document body.'));
    });

    test('updateProperty inserts new property before closing delimiter if not present', () {
      final updated = FrontmatterEditorHelper.updateProperty(
        documentText: sampleDocWithFrontmatter,
        key: 'custom_field',
        newValue: 'engineering',
      );

      final parsed = FrontmatterEditorHelper.parse(updated);
      expect(parsed.unknownProperties['custom_field'], equals('engineering'));
      expect(parsed.author, equals('Elena Woods'));
      expect(updated, contains('custom_field: engineering'));
    });

    test('updateProperty creates new frontmatter block at start if none exists', () {
      const plainDoc = '# Plain Document\nSome text.';
      final updated = FrontmatterEditorHelper.updateProperty(
        documentText: plainDoc,
        key: 'author',
        newValue: 'Ada Lovelace',
      );

      expect(updated, startsWith('---\nauthor: Ada Lovelace\n---\n\n# Plain Document'));
      final parsed = FrontmatterEditorHelper.parse(updated);
      expect(parsed.hasFrontmatter, isTrue);
      expect(parsed.author, equals('Ada Lovelace'));
    });

    test('updateTitle updates title in frontmatter when frontmatter is present', () {
      final updated = FrontmatterEditorHelper.updateTitle(
        documentText: sampleDocWithFrontmatter,
        newTitle: 'Updated Design Doc',
      );

      final parsed = FrontmatterEditorHelper.parse(updated);
      expect(parsed.title, equals('Updated Design Doc'));
      expect(parsed.author, equals('Elena Woods'));
      expect(updated, contains('title: Updated Design Doc'));
    });

    test('updateTitle does NOT add frontmatter if document does not have frontmatter', () {
      const plainDoc = '# Plain Document\nSome text.';
      final updated = FrontmatterEditorHelper.updateTitle(
        documentText: plainDoc,
        newTitle: 'New Title',
      );

      expect(updated, equals(plainDoc));
    });

    test('updateTags replaces tags in frontmatter', () {
      final updated = FrontmatterEditorHelper.updateTags(
        documentText: sampleDocWithFrontmatter,
        tags: ['flutter', 'release'],
      );

      final parsed = FrontmatterEditorHelper.parse(updated);
      expect(parsed.tags, equals(['flutter', 'release']));
      expect(parsed.author, equals('Elena Woods'));
      expect(updated, contains('tags: [flutter, release]'));
    });

    test('extractBody strips frontmatter block and returns body markdown', () {
      final body = FrontmatterEditorHelper.extractBody(sampleDocWithFrontmatter);
      expect(body, equals('\n# Introduction\n\nThis is the document body.\n'));
    });

    test('extractBody returns full text if no frontmatter exists', () {
      const plainDoc = '# Hello\nBody';
      expect(FrontmatterEditorHelper.extractBody(plainDoc), equals(plainDoc));
    });

    test('assemble joins frontmatter block and body', () {
      const header = '---\ntitle: Note\n---\n';
      const body = '# Heading\nBody';
      final full = FrontmatterEditorHelper.assemble(header, body);
      expect(full, equals('---\ntitle: Note\n---\n# Heading\nBody'));
    });
  });
}
