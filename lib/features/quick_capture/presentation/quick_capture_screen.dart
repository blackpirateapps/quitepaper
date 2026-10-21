import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/database/app_database.dart';
import '../../web_clipper/presentation/web_clip_dialog.dart';
import '../application/capture_navigation_helper.dart';
import '../application/quick_capture_controller.dart';
import '../application/quick_capture_normalizer.dart';
import '../domain/quick_capture_payload.dart';

/// Lightweight, distraction-free Quick Capture screen.
/// Implements immediate keyboard focus, warm editorial aesthetics,
/// debounced draft persistence, and source-aware navigation return.
class QuickCaptureScreen extends ConsumerStatefulWidget {
  const QuickCaptureScreen({
    super.key,
    required this.payload,
  });

  final QuickCapturePayload payload;

  static Route<void> route(QuickCapturePayload payload) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/quick_capture'),
      builder: (_) => QuickCaptureScreen(payload: payload),
    );
  }

  @override
  ConsumerState<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends ConsumerState<QuickCaptureScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _hasRequestedInitialFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController = TextEditingController(text: widget.payload.initialContent);
    _focusNode = FocusNode();

    // Preserve cursor at end or initial position
    if (widget.payload.initialContent.isNotEmpty) {
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.payload.cursorPosition.clamp(0, widget.payload.initialContent.length)),
      );
    }

    _textController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasRequestedInitialFocus) {
        _hasRequestedInitialFocus = true;
        _focusNode.requestFocus();
      }
    });
  }

  void _onTextChanged() {
    ref
        .read(quickCaptureControllerProvider(widget.payload).notifier)
        .updateContent(_textController.text, cursor: _textController.selection.baseOffset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref
          .read(quickCaptureControllerProvider(widget.payload).notifier)
          .flushDraft();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final controller =
        ref.read(quickCaptureControllerProvider(widget.payload).notifier);
    final success = await controller.save();
    if (success && mounted) {
      await CaptureNavigationHelper.closeCapture(
        context,
        origin: widget.payload.origin,
      );
    }
  }

  Future<void> _handleClose() async {
    final state = ref.read(quickCaptureControllerProvider(widget.payload));
    final controller =
        ref.read(quickCaptureControllerProvider(widget.payload).notifier);

    if (!state.isEmpty && !state.isSaved) {
      await controller.flushDraft();
    }

    if (mounted) {
      await CaptureNavigationHelper.closeCapture(
        context,
        origin: widget.payload.origin,
      );
    }
  }

  void _showDraftsSheet(List<QuickCaptureDraftEntity> drafts) {
    final colors = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unfinished Captures',
                      style: AppTypography.headline.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.iconSecondary, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: colors.divider),
                    itemBuilder: (_, index) {
                      final draft = drafts[index];
                      final snippet = draft.content.trim().split('\n').first;
                      final displaySnippet = snippet.length > 60 ? '${snippet.substring(0, 57)}...' : snippet;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          displaySnippet.isEmpty ? '(Empty draft)' : displaySnippet,
                          style: AppTypography.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Source: ${draft.source} • ${_formatRelative(draft.updatedAt)}',
                          style: AppTypography.caption.copyWith(color: colors.textTertiary),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: colors.iconMuted, size: 20),
                          onPressed: () async {
                            await ref
                                .read(quickCaptureControllerProvider(widget.payload).notifier)
                                .discardDraft(draft.id);
                            if (drafts.length <= 1 && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                        ),
                        onTap: () {
                          ref
                              .read(quickCaptureControllerProvider(widget.payload).notifier)
                              .resumeDraft(draft);
                          _textController.text = draft.content;
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: draft.cursorPosition.clamp(0, draft.content.length)),
                          );
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final state = ref.watch(quickCaptureControllerProvider(widget.payload));

    final detectedUrl = widget.payload.sourceUrl ??
        QuickCaptureNormalizer.extractUrl(_textController.text);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Bar: [✕ Quick Capture] ... [Save]
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Close icon + Title
                        Flexible(
                          child: InkWell(
                            onTap: _handleClose,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    color: colors.textPrimary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Quick Capture',
                                      style: AppTypography.headline.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right: Coral Save button
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: state.canSave ? 1.0 : 0.45,
                          child: Material(
                            color: colors.accent,
                            borderRadius: AppRadii.borderMd,
                            elevation: 0,
                            child: InkWell(
                              onTap: state.canSave ? _handleSave : null,
                              borderRadius: AppRadii.borderMd,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                child: state.isSaving
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Save',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider below top bar
                  Divider(height: 1, thickness: 1, color: colors.divider),

                  // Optional notifications/banners
                  if (state.errorMessage != null)
                    Container(
                      color: colors.error.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: AppTypography.caption.copyWith(color: colors.error),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (state.incomingPendingPayload != null)
                    Container(
                      color: colors.accent.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.share_arrival_time_outlined, color: colors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'New shared content received',
                              style: AppTypography.caption.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(quickCaptureControllerProvider(widget.payload).notifier)
                                  .acceptIncomingPendingShare();
                              _textController.text =
                                  state.incomingPendingPayload!.initialContent;
                            },
                            child: const Text('Switch'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              ref
                                  .read(quickCaptureControllerProvider(widget.payload).notifier)
                                  .dismissIncomingPendingShare();
                            },
                          ),
                        ],
                      ),
                    ),

                  // 2. Main Editing Surface
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Editorial Heading: "What's on your mind?"
                          Text(
                            "What's on your mind?",
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Multiline Text Input
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              textAlignVertical: TextAlignVertical.top,
                              cursorColor: colors.accent,
                              cursorWidth: 2.2,
                              cursorRadius: const Radius.circular(2),
                              style: AppTypography.body.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                                height: 1.6,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText:
                                    'The idea goes here. Start typing immediately, without a title or any extra setup.',
                                hintStyle: AppTypography.body.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 17,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Optional Action Bar: Clip full article / Resume draft
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (detectedUrl != null && detectedUrl.isNotEmpty) ...[
                            InkWell(
                              onTap: () {
                                WebClipDialog.show(context, initialUrl: detectedUrl);
                              },
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language_rounded, size: 15, color: colors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clip full article',
                                      style: AppTypography.caption.copyWith(
                                        color: colors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (state.availableDrafts.isNotEmpty) ...[
                            InkWell(
                              onTap: () => _showDraftsSheet(state.availableDrafts),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.history_rounded, size: 15, color: colors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Resume unfinished capture (${state.availableDrafts.length})',
                                      style: AppTypography.caption.copyWith(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 4. Footer: [Lock icon] Saved on your device first
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Saved on your device first',
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
