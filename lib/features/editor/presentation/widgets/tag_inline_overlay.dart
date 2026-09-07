import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../tags/domain/tag_model.dart';
import '../../application/tag_search_service.dart';
import 'tag_inline_menu.dart';

/// Callback invoked when a tag candidate is selected from the inline tag autocomplete overlay.
typedef TagSelectCallback = void Function(Tag tag, int replaceStart, int replaceEnd);

/// Controller and overlay manager for Notion/Bear-style inline tag autocomplete.
class TagInlineOverlayController {
  TagInlineOverlayController({
    required this.context,
    required this.searchService,
    required this.onSelectTag,
    this.onDismissed,
  });

  final BuildContext context;
  final TagSearchService searchService;
  final TagSelectCallback onSelectTag;
  final VoidCallback? onDismissed;

  OverlayEntry? _overlayEntry;
  List<Tag> _items = const [];
  int _selectedIndex = 0;
  String _currentQuery = '';
  int _triggerStart = 0;
  int _queryEnd = 0;
  Rect _caretRect = Rect.zero;
  final ScrollController _scrollController = ScrollController();

  bool get isOpen => _overlayEntry != null;
  int get totalCount => _items.length;

  /// Opens or updates the inline tag autocomplete overlay at the given [caretRect].
  void showOrUpdate({
    required String query,
    required int triggerStart,
    required int queryEnd,
    required Rect caretRect,
    required List<Tag> existingTags,
    String? currentNoteContent,
  }) {
    _currentQuery = query;
    _triggerStart = triggerStart;
    _queryEnd = queryEnd;
    _caretRect = caretRect;

    final results = searchService.searchTags(
      query: query,
      existingTags: existingTags,
      currentNoteContent: currentNoteContent,
      limit: 15,
    );

    if (results.isEmpty) {
      hide();
      return;
    }

    if (!context.mounted) return;

    _items = results;
    if (_selectedIndex >= _items.length) {
      _selectedIndex = max(0, _items.length - 1);
    }

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (ctx) => _buildOverlayWidget(ctx),
      );
      final overlay = Overlay.maybeOf(context);
      if (overlay != null) {
        overlay.insert(_overlayEntry!);
      }
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  /// Handles hardware keyboard events (ArrowUp, ArrowDown, Enter, Tab, Escape).
  /// Returns `KeyEventResult.handled` if the key was consumed by the tag autocomplete menu.
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (!isOpen || _items.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _selectedIndex = (_selectedIndex + 1) % _items.length;
      _overlayEntry?.markNeedsBuild();
      _scrollToSelected();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _selectedIndex = (_selectedIndex - 1 + _items.length) % _items.length;
      _overlayEntry?.markNeedsBuild();
      _scrollToSelected();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab) {
      confirmSelection();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      hide();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 36.0;
    final targetOffset = _selectedIndex * itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  /// Confirms the current highlighted selection.
  void confirmSelection() {
    if (!isOpen || _items.isEmpty) return;

    if (_selectedIndex < _items.length) {
      final selectedTag = _items[_selectedIndex];
      final start = _triggerStart;
      final end = _queryEnd;
      hide();
      onSelectTag(selectedTag, start, end);
    }
  }

  /// Hides and cleans up the overlay entry.
  void hide() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _items = const [];
      _selectedIndex = 0;
      onDismissed?.call();
    }
  }

  /// Disposes of any active overlay and controllers.
  void dispose() {
    hide();
    _scrollController.dispose();
  }

  Widget _buildOverlayWidget(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    const menuWidth = 280.0;
    const menuMaxHeight = 220.0;

    // Mobile layout with open keyboard: dock floating right above keyboard/toolbar
    final isMobileWithKeyboard = screenSize.width < 600 && keyboardHeight > 0;

    double? left;
    double? top;
    double? bottom;
    double effectiveWidth = menuWidth;

    if (isMobileWithKeyboard) {
      effectiveWidth = min(menuWidth, screenSize.width - 32.0);
      left = (screenSize.width - effectiveWidth) / 2.0;
      bottom = keyboardHeight + 48.0; // floating above toolbar
    } else {
      effectiveWidth = min(menuWidth, screenSize.width - 32.0);
      left = _caretRect.left.clamp(16.0, max(16.0, screenSize.width - effectiveWidth - 16.0));

      final availableBelow = screenSize.height - keyboardHeight - _caretRect.bottom - 16.0;
      if (availableBelow >= 180.0 || _caretRect.top < 180.0) {
        // Place below caret
        top = _caretRect.bottom + 4.0;
      } else {
        // Flip above caret
        bottom = screenSize.height - _caretRect.top + 4.0;
      }
    }

    return Stack(
      children: [
        // Transparent dismiss backdrop (tapping anywhere outside closes overlay without blocking editor focus)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => hide(),
          ),
        ),

        // Floating Tag Autocomplete Menu
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          child: TagInlineMenu(
            items: _items,
            selectedIndex: _selectedIndex,
            query: _currentQuery,
            width: effectiveWidth,
            maxHeight: menuMaxHeight,
            scrollController: _scrollController,
            onSelectTag: (tag) {
              final start = _triggerStart;
              final end = _queryEnd;
              hide();
              onSelectTag(tag, start, end);
            },
          ),
        ),
      ],
    );
  }
}
