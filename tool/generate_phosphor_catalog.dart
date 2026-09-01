// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Build-time script to generate the complete offline Phosphor Icon catalog
/// for Quiet Paper from the pinned @phosphor-icons/core version.
///
/// Usage:
///   dart run tool/generate_phosphor_catalog.dart
void main() async {
  print('=== Quiet Paper Phosphor Catalog Generator ===');
  const phosphorVersion = '2.1.1';
  const packageVersion = '2.1.0';

  // 1. Fetch official metadata from unpkg
  print('Fetching Phosphor core metadata v$phosphorVersion...');
  final url = Uri.parse('https://unpkg.com/@phosphor-icons/core@$phosphorVersion/dist/index.mjs');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch Phosphor core metadata: HTTP ${response.statusCode}');
  }

  final body = response.body;

  // 2. Parse phosphor_icons_regular.dart from pub cache for codepoint mapping & flutter camelCase names
  print('Inspecting phosphor_flutter package...');
  final pubCachePath = Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache';
  final regularFile = File('$pubCachePath/hosted/pub.dev/phosphor_flutter-$packageVersion/lib/src/phosphor_icons_regular.dart');
  if (!regularFile.existsSync()) {
    throw Exception('phosphor_flutter-$packageVersion not found in pub cache. Run flutter pub get first.');
  }

  final regularContent = regularFile.readAsStringSync();
  final lines = regularContent.split('\n');
  final flutterIconMap = <String, Map<String, dynamic>>{}; // kebab -> {camelName, codePoint}

  String? currentDoc;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('/// ![')) {
      currentDoc = trimmed;
    } else if (trimmed.startsWith('static const ')) {
      final match = RegExp(r'static const ([a-zA-Z0-9_]+) = PhosphorFlatIconData\((0x[0-9a-fA-F]+)').firstMatch(trimmed);
      if (match != null) {
        final camelName = match.group(1)!;
        final codePointHex = match.group(2)!;
        final codePoint = int.parse(codePointHex);
        String kebab = camelName;
        if (currentDoc != null) {
          final docMatch = RegExp(r'/// !\[([a-zA-Z0-9_-]+)\]').firstMatch(currentDoc);
          if (docMatch != null) {
            kebab = docMatch.group(1)!;
          }
        }
        flutterIconMap[kebab] = {
          'camelName': camelName,
          'codePointHex': codePointHex,
          'codePoint': codePoint,
        };
      }
      currentDoc = null;
    }
  }

  print('Discovered ${flutterIconMap.length} icons in phosphor_flutter.');

  // 3. Extract official icon items from index.mjs
  // The catalog in index.mjs is inside `const n = [ ... ];` or similar array
  final arrayStart = body.indexOf('const n = [');
  if (arrayStart == -1) {
    throw Exception('Could not locate catalog array in index.mjs');
  }
  final arrayEnd = body.indexOf(';', arrayStart);
  final arrayJs = body.substring(arrayStart + 'const n = '.length, arrayEnd).trim();

  // Convert JS object syntax to JSON
  // In index.mjs, properties are keys like `name:`, `pascal_name:`, `categories:`, `figma_category:`, `tags:`, `codepoint:`
  // and enum references like `e.FINANCE`, `a.WEATHER`
  // Let's parse with RegExp
  final itemRegex = RegExp(r'\{\s*name:\s*"([^"]+)",\s*pascal_name:\s*"([^"]+)",\s*categories:\s*\[([^\]]*)\],\s*figma_category:\s*([^,]+),\s*tags:\s*\[([^\]]*)\],\s*codepoint:\s*([0-9]+)', multiLine: true);

  final matches = itemRegex.allMatches(arrayJs);
  print('Extracted ${matches.length} icons from official metadata.');

  if (matches.isEmpty) {
    throw Exception('Failed to parse official icons from index.mjs');
  }

  final categoryMap = {
    'e.ARROWS': 'arrows',
    'e.BRAND': 'brands',
    'e.COMMERCE': 'finance',
    'e.COMMUNICATION': 'communication',
    'e.DESIGN': 'design',
    'e.DEVELOPMENT': 'development',
    'e.EDITOR': 'files',
    'e.FINANCE': 'finance',
    'e.GAMES': 'activity',
    'e.HEALTH': 'health',
    'e.MAP': 'maps',
    'e.MEDIA': 'media',
    'e.NATURE': 'nature',
    'e.OBJECTS': 'objects',
    'e.OFFICE': 'files',
    'e.PEOPLE': 'people',
    'e.SYSTEM': 'system',
    'e.WEATHER': 'weather',
  };

  final figmaCategoryMap = {
    'a.ARROWS': 'arrows',
    'a.BRAND': 'brands',
    'a.COMMERCE': 'finance',
    'a.COMMUNICATION': 'communication',
    'a.DESIGN': 'design',
    'a.DEVELOPMENT': 'development',
    'a.EDUCATION': 'education',
    'a.FINANCE': 'finance',
    'a.GAMES': 'activity',
    'a.HEALTH': 'health',
    'a.MAP': 'maps',
    'a.MEDIA': 'media',
    'a.OFFICE': 'files',
    'a.PEOPLE': 'people',
    'a.SECURITY': 'security',
    'a.SYSTEM': 'system',
    'a.TIME': 'system',
    'a.WEATHER': 'weather',
  };

  final catalogEntries = <Map<String, dynamic>>[];
  final processedIds = <String>{};

  for (final m in matches) {
    final id = m.group(1)!;
    final pascalName = m.group(2)!;
    final rawCats = m.group(3)!;
    final rawFigmaCat = m.group(4)!.trim();
    final rawTags = m.group(5)!;
    final codepoint = int.parse(m.group(6)!);

    // Tags / aliases
    final tags = RegExp(r'"([^"]+)"')
        .allMatches(rawTags)
        .map((tm) => tm.group(1)!)
        .where((t) => t != '*new*' && t != '*updated*')
        .toList();

    // Categories
    final categories = <String>{};
    for (final rawCat in rawCats.split(',')) {
      final key = rawCat.trim();
      if (categoryMap.containsKey(key)) {
        categories.add(categoryMap[key]!);
      }
    }
    if (figmaCategoryMap.containsKey(rawFigmaCat)) {
      categories.add(figmaCategoryMap[rawFigmaCat]!);
    }

    // Specific category heuristic mappings
    if (id.contains('food') || id.contains('coffee') || id.contains('beer') || id.contains('cup') || id.contains('fork') || id.contains('knife') || id.contains('cookie') || id.contains('cake') || id.contains('pizza') || id.contains('burger') || id.contains('bowl') || id.contains('bread') || id.contains('brandy') || id.contains('martini') || id.contains('wine')) {
      categories.add('food');
    }
    if (id.contains('building') || id.contains('house') || id.contains('bank') || id.contains('church') || id.contains('hospital') || id.contains('warehouse') || id.contains('storefront') || id.contains('factory')) {
      categories.add('buildings');
      categories.add('places');
    }
    if (id.contains('car') || id.contains('train') || id.contains('bicycle') || id.contains('motorcycle') || id.contains('bus') || id.contains('airplane') || id.contains('taxi') || id.contains('boat') || id.contains('jeep') || id.contains('truck') || id.contains('scooter') || id.contains('rocket') || id.contains('van')) {
      categories.add('transportation');
    }
    if (id.contains('shield') || id.contains('lock') || id.contains('key') || id.contains('password') || id.contains('fingerprint') || id.contains('warning') || id.contains('siren') || id.contains('vault') || id.contains('firewall')) {
      categories.add('security');
    }
    if (id.contains('circle') || id.contains('square') || id.contains('triangle') || id.contains('polygon') || id.contains('star') || id.contains('diamond') || id.contains('hexagon') || id.contains('octagon') || id.contains('heart') || id.contains('cube') || id.contains('cylinder') || id.contains('sphere')) {
      categories.add('shapes');
    }
    if (id.contains('atom') || id.contains('dna') || id.contains('flask') || id.contains('test-tube') || id.contains('molecule') || id.contains('planet') || id.contains('telescope') || id.contains('microscope') || id.contains('radioactive')) {
      categories.add('science');
    }
    if (id.contains('book') || id.contains('student') || id.contains('graduation') || id.contains('notebook') || id.contains('chalkboard') || id.contains('exam') || id.contains('read')) {
      categories.add('education');
    }
    if (id.contains('computer') || id.contains('laptop') || id.contains('cpu') || id.contains('hard-drive') || id.contains('microchip') || id.contains('robot') || id.contains('drone') || id.contains('sim-card') || id.contains('motherboard')) {
      categories.add('technology');
    }
    if (id.contains('code') || id.contains('git') || id.contains('terminal') || id.contains('brackets') || id.contains('bug') || id.contains('webhook') || id.contains('api')) {
      categories.add('development');
    }
    if (id.contains('activity') || id.contains('game') || id.contains('sport') || id.contains('football') || id.contains('basketball') || id.contains('tennis') || id.contains('golf') || id.contains('barbell') || id.contains('swimming') || id.contains('run') || id.contains('sneaker')) {
      categories.add('activity');
    }

    if (categories.isEmpty) {
      categories.add('objects');
    }

    // Convert pascal_name to human readable display name: e.g. "AddressBook" -> "Address Book"
    final displayName = _formatDisplayName(pascalName);

    final flutterData = flutterIconMap[id];
    final camelName = flutterData?['camelName'] ?? _kebabToCamel(id);
    final finalCodePoint = flutterData?['codePoint'] ?? codepoint;

    if (processedIds.contains(id)) {
      throw Exception('Duplicate icon ID discovered: $id');
    }
    processedIds.add(id);

    catalogEntries.add({
      'id': id,
      'name': displayName,
      'pascalName': pascalName,
      'camelName': camelName,
      'codePoint': finalCodePoint,
      'categories': categories.toList()..sort(),
      'tags': tags,
    });
  }

  // Also verify any icons in flutterIconMap that were not in index.mjs
  for (final entry in flutterIconMap.entries) {
    final id = entry.key;
    if (!processedIds.contains(id)) {
      final camelName = entry.value['camelName'] as String;
      final codePoint = entry.value['codePoint'] as int;
      final pascalName = _camelToPascal(camelName);
      final displayName = _formatDisplayName(pascalName);
      processedIds.add(id);
      catalogEntries.add({
        'id': id,
        'name': displayName,
        'pascalName': pascalName,
        'camelName': camelName,
        'codePoint': codePoint,
        'categories': ['objects'],
        'tags': <String>[],
      });
    }
  }

  catalogEntries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  print('Total compiled icons in catalog: ${catalogEntries.length}');

  // 4. Write catalog JSON to assets/icons/phosphor_catalog.json
  final catalogFile = File('assets/icons/phosphor_catalog.json');
  catalogFile.parent.createSync(recursive: true);
  final catalogJsonString = const JsonEncoder.withIndent('  ').convert(catalogEntries);
  catalogFile.writeAsStringSync(catalogJsonString);
  print('Wrote catalog to ${catalogFile.path} (${catalogFile.lengthSync()} bytes)');

  // 5. Compute SHA256 of catalog file for manifest integrity
  final catalogBytes = catalogFile.readAsBytesSync();
  final catalogDigest = sha256.convert(catalogBytes).toString();

  // 6. Write manifest JSON
  final manifest = {
    'version': phosphorVersion,
    'packageVersion': packageVersion,
    'iconCount': catalogEntries.length,
    'catalogSha256': catalogDigest,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'license': 'MIT (Phosphor Icons - https://phosphoricons.com)',
    'categories': [
      'activity',
      'arrows',
      'brands',
      'buildings',
      'communication',
      'design',
      'development',
      'education',
      'files',
      'finance',
      'food',
      'health',
      'maps',
      'media',
      'nature',
      'objects',
      'people',
      'places',
      'science',
      'security',
      'shapes',
      'system',
      'technology',
      'transportation',
      'weather',
    ],
  };
  final manifestFile = File('assets/icons/phosphor_manifest.json');
  manifestFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  print('Wrote manifest to ${manifestFile.path}');

  // 7. Generate Dart code map in lib/features/tags/domain/phosphor_icon_data_map.g.dart
  // for instant synchronous resolution of any Phosphor icon!
  final dartFile = File('lib/features/tags/domain/phosphor_icon_data_map.g.dart');
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// Generated by tool/generate_phosphor_catalog.dart');
  buffer.writeln('// Phosphor Icons Version: $phosphorVersion (Package: $packageVersion)');
  buffer.writeln('// Icon Count: ${catalogEntries.length}');
  buffer.writeln();
  buffer.writeln("import 'package:phosphor_flutter/phosphor_flutter.dart';");
  buffer.writeln();
  buffer.writeln('/// Map of all normalized Phosphor icon IDs to their PhosphorFlatIconData glyphs.');
  buffer.writeln('const Map<String, PhosphorFlatIconData> kPhosphorRegularIcons = {');
  for (final item in catalogEntries) {
    final id = item['id'] as String;
    final camelName = item['camelName'] as String;
    buffer.writeln("  '$id': PhosphorIconsRegular.$camelName,");
  }
  buffer.writeln('};');
  buffer.writeln();
  buffer.writeln('/// Map of all normalized Phosphor icon IDs to their Bold glyphs.');
  buffer.writeln('const Map<String, PhosphorFlatIconData> kPhosphorBoldIcons = {');
  for (final item in catalogEntries) {
    final id = item['id'] as String;
    final camelName = item['camelName'] as String;
    buffer.writeln("  '$id': PhosphorIconsBold.$camelName,");
  }
  buffer.writeln('};');
  buffer.writeln();
  buffer.writeln('/// Map of all normalized Phosphor icon IDs to their Fill glyphs.');
  buffer.writeln('const Map<String, PhosphorFlatIconData> kPhosphorFillIcons = {');
  for (final item in catalogEntries) {
    final id = item['id'] as String;
    final camelName = item['camelName'] as String;
    buffer.writeln("  '$id': PhosphorIconsFill.$camelName,");
  }
  buffer.writeln('};');
  buffer.writeln();
  buffer.writeln('/// Map of all normalized Phosphor icon IDs to their Light glyphs.');
  buffer.writeln('const Map<String, PhosphorFlatIconData> kPhosphorLightIcons = {');
  for (final item in catalogEntries) {
    final id = item['id'] as String;
    final camelName = item['camelName'] as String;
    buffer.writeln("  '$id': PhosphorIconsLight.$camelName,");
  }
  buffer.writeln('};');
  buffer.writeln();

  dartFile.writeAsStringSync(buffer.toString());
  print('Wrote Dart icon maps to ${dartFile.path} (${dartFile.lengthSync()} bytes)');
  print('=== Generation Complete! ===');
}

String _formatDisplayName(String pascalName) {
  final buffer = StringBuffer();
  for (int i = 0; i < pascalName.length; i++) {
    final char = pascalName[i];
    if (i > 0 && char.toUpperCase() == char && char.toLowerCase() != char) {
      // Check if previous char was lowercase or next is lowercase
      final prev = pascalName[i - 1];
      if (prev.toLowerCase() == prev || (i + 1 < pascalName.length && pascalName[i + 1].toLowerCase() == pascalName[i + 1])) {
        buffer.write(' ');
      }
    }
    buffer.write(char);
  }
  return buffer.toString().trim();
}

String _kebabToCamel(String kebab) {
  final parts = kebab.split('-');
  if (parts.isEmpty) return kebab;
  final first = parts.first.toLowerCase();
  final rest = parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}').join('');
  return '$first$rest';
}

String _camelToPascal(String camel) {
  if (camel.isEmpty) return camel;
  return '${camel[0].toUpperCase()}${camel.substring(1)}';
}
