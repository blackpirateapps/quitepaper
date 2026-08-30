import 'package:highlight/languages/all.dart' as hl_all;
import '../domain/syntax_language.dart';

/// Central registry of programming, configuration, and markup languages
/// supported by Quiet Paper's syntax highlighting subsystem.
class SyntaxLanguageRegistry {
  SyntaxLanguageRegistry._() {
    _init();
  }

  /// Singleton instance.
  static final SyntaxLanguageRegistry instance = SyntaxLanguageRegistry._();

  static const int version = 1;

  final Map<String, SyntaxLanguage> _languagesById = {};
  final Map<String, SyntaxLanguage> _languagesByAlias = {};
  final Map<String, SyntaxLanguage> _languagesByExtension = {};
  final Map<String, SyntaxLanguage> _languagesByMime = {};
  final List<SyntaxLanguage> _allLanguages = [];

  List<SyntaxLanguage> get allLanguages => List.unmodifiable(_allLanguages);
  List<String> get allLanguageIds => List.unmodifiable(_languagesById.keys.toList());

  void _register(SyntaxLanguage lang) {
    _languagesById[lang.id.toLowerCase()] = lang;
    _allLanguages.add(lang);

    for (final alias in lang.aliases) {
      _languagesByAlias[alias.toLowerCase()] = lang;
    }
    for (final ext in lang.extensions) {
      final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
      _languagesByExtension[cleanExt.toLowerCase()] = lang;
    }
    for (final mime in lang.mimeTypes) {
      _languagesByMime[mime.toLowerCase()] = lang;
    }
  }

  void _init() {
    _register(SyntaxLanguage.plainText);

    // 1. Core Mobile & Web Languages
    _register(const SyntaxLanguage(
      id: 'dart',
      name: 'Dart',
      aliases: ['flutter'],
      extensions: ['dart'],
      mimeTypes: ['text/x-dart', 'application/vnd.dart'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'javascript',
      name: 'JavaScript',
      aliases: ['js', 'node', 'jsx'],
      extensions: ['js', 'mjs', 'cjs', 'jsx'],
      mimeTypes: ['text/javascript', 'application/javascript', 'text/jsx'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'typescript',
      name: 'TypeScript',
      aliases: ['ts', 'tsx'],
      extensions: ['ts', 'mts', 'cts', 'tsx'],
      mimeTypes: ['application/typescript', 'text/typescript', 'text/tsx'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'xml',
      name: 'HTML / XML',
      aliases: ['html', 'htm', 'xhtml', 'svg', 'plist', 'xaml'],
      extensions: ['html', 'htm', 'xml', 'svg', 'plist', 'xaml'],
      mimeTypes: ['text/html', 'text/xml', 'application/xml', 'image/svg+xml'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'css',
      name: 'CSS',
      aliases: ['style'],
      extensions: ['css'],
      mimeTypes: ['text/css'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'scss',
      name: 'SCSS / Sass',
      aliases: ['sass'],
      extensions: ['scss', 'sass'],
      mimeTypes: ['text/x-scss', 'text/x-sass'],
      category: 'Mobile & Web',
    ));

    _register(const SyntaxLanguage(
      id: 'json',
      name: 'JSON',
      aliases: ['jsonc', 'jsonl', 'geojson'],
      extensions: ['json', 'jsonc', 'jsonl', 'geojson'],
      mimeTypes: ['application/json', 'application/json5', 'application/x-jsonlines'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'yaml',
      name: 'YAML',
      aliases: ['yml'],
      extensions: ['yaml', 'yml'],
      mimeTypes: ['text/yaml', 'text/x-yaml', 'application/x-yaml'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'sql',
      name: 'SQL',
      aliases: ['mysql', 'pgsql', 'postgres', 'sqlite', 'plsql', 'tsql'],
      extensions: ['sql', 'psql'],
      mimeTypes: ['text/x-sql', 'application/sql'],
      category: 'Database',
    ));

    _register(const SyntaxLanguage(
      id: 'bash',
      name: 'Bash / Shell',
      aliases: ['sh', 'shell', 'zsh', 'ash'],
      extensions: ['sh', 'bash', 'zsh'],
      mimeTypes: ['application/x-sh', 'text/x-shellscript'],
      category: 'Scripting',
    ));

    // 2. General-Purpose & Systems Languages
    _register(const SyntaxLanguage(
      id: 'python',
      name: 'Python',
      aliases: ['py', 'python3', 'pyw'],
      extensions: ['py', 'pyw', 'pyi'],
      mimeTypes: ['text/x-python', 'application/x-python-code'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'rust',
      name: 'Rust',
      aliases: ['rs'],
      extensions: ['rs'],
      mimeTypes: ['text/x-rust', 'text/rust'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'go',
      name: 'Go',
      aliases: ['golang'],
      extensions: ['go'],
      mimeTypes: ['text/x-go', 'text/x-golang'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'kotlin',
      name: 'Kotlin',
      aliases: ['kt', 'kts'],
      extensions: ['kt', 'kts', 'ktm'],
      mimeTypes: ['text/x-kotlin'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'swift',
      name: 'Swift',
      aliases: ['swift'],
      extensions: ['swift'],
      mimeTypes: ['text/x-swift'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'java',
      name: 'Java',
      aliases: ['jsp'],
      extensions: ['java', 'jsp'],
      mimeTypes: ['text/x-java-source', 'text/x-java'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'cpp',
      name: 'C++',
      aliases: ['c++', 'cc', 'cxx', 'hpp', 'hh', 'hxx'],
      extensions: ['cpp', 'cc', 'cxx', 'c++', 'hpp', 'hh', 'hxx', 'h++'],
      mimeTypes: ['text/x-c++src', 'text/x-c++hdr'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'c',
      name: 'C',
      aliases: ['h'],
      extensions: ['c', 'h'],
      mimeTypes: ['text/x-csrc', 'text/x-chdr'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'cs',
      name: 'C#',
      aliases: ['csharp', 'c#'],
      extensions: ['cs'],
      mimeTypes: ['text/x-csharp'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'php',
      name: 'PHP',
      aliases: ['php3', 'php4', 'php5', 'phtml'],
      extensions: ['php', 'phtml', 'php3', 'php4', 'php5'],
      mimeTypes: ['application/x-httpd-php', 'text/x-php'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'ruby',
      name: 'Ruby',
      aliases: ['rb', 'gemspec', 'podspec', 'rake'],
      extensions: ['rb', 'gemspec', 'podspec', 'rake'],
      mimeTypes: ['text/x-ruby', 'application/x-ruby'],
      category: 'Programming',
    ));

    // 3. Configuration, Data & Markup
    _register(const SyntaxLanguage(
      id: 'markdown',
      name: 'Markdown',
      aliases: ['md', 'mkd', 'mdown'],
      extensions: ['md', 'markdown', 'mdown', 'mkd'],
      mimeTypes: ['text/markdown', 'text/x-markdown'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'toml',
      name: 'TOML',
      aliases: ['cargo.lock', 'pipfile'],
      extensions: ['toml'],
      mimeTypes: ['application/toml', 'text/x-toml'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'ini',
      name: 'INI / Config',
      aliases: ['cfg', 'conf', 'properties', 'env', 'editorconfig', 'gitignore'],
      extensions: ['ini', 'cfg', 'conf', 'properties', 'env', 'editorconfig', 'gitignore'],
      mimeTypes: ['text/x-ini', 'text/x-properties'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'graphql',
      name: 'GraphQL',
      aliases: ['gql'],
      extensions: ['graphql', 'gql'],
      mimeTypes: ['application/graphql'],
      category: 'Database',
    ));

    _register(const SyntaxLanguage(
      id: 'dockerfile',
      name: 'Dockerfile',
      aliases: ['docker'],
      extensions: ['dockerfile'],
      mimeTypes: ['text/x-dockerfile'],
      category: 'DevOps & Tooling',
    ));

    _register(const SyntaxLanguage(
      id: 'makefile',
      name: 'Makefile',
      aliases: ['make', 'mk'],
      extensions: ['makefile', 'mk'],
      mimeTypes: ['text/x-makefile'],
      category: 'DevOps & Tooling',
    ));

    _register(const SyntaxLanguage(
      id: 'diff',
      name: 'Diff / Patch',
      aliases: ['patch'],
      extensions: ['diff', 'patch'],
      mimeTypes: ['text/x-diff', 'text/x-patch'],
      category: 'DevOps & Tooling',
    ));

    // 4. Other Popular Scripting & Functional Languages
    _register(const SyntaxLanguage(
      id: 'lua',
      name: 'Lua',
      aliases: [],
      extensions: ['lua'],
      mimeTypes: ['text/x-lua'],
      category: 'Scripting',
    ));

    _register(const SyntaxLanguage(
      id: 'powershell',
      name: 'PowerShell',
      aliases: ['ps', 'ps1'],
      extensions: ['ps1', 'psm1', 'psd1'],
      mimeTypes: ['text/x-powershell'],
      category: 'Scripting',
    ));

    _register(const SyntaxLanguage(
      id: 'perl',
      name: 'Perl',
      aliases: ['pl', 'pm'],
      extensions: ['pl', 'pm'],
      mimeTypes: ['text/x-perl'],
      category: 'Scripting',
    ));

    _register(const SyntaxLanguage(
      id: 'r',
      name: 'R',
      aliases: ['rlang'],
      extensions: ['r', 'R'],
      mimeTypes: ['text/x-r'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'scala',
      name: 'Scala',
      aliases: [],
      extensions: ['scala', 'sc'],
      mimeTypes: ['text/x-scala'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'protobuf',
      name: 'Protocol Buffers',
      aliases: ['proto'],
      extensions: ['proto'],
      mimeTypes: ['text/x-protobuf'],
      category: 'Data & Config',
    ));

    _register(const SyntaxLanguage(
      id: 'objectivec',
      name: 'Objective-C',
      aliases: ['objc', 'mm', 'm'],
      extensions: ['m', 'mm'],
      mimeTypes: ['text/x-objectivec'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'elixir',
      name: 'Elixir',
      aliases: ['ex', 'exs'],
      extensions: ['ex', 'exs'],
      mimeTypes: ['text/x-elixir'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'erlang',
      name: 'Erlang',
      aliases: ['erl'],
      extensions: ['erl', 'hrl'],
      mimeTypes: ['text/x-erlang'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'clojure',
      name: 'Clojure',
      aliases: ['clj', 'cljs'],
      extensions: ['clj', 'cljs', 'cljc', 'edn'],
      mimeTypes: ['text/x-clojure'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'haskell',
      name: 'Haskell',
      aliases: ['hs'],
      extensions: ['hs', 'lhs'],
      mimeTypes: ['text/x-haskell'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'julia',
      name: 'Julia',
      aliases: ['jl'],
      extensions: ['jl'],
      mimeTypes: ['text/x-julia'],
      category: 'Programming',
    ));

    _register(const SyntaxLanguage(
      id: 'vim',
      name: 'Vim Script',
      aliases: ['vimscript'],
      extensions: ['vim', 'vimrc'],
      mimeTypes: ['text/x-vim'],
      category: 'Scripting',
    ));

    // 10. Populate all remaining bundled highlight grammars
    for (final entry in hl_all.allLanguages.entries) {
      if (!_languagesById.containsKey(entry.key.toLowerCase())) {
        final rawName = entry.key;
        final displayName = rawName.isNotEmpty
            ? '${rawName[0].toUpperCase()}${rawName.substring(1)}'
            : rawName;
        _register(SyntaxLanguage(
          id: entry.key,
          name: displayName,
          extensions: [entry.key],
          category: 'Other',
        ));
      }
    }
  }

  /// Finds a language by its canonical ID.
  SyntaxLanguage? findById(String id) {
    final clean = id.trim().toLowerCase();
    return _languagesById[clean];
  }

  /// Finds a language by canonical ID or alias.
  SyntaxLanguage? findByIdOrAlias(String identifier) {
    final clean = identifier.trim().toLowerCase();
    return _languagesById[clean] ?? _languagesByAlias[clean];
  }

  /// Finds a language by file extension (with or without leading dot).
  SyntaxLanguage? findByExtension(String extension) {
    var clean = extension.trim().toLowerCase();
    if (clean.startsWith('.')) {
      clean = clean.substring(1);
    }
    return _languagesByExtension[clean];
  }

  /// Finds a language by MIME type.
  SyntaxLanguage? findByMimeType(String mimeType) {
    final clean = mimeType.trim().toLowerCase();
    return _languagesByMime[clean];
  }

  /// Searches languages by name, ID, or alias matching [query].
  List<SyntaxLanguage> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return allLanguages;

    return _allLanguages.where((lang) {
      if (lang.id.toLowerCase().contains(clean)) return true;
      if (lang.name.toLowerCase().contains(clean)) return true;
      for (final a in lang.aliases) {
        if (a.toLowerCase().contains(clean)) return true;
      }
      for (final e in lang.extensions) {
        if (e.toLowerCase().contains(clean)) return true;
      }
      return false;
    }).toList();
  }
}
