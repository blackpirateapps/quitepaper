/// Available presentation styles for the notes list.
enum NotesListStyle {
  /// Default card-based notes list with date headers and top filter chips.
  quietPaper,

  /// Clean, content-focused editorial document list with inline attachments
  /// and dynamic collection header inspired by the Bear notes design language.
  editorial;

  String get storageKey => name;

  String get title {
    switch (this) {
      case NotesListStyle.quietPaper:
        return 'Quiet Paper';
      case NotesListStyle.editorial:
        return 'Editorial';
    }
  }

  String get description {
    switch (this) {
      case NotesListStyle.quietPaper:
        return 'Your current card-based notes list.';
      case NotesListStyle.editorial:
        return 'A content-focused list with inline previews and attachments.';
    }
  }

  static NotesListStyle fromString(String? val) {
    if (val == 'editorial') {
      return NotesListStyle.editorial;
    }
    return NotesListStyle.quietPaper;
  }
}
