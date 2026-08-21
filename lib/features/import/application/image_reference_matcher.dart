import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../domain/import_image_reference.dart';
import '../domain/markdown_import_item.dart';
import 'markdown_image_parser.dart';

/// Smart matcher to map user-picked image files to unresolved markdown image references.
abstract final class ImageReferenceMatcher {
  /// Matches all missing image references in [items] against a batch of [pickedFiles].
  /// Returns the total number of newly resolved image references.
  static int matchMissingImages({
    required List<MarkdownImportItem> items,
    required List<PlatformFile> pickedFiles,
  }) {
    if (items.isEmpty || pickedFiles.isEmpty) {
      return 0;
    }

    var matchedCount = 0;

    for (final item in items) {
      for (final ref in item.imageReferences) {
        if (ref.isFound) continue;

        final matchedFile = _findBestMatch(ref, pickedFiles);
        if (matchedFile != null) {
          if (matchedFile.path != null && matchedFile.path!.isNotEmpty) {
            try {
              final file = File(matchedFile.path!);
              final stat = file.statSync();
              ref.markResolved(filePath: file.path, byteSize: stat.size);
              matchedCount++;
            } catch (_) {
              if (matchedFile.bytes != null) {
                ref.markResolved(bytes: matchedFile.bytes, byteSize: matchedFile.size);
                matchedCount++;
              }
            }
          } else if (matchedFile.bytes != null) {
            ref.markResolved(bytes: matchedFile.bytes, byteSize: matchedFile.size);
            matchedCount++;
          }
        }
      }
    }

    return matchedCount;
  }

  /// Relinks a single specific [ref] with a chosen [pickedFile].
  static bool relinkSingleImage({
    required ImportImageReference ref,
    required PlatformFile pickedFile,
  }) {
    if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
      try {
        final file = File(pickedFile.path!);
        final stat = file.statSync();
        ref.markResolved(filePath: file.path, byteSize: stat.size);
        return true;
      } catch (_) {
        if (pickedFile.bytes != null) {
          ref.markResolved(bytes: pickedFile.bytes, byteSize: pickedFile.size);
          return true;
        }
      }
    } else if (pickedFile.bytes != null) {
      ref.markResolved(bytes: pickedFile.bytes, byteSize: pickedFile.size);
      return true;
    }
    return false;
  }

  static PlatformFile? _findBestMatch(
    ImportImageReference ref,
    List<PlatformFile> pickedFiles,
  ) {
    final cleaned = MarkdownImageParser.cleanTarget(ref.rawTarget);
    final targetBase = p.basename(cleaned).toLowerCase();
    final targetNameNoExt = p.basenameWithoutExtension(cleaned).toLowerCase();
    final targetNormalized = targetNameNoExt.replaceAll(RegExp(r'[-_\s]+'), ' ').trim();

    // 1. Exact basename match (e.g. "photo.png" == "photo.png")
    for (final pf in pickedFiles) {
      final name = pf.name.toLowerCase();
      if (name == targetBase) return pf;

      if (pf.path != null) {
        final pathBase = p.basename(pf.path!).toLowerCase();
        if (pathBase == targetBase) return pf;
      }
    }

    // 2. Trailing subpath match (e.g. "assets/diagram.png" in "/User/Downloads/assets/diagram.png")
    if (cleaned.contains('/') || cleaned.contains('\\')) {
      final normalizedTargetSubpath = p.normalize(cleaned).toLowerCase();
      for (final pf in pickedFiles) {
        if (pf.path != null) {
          final normalizedPickedPath = p.normalize(pf.path!).toLowerCase();
          if (normalizedPickedPath.endsWith(normalizedTargetSubpath)) {
            return pf;
          }
        }
      }
    }

    // 3. Name without extension match (e.g. "photo.jpg" matches "photo.jpeg" or "photo.png")
    for (final pf in pickedFiles) {
      final pfNameNoExt = p.basenameWithoutExtension(pf.name).toLowerCase();
      if (pfNameNoExt == targetNameNoExt) return pf;
    }

    // 4. Delimiter-tolerant match (e.g. "flow_chart.png" matches "flow-chart.png" or "flow chart.png")
    for (final pf in pickedFiles) {
      final pfNormalized = p
          .basenameWithoutExtension(pf.name)
          .toLowerCase()
          .replaceAll(RegExp(r'[-_\s]+'), ' ')
          .trim();
      if (pfNormalized == targetNormalized && targetNormalized.isNotEmpty) {
        return pf;
      }
    }

    return null;
  }
}
