import 'package:uuid/uuid.dart';
import 'import_image_reference.dart';

class MarkdownImportItem {
  MarkdownImportItem({
    String? id,
    required this.filePath,
    required this.relativePath,
    required this.title,
    required this.content,
    required List<String> tags,
    required this.createdAt,
    required this.updatedAt,
    required this.fileSizeBytes,
    this.isSelected = true,
    List<ImportImageReference>? imageReferences,
  })  : id = id ?? const Uuid().v4(),
        tags = List<String>.from(tags),
        imageReferences = imageReferences != null
            ? List<ImportImageReference>.from(imageReferences)
            : <ImportImageReference>[];

  final String id;
  final String filePath;
  final String relativePath;
  String title;
  String content;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  int fileSizeBytes;
  bool isSelected;
  List<ImportImageReference> imageReferences;

  int get totalImagesCount => imageReferences.length;
  int get foundImagesCount => imageReferences.where((img) => img.isFound).length;
  int get missingImagesCount => imageReferences.where((img) => !img.isFound).length;
  bool get hasImages => imageReferences.isNotEmpty;
  bool get hasMissingImages => missingImagesCount > 0;

  void toggleSelected() {
    isSelected = !isSelected;
  }

  void addTag(String tag) {
    final clean = tag.trim().toLowerCase();
    if (clean.isNotEmpty && !tags.contains(clean)) {
      tags.add(clean);
    }
  }

  void removeTag(String tag) {
    tags.remove(tag.trim().toLowerCase());
  }

  MarkdownImportItem copyWith({
    String? id,
    String? filePath,
    String? relativePath,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? fileSizeBytes,
    bool? isSelected,
    List<ImportImageReference>? imageReferences,
  }) {
    return MarkdownImportItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isSelected: isSelected ?? this.isSelected,
      imageReferences: imageReferences ?? this.imageReferences,
    );
  }
}
