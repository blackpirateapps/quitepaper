import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Status of an image reference extracted from a markdown document.
enum ImportImageStatus {
  /// File was successfully located on disk or picked by the user.
  resolved,

  /// File could not be found at the relative or vault paths.
  missing,

  /// File was found but exceeds the 25 MB size limit.
  exceedsLimit,

  /// File is not a supported image format.
  unsupportedType,
}

/// Represents an image reference found inside an imported markdown document.
class ImportImageReference {
  ImportImageReference({
    String? id,
    required this.originalSyntax,
    required this.rawTarget,
    required this.altText,
    this.resolvedFilePath,
    this.pickedBytes,
    this.fileSizeBytes = 0,
    this.status = ImportImageStatus.missing,
  }) : id = id ?? const Uuid().v4();

  /// Unique identifier for this image reference instance.
  final String id;

  /// The exact verbatim markdown snippet in the source document (e.g. `![Alt](images/pic.png)` or `![[pic.png]]`).
  final String originalSyntax;

  /// The raw path or target specified in the markdown (e.g. `images/pic.png`, `pic.png`, `./assets/pic.png`).
  final String rawTarget;

  /// The extracted alt text or title description.
  final String altText;

  /// The absolute path to the resolved image file on the local filesystem.
  String? resolvedFilePath;

  /// Raw image bytes if the file was picked in memory.
  Uint8List? pickedBytes;

  /// Size of the image file in bytes.
  int fileSizeBytes;

  /// Current resolution status.
  ImportImageStatus status;

  /// Whether the image is resolved and ready for encrypted import.
  bool get isFound =>
      status == ImportImageStatus.resolved &&
      ((resolvedFilePath != null && resolvedFilePath!.isNotEmpty) ||
          (pickedBytes != null && pickedBytes!.isNotEmpty));

  /// Clean display filename for UI representation.
  String get displayName {
    if (resolvedFilePath != null && resolvedFilePath!.isNotEmpty) {
      return p.basename(resolvedFilePath!);
    }
    final clean = Uri.decodeComponent(
      rawTarget.split('?').first.split('#').first.trim(),
    );
    final base = p.basename(clean);
    return base.isNotEmpty ? base : rawTarget;
  }

  /// Marks this reference as successfully resolved with a local file or bytes.
  void markResolved({
    String? filePath,
    Uint8List? bytes,
    int? byteSize,
  }) {
    if (filePath != null && filePath.isNotEmpty) {
      resolvedFilePath = filePath;
    }
    if (bytes != null && bytes.isNotEmpty) {
      pickedBytes = bytes;
    }
    if (byteSize != null) {
      fileSizeBytes = byteSize;
    }
    status = ImportImageStatus.resolved;
  }

  /// Marks this reference as missing / unresolvable.
  void markMissing() {
    resolvedFilePath = null;
    pickedBytes = null;
    status = ImportImageStatus.missing;
  }

  ImportImageReference copyWith({
    String? id,
    String? originalSyntax,
    String? rawTarget,
    String? altText,
    String? resolvedFilePath,
    Uint8List? pickedBytes,
    int? fileSizeBytes,
    ImportImageStatus? status,
  }) {
    return ImportImageReference(
      id: id ?? this.id,
      originalSyntax: originalSyntax ?? this.originalSyntax,
      rawTarget: rawTarget ?? this.rawTarget,
      altText: altText ?? this.altText,
      resolvedFilePath: resolvedFilePath ?? this.resolvedFilePath,
      pickedBytes: pickedBytes ?? this.pickedBytes,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
    );
  }
}
