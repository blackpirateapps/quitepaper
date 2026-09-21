import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'slash_command_item.dart';
import 'slash_command_menu.dart';

typedef SlashCommandSelectCallback = void Function(
  SlashCommandItem command,
  int replaceStart,
  int replaceEnd,
);

/// Controller and overlay manager for Notion/Bear-style inline slash commands ('/').
class SlashCommandOverlayController {
  SlashCommandOverlayController({
    required this.context,
    required this.onSelectCommand,
    this.onDismissed,
  });

  final BuildContext context;
  final SlashCommandSelectCallback onSelectCommand;
  final VoidCallback? onDismissed;

  OverlayEntry? _overlayEntry;
  List<SlashCommandItem> _items = const [];
  int _selectedIndex = 0;
  String _currentQuery = '';
  int _triggerStart = 0;
  int _queryEnd = 0;
  Rect _caretRect = Rect.zero;
  final ScrollController _scrollController = ScrollController();

  bool get isOpen => _overlayEntry != null;
  int get totalCount => _items.length;
  String get currentQuery => _currentQuery;

  /// Opens or updates the slash command overlay for the given [query] at [caretRect].
  void showOrUpdate({
    required String query,
    required int triggerStart,
    required int queryEnd,
    required Rect caretRect,
  }) {
    _currentQuery = query;
    _triggerStart = triggerStart;
    _queryEnd = queryEnd;
    _caretRect = caretRect;

    final results = SlashCommandItem.all
        .where((cmd) => cmd.matches(query))
        .toList();

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
    const itemHeight = 44.0;
    final targetOffset = _selectedIndex * itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  /// Confirms the highlighted slash command.
  void confirmSelection() {
    if (!isOpen || _items.isEmpty) return;

    if (_selectedIndex < _items.length) {
      final selected = _items[_selectedIndex];
      final start = _triggerStart;
      final end = _queryEnd;
      hide();
      onSelectCommand(selected, start, end);
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

  /// Disposes of any active overlay and scroll controller.
  void dispose() {
    hide();
    _scrollController.dispose();
  }

  Widget _buildOverlayWidget(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    const menuWidth = 320.0;
    const menuMaxHeight = 280.0;

    double left = _caretRect.left;
    double top = _caretRect.bottom + 6.0;

    // Flip above caret if overflowing bottom
    if (top + menuMaxHeight > screenSize.height - 24.0) {
      top = max(16.0, _caretRect.top - menuMaxHeight - 6.0);
    }

    // Clamp horizontally to stay inside screen bounds
    left = left.clamp(16.0, max(16.0, screenSize.width - menuWidth - 16.0));

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: SlashCommandMenu(
            items: _items,
            selectedIndex: _selectedIndex,
            width: menuWidth,
            maxHeight: menuMaxHeight,
            scrollController: _scrollController,
            onSelectCommand: (cmd) {
              final start = _triggerStart;
              final end = _queryEnd;
              hide();
              onSelectCommand(cmd, start, end);
            },
          ),
        ),
      ],
    );
  }
}
