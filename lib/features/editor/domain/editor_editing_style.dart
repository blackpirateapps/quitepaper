/// Supported editing styles for the Quiet Paper Markdown editor.
enum EditorEditingStyle {
  /// WYSIWYG mode (Beta): Markdown syntax is hidden during editing for a calm, Bear-like writing experience.
  wysiwyg,

  /// Markdown mode: Raw Markdown syntax remains visible during editing.
  markdown;

  /// Returns the persistent string key for this editing style.
  String get storageKey => name;

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case EditorEditingStyle.wysiwyg:
        return 'WYSIWYG (Beta)';
      case EditorEditingStyle.markdown:
        return 'Markdown';
    }
  }

  /// Descriptive subtitle for settings presentation.
  String get description {
    switch (this) {
      case EditorEditingStyle.wysiwyg:
        return 'Hide Markdown syntax for a cleaner writing experience';
      case EditorEditingStyle.markdown:
        return 'Show Markdown syntax while editing';
    }
  }

  /// Parses a stored string into [EditorEditingStyle], defaulting to [EditorEditingStyle.wysiwyg].
  static EditorEditingStyle fromString(String? value) {
    if (value == 'markdown') {
      return EditorEditingStyle.markdown;
    }
    return EditorEditingStyle.wysiwyg;
  }
}
