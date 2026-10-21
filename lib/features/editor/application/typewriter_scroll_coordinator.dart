import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Coordinates typewriter scrolling across Quiet Paper's editor surfaces.
///
/// Ensures the active cursor line remains vertically centered (~45% from the top
/// of the visible viewport) as the user types, preventing the caret from resting
/// against the bottom screen edge or software keyboard.
class TypewriterScrollCoordinator {
  TypewriterScrollCoordinator({
    required this.scrollController,
    required this.viewportKey,
    this.targetFraction = 0.45,
    this.isEnabled = _defaultEnabled,
  });

  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final double targetFraction;
  final bool Function() isEnabled;

  static bool _defaultEnabled() => true;

  bool _isScheduled = false;
  Offset? _pendingCustomCaretPos;
  FocusNode? _pendingActiveFocusNode;

  /// Notifies the coordinator of typing or editing activity.
  ///
  /// Schedules a post-frame alignment so that text layout metrics and caret
  /// coordinates are accurate following the widget rebuild.
  void onTypingActivity({
    Offset? customGlobalCaretPos,
    FocusNode? activeFocusNode,
  }) {
    if (!isEnabled()) return;
    if (customGlobalCaretPos != null) _pendingCustomCaretPos = customGlobalCaretPos;
    if (activeFocusNode != null) _pendingActiveFocusNode = activeFocusNode;

    if (_isScheduled) return;

    _isScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScheduled = false;
      final pos = _pendingCustomCaretPos;
      final fn = _pendingActiveFocusNode;
      _pendingCustomCaretPos = null;
      _pendingActiveFocusNode = null;

      alignCaretToTarget(
        customGlobalCaretPos: pos,
        activeFocusNode: fn,
      );
    });
  }

  /// Calculates the delta between the active caret position and the target
  /// waterline (45% from viewport top), and smoothly animates the scroll position.
  void alignCaretToTarget({
    Offset? customGlobalCaretPos,
    FocusNode? activeFocusNode,
    bool animated = true,
  }) {
    if (!isEnabled()) return;
    if (!scrollController.hasClients) return;

    // Do not disrupt manual touch dragging or mouse wheel inertia scrolling
    if (scrollController.position.isScrollingNotifier.value) return;

    final viewportContext = viewportKey.currentContext ??
        scrollController.position.context.notificationContext;
    if (viewportContext == null) return;

    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportHeight = viewportBox.size.height;
    if (viewportHeight <= 0) return;

    final targetGlobalY = viewportTop + (viewportHeight * targetFraction);
    final caretGlobalY = customGlobalCaretPos?.dy ?? _findActiveCaretGlobalY(activeFocusNode);
    if (caretGlobalY == null) return;

    final dy = caretGlobalY - targetGlobalY;
    if (dy.abs() < 2.0) return; // Already aligned within tolerance

    final currentOffset = scrollController.offset;
    final minOffset = scrollController.position.minScrollExtent;
    final maxOffset = scrollController.position.maxScrollExtent;

    final targetOffset = (currentOffset + dy).clamp(minOffset, maxOffset);
    if ((targetOffset - currentOffset).abs() < 1.0) return;

    if (animated) {
      scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    } else {
      scrollController.jumpTo(targetOffset);
    }
  }

  /// Traverses from [focusNode] to find the active [RenderEditable] and extract
  /// its caret position in global screen coordinates.
  static double? _findActiveCaretGlobalY(FocusNode? focusNode) {
    if (focusNode == null || !focusNode.hasFocus) return null;
    final context = focusNode.context;
    if (context == null) return null;

    final renderEditable = findRenderEditable(context);
    if (renderEditable == null || !renderEditable.hasSize) return null;

    final selection = renderEditable.selection;
    if (selection == null || !selection.isValid) return null;

    final localRect = renderEditable.getLocalRectForCaret(
      TextPosition(offset: selection.extentOffset),
    );
    return renderEditable.localToGlobal(localRect.center).dy;
  }

  /// Locates the nearest descendant [RenderEditable] in the widget tree.
  static RenderEditable? findRenderEditable(BuildContext context) {
    RenderEditable? result;
    void visitor(RenderObject child) {
      if (child is RenderEditable) {
        result = child;
        return;
      }
      child.visitChildren(visitor);
    }

    final ro = context.findRenderObject();
    if (ro is RenderEditable) return ro;
    ro?.visitChildren(visitor);
    return result;
  }
}
