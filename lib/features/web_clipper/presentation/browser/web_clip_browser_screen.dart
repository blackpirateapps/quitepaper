import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/link_launcher_helper.dart';
import '../../../../core/web_clipper/web_capture_payload.dart';
import '../../../../core/web_clipper/web_capture_result.dart';
import '../../../../core/web_clipper/web_clipper_provider.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/domain/note_model.dart';
import '../web_clip_preview_sheet.dart';
import 'web_clip_browser_controller.dart';

/// Full-screen in-app acquisition browser allowing users to navigate legitimately,
/// interact with pages, complete ordinary verifications, and explicitly capture content into Quiet Paper.
class WebClipBrowserScreen extends ConsumerStatefulWidget {
  const WebClipBrowserScreen({
    super.key,
    required this.initialUrl,
    this.controller,
  });

  final String initialUrl;
  final WebClipBrowserController? controller;

  /// Opens the acquisition browser screen and returns the created note if clipped and saved.
  static Future<Note?> open(
    BuildContext context, {
    required String initialUrl,
  }) {
    return Navigator.of(context).push<Note?>(
      MaterialPageRoute(
        builder: (_) => WebClipBrowserScreen(initialUrl: initialUrl),
      ),
    );
  }

  @override
  ConsumerState<WebClipBrowserScreen> createState() =>
      _WebClipBrowserScreenState();
}

class _WebClipBrowserScreenState extends ConsumerState<WebClipBrowserScreen> {
  late WebClipBrowserController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = WebClipBrowserController(initialUrl: widget.initialUrl);
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleClip() async {
    final captureResult = await _controller.captureCurrentPage();

    if (!captureResult.isSuccess || captureResult.payload == null) {
      if (mounted) {
        final errorMsg = captureResult.error?.message ?? 'Failed to capture page content.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final payload = captureResult.payload!;
    final clipperService = ref.read(webClipperServiceProvider);

    try {
      final scanResult = await clipperService.scanPayload(payload, allowFallback: true);

      if (!mounted) return;

      // Launch existing WebClipPreviewSheet
      final savedNote = await showModalBottomSheet<Note?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WebClipPreviewSheet(scanResult: scanResult),
      );

      if (!mounted) return;

      if (savedNote != null) {
        // Saved successfully: pop browser with resulting note
        Navigator.of(context).pop(savedNote);
      } else {
        // Cancelled preview: return browser to ready state without reloading
        _controller.resetToReady();
      }
    } on WebAcquisitionError catch (acqError) {
      if (!mounted) return;
      _controller.resetToReady();
      _showExtractionFailureFallback(payload, acqError.message);
    } catch (e) {
      if (!mounted) return;
      _controller.resetToReady();
      _showExtractionFailureFallback(payload, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showExtractionFailureFallback(
    WebCapturePayload payload,
    String failureDetails,
  ) async {
    final colors = context.appColors;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Row(
          children: [
            Icon(Icons.article_outlined, color: colors.textSecondary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Article Extraction',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Couldn't identify a dedicated article container on this page.",
              style: AppTypography.body.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can save the page content as-is or preserve the original page as an encrypted offline snapshot.',
              style: AppTypography.caption.copyWith(color: colors.textTertiary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          QuietButton(
            label: 'Save Offline Snapshot',
            variant: QuietButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop('snapshot'),
          ),
          QuietButton(
            label: 'Use Page Content',
            variant: QuietButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop('pageContent'),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;

    final clipperService = ref.read(webClipperServiceProvider);

    if (action == 'pageContent') {
      try {
        final scanResult = await clipperService.scanPayload(payload, allowFallback: true);
        if (!mounted) return;
        final savedNote = await showModalBottomSheet<Note?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => WebClipPreviewSheet(scanResult: scanResult),
        );
        if (mounted && savedNote != null) {
          Navigator.of(context).pop(savedNote);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process page content: $e'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (action == 'snapshot') {
      try {
        final scanResult = await clipperService.scanPayload(payload, allowFallback: true);
        if (!mounted) return;
        final savedNote = await showModalBottomSheet<Note?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => WebClipPreviewSheet(
            scanResult: scanResult.copyWith(isPageContentFallback: true),
          ),
        );
        if (mounted && savedNote != null) {
          Navigator.of(context).pop(savedNote);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save snapshot: $e'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showUrlEditDialog() {
    final colors = context.appColors;
    final textController = TextEditingController(text: _controller.state.currentUrl);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          'Navigate to URL',
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'https://example.com',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.background,
            border: OutlineInputBorder(
              borderRadius: AppRadii.borderMd,
              borderSide: BorderSide(color: colors.divider),
            ),
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            _controller.navigateTo(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          QuietButton(
            label: 'Go',
            variant: QuietButtonVariant.primary,
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.navigateTo(textController.text);
            },
          ),
        ],
      ),
    );
  }

  void _showPageInfoDialog() {
    final colors = context.appColors;
    final state = _controller.state;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Page Info',
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Domain', state.domain, colors),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Title', state.pageTitle.isNotEmpty ? state.pageTitle : '—', colors),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Security', state.isSecure ? 'HTTPS (Encrypted)' : 'HTTP (Unencrypted)', colors),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Status', state.loadingState.name, colors),
          ],
        ),
        actions: [
          QuietButton(
            label: 'Close',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: AppTypography.body.copyWith(
            color: colors.textPrimary,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: QuietIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: InkWell(
              onTap: _showUrlEditDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isSecure)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: colors.textTertiary,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            state.domain,
                            style: AppTypography.headline.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (state.pageTitle.isNotEmpty)
                      Text(
                        state.pageTitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              // History Back
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                tooltip: 'Back in history',
                color: state.canGoBack ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.4),
                onPressed: state.canGoBack ? _controller.goBack : null,
              ),
              // History Forward
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                tooltip: 'Forward in history',
                color: state.canGoForward ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.4),
                onPressed: state.canGoForward ? _controller.goForward : null,
              ),
              // Reload
              QuietIconButton(
                icon: state.isLoading ? Icons.close_rounded : Icons.refresh_rounded,
                tooltip: state.isLoading ? 'Stop loading' : 'Reload',
                onPressed: () => _controller.reload(),
              ),
              // Overflow Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
                color: colors.surface,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
                onSelected: (val) {
                  switch (val) {
                    case 'reload':
                      _controller.reload();
                      break;
                    case 'external':
                      LinkLauncherHelper.handleLinkTap(context, state.currentUrl);
                      break;
                    case 'copy':
                      Clipboard.setData(ClipboardData(text: state.currentUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      break;
                    case 'info':
                      _showPageInfoDialog();
                      break;
                    case 'close':
                      Navigator.of(context).pop();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reload',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Reload'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'external',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('External Browser'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Copy URL'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Page Info'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Close Browser'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            bottom: state.isLoading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(2.0),
                    child: LinearProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      backgroundColor: Colors.transparent,
                      color: colors.accent,
                      minHeight: 2.0,
                    ),
                  )
                : null,
          ),
          body: Column(
            children: [
              // Main WebView area
              Expanded(
                child: _buildWebViewArea(colors, state),
              ),

              // Bottom Acquisition & Clip Bar
              _buildBottomClipBar(colors, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebViewArea(AppColors colors, WebClipBrowserState state) {
    if (state.loadingState == BrowserLoadingState.error && state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                "This page couldn't be loaded.",
                style: AppTypography.title.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.errorMessage!,
                style: AppTypography.caption.copyWith(color: colors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuietButton(
                    label: 'Try Again',
                    variant: QuietButtonVariant.primary,
                    onPressed: () => _controller.reload(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  QuietButton(
                    label: 'Clip Anyway',
                    variant: QuietButtonVariant.secondary,
                    onPressed: _handleClip,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.webViewController != null && !kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: WebViewWidget(controller: _controller.webViewController!),
        ),
      );
    }

    // Fallback in test / web environments
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 40, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Acquisition Browser: ${state.currentUrl}',
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomClipBar(AppColors colors, WebClipBrowserState state) {
    final isCapturing = state.isCapturingOrProcessing;

    String buttonLabel = 'Clip';
    QuietButtonVariant variant = QuietButtonVariant.primary;
    VoidCallback? onPressed = _handleClip;

    if (isCapturing) {
      buttonLabel = state.statusMessage ?? 'Capturing…';
      onPressed = null;
    } else if (state.isLoading) {
      if (state.isTakingLong) {
        buttonLabel = 'Clip Anyway';
        variant = QuietButtonVariant.primary;
        onPressed = _handleClip;
      } else {
        buttonLabel = 'Loading…';
        onPressed = null;
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm + 2,
        bottom: MediaQuery.of(context).padding.bottom + (AppSpacing.sm + 2),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            children: [
              // Status Cue
              Expanded(
                child: Text(
                  state.isCapturingOrProcessing
                      ? (state.statusMessage ?? 'Processing article…')
                      : (state.isLoading
                          ? 'Waiting for page to load…'
                          : 'Ready to clip content'),
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Main Clip Action Button
              QuietButton(
                label: buttonLabel,
                variant: variant,
                isLoading: isCapturing,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
