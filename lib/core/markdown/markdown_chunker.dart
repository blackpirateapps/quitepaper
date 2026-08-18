abstract final class MarkdownChunker {
  /// Splits markdown text into chunks for lazy / virtualized rendering.
  /// Preserves block boundaries (code fences, tables, blockquotes, lists)
  /// while splitting large documents into smaller chunks of ~1000-2000 characters.
  static List<String> split(String markdown, {int targetChunkChars = 1200}) {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final lines = markdown.split('\n');
    final chunks = <String>[];
    final currentLines = <String>[];
    int currentChars = 0;

    bool inCodeFence = false;
    String codeFenceMarker = '';
    bool inTable = false;
    bool inList = false;
    bool inBlockquote = false;

    void flushChunk() {
      if (currentLines.isNotEmpty) {
        final chunkText = currentLines.join('\n');
        if (chunkText.trim().isNotEmpty) {
          chunks.add(chunkText);
        }
        currentLines.clear();
        currentChars = 0;
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // 1. Code fence detection (``` or ~~~)
      if (trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~')) {
        final marker = trimmedLine.substring(0, 3);
        if (!inCodeFence) {
          if (currentChars >= targetChunkChars) {
            flushChunk();
          }
          inCodeFence = true;
          codeFenceMarker = marker;
          currentLines.add(line);
          currentChars += line.length + 1;
          continue;
        } else if (trimmedLine.startsWith(codeFenceMarker)) {
          inCodeFence = false;
          codeFenceMarker = '';
          currentLines.add(line);
          currentChars += line.length + 1;
          if (currentChars >= targetChunkChars) {
            flushChunk();
          }
          continue;
        }
      }

      if (inCodeFence) {
        currentLines.add(line);
        currentChars += line.length + 1;
        // If an unclosed code block is abnormally huge, safely flush
        if (currentChars >= targetChunkChars * 4) {
          currentLines.add('```');
          flushChunk();
          currentLines.add('```');
          currentChars = 4;
        }
        continue;
      }

      // 2. Table detection (| ... |)
      final isTableRow = trimmedLine.startsWith('|') ||
          (trimmedLine.endsWith('|') && trimmedLine.contains('|'));

      if (isTableRow) {
        if (!inTable) {
          if (currentChars >= targetChunkChars) {
            flushChunk();
          }
          inTable = true;
        }
        currentLines.add(line);
        currentChars += line.length + 1;
        continue;
      } else if (inTable) {
        inTable = false;
        if (currentChars >= targetChunkChars) {
          flushChunk();
        }
      }

      // 3. List detection
      final isListItem = _isListItem(trimmedLine);
      if (isListItem) {
        if (!inList && currentChars >= targetChunkChars) {
          flushChunk();
        }
        inList = true;
        currentLines.add(line);
        currentChars += line.length + 1;
        continue;
      } else if (inList) {
        if (line.startsWith('  ') || line.startsWith('\t')) {
          // Indented list continuation
          currentLines.add(line);
          currentChars += line.length + 1;
          continue;
        } else {
          inList = false;
          if (currentChars >= targetChunkChars) {
            flushChunk();
          }
        }
      }

      // 4. Blockquote detection (> ...)
      final isBlockquote = trimmedLine.startsWith('>');
      if (isBlockquote) {
        if (!inBlockquote && currentChars >= targetChunkChars) {
          flushChunk();
        }
        inBlockquote = true;
        currentLines.add(line);
        currentChars += line.length + 1;
        continue;
      } else if (inBlockquote) {
        inBlockquote = false;
        if (currentChars >= targetChunkChars) {
          flushChunk();
        }
      }

      // 5. Blank line: standard paragraph boundary
      if (trimmedLine.isEmpty) {
        if (currentLines.isNotEmpty) {
          currentLines.add(line);
          currentChars += line.length + 1;
          if (currentChars >= targetChunkChars) {
            flushChunk();
          }
        }
        continue;
      }

      // 6. Heading line (# Heading)
      if (trimmedLine.startsWith('#')) {
        if (currentChars >= targetChunkChars ~/ 2) {
          flushChunk();
        }
      }

      // 7. Extremely long single line handling
      if (line.length > targetChunkChars * 2) {
        if (currentLines.isNotEmpty) {
          flushChunk();
        }
        final subLines = _splitLongLine(line, targetChunkChars);
        for (final sub in subLines) {
          chunks.add(sub);
        }
        continue;
      }

      currentLines.add(line);
      currentChars += line.length + 1;

      if (currentChars >= targetChunkChars * 2) {
        flushChunk();
      }
    }

    flushChunk();

    return chunks.isEmpty ? (trimmed.isEmpty ? const [] : [markdown]) : chunks;
  }

  static bool _isListItem(String trimmed) {
    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ')) {
      return true;
    }
    final match = RegExp(r'^\d+\.\s').firstMatch(trimmed);
    return match != null;
  }

  static List<String> _splitLongLine(String line, int targetChunkChars) {
    final result = <String>[];
    int start = 0;
    while (start < line.length) {
      int end = start + targetChunkChars;
      if (end >= line.length) {
        final remaining = line.substring(start).trim();
        if (remaining.isNotEmpty) {
          result.add(remaining);
        }
        break;
      }

      int breakIndex = -1;
      for (int i = end; i > start + (targetChunkChars ~/ 2); i--) {
        final c = line[i];
        if (c == '.' || c == '!' || c == '?' || c == ' ') {
          breakIndex = i + 1;
          break;
        }
      }

      if (breakIndex == -1) {
        breakIndex = end;
      }

      final chunk = line.substring(start, breakIndex).trim();
      if (chunk.isNotEmpty) {
        result.add(chunk);
      }
      start = breakIndex;
    }
    return result;
  }
}
