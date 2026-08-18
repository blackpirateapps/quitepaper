import 'package:uuid/uuid.dart';

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
  })  : id = id ?? const Uuid().v4(),
        tags = List<String>.from(tags);

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
    );
  }
}
