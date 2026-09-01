import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:quitepaper/features/tags/domain/tag_icon_definition.dart';
import 'package:quitepaper/features/tags/domain/tag_icon_registry.dart';

void main() {
  group('TagIconRegistry Tests', () {
    test('cleanId strips namespaces and cleans whitespace/casing', () {
      expect(TagIconRegistry.cleanId(null), isNull);
      expect(TagIconRegistry.cleanId(''), isNull);
      expect(TagIconRegistry.cleanId('   '), isNull);
      expect(TagIconRegistry.cleanId('phosphor:book-open'), 'book-open');
      expect(TagIconRegistry.cleanId('ph:Camera'), 'camera');
      expect(TagIconRegistry.cleanId('icon:heart'), 'heart');
      expect(TagIconRegistry.cleanId('  phosphor:folder_simple  '), 'folder-simple');
    });

    test('cleanId maps legacy aliases to canonical Phosphor identifiers', () {
      expect(TagIconRegistry.cleanId('pin'), 'push-pin');
      expect(TagIconRegistry.cleanId('box'), 'archive');
      expect(TagIconRegistry.cleanId('edit'), 'pencil-simple');
      expect(TagIconRegistry.cleanId('search'), 'magnifying-glass');
      expect(TagIconRegistry.cleanId('settings'), 'gear-six');
      expect(TagIconRegistry.cleanId('trash'), 'trash');
    });

    test('formatIconKey formats canonical storage key', () {
      expect(TagIconRegistry.formatIconKey('book-open'), 'phosphor:book-open');
      expect(TagIconRegistry.formatIconKey('phosphor:heart'), 'phosphor:heart');
      expect(TagIconRegistry.formatIconKey('pin'), 'phosphor:push-pin');
    });

    test('hasCustomIcon checks presence of icon ID', () {
      expect(TagIconRegistry.hasCustomIcon(null), isFalse);
      expect(TagIconRegistry.hasCustomIcon(''), isFalse);
      expect(TagIconRegistry.hasCustomIcon('phosphor:tag'), isTrue);
      expect(TagIconRegistry.hasCustomIcon('heart'), isTrue);
    });

    test('getIconData returns correct icon or fallback for null/unknown', () {
      // Fallback
      expect(TagIconRegistry.getIconData(null), PhosphorIconsRegular.tag);
      expect(TagIconRegistry.getIconData(''), PhosphorIconsRegular.tag);
      expect(TagIconRegistry.getIconData('unknown-nonexistent-icon'), PhosphorIconsRegular.tag);

      // Known icons
      expect(TagIconRegistry.getIconData('phosphor:acorn'), PhosphorIconsRegular.acorn);
      expect(TagIconRegistry.getIconData('camera'), PhosphorIconsRegular.camera);
      expect(TagIconRegistry.getIconData('heart'), PhosphorIconsRegular.heart);
    });

    test('getIconData supports custom weight variants', () {
      final reg = TagIconRegistry.getIconData('heart', weight: PhosphorIconWeight.regular);
      final bold = TagIconRegistry.getIconData('heart', weight: PhosphorIconWeight.bold);
      final fill = TagIconRegistry.getIconData('heart', weight: PhosphorIconWeight.fill);
      final light = TagIconRegistry.getIconData('heart', weight: PhosphorIconWeight.light);

      expect(reg, PhosphorIconsRegular.heart);
      expect(bold, PhosphorIconsBold.heart);
      expect(fill, PhosphorIconsFill.heart);
      expect(light, PhosphorIconsLight.heart);
    });

    test('fromId builds definition wrapper', () {
      final def = TagIconRegistry.fromId('phosphor:heart');
      expect(def, isNotNull);
      expect(def!.id, 'heart');
      expect(def.key, 'phosphor:heart');

      expect(TagIconRegistry.fromId(null), isNull);
    });
  });
}
