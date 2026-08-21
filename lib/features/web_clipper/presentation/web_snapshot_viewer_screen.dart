import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/documents/document_provider.dart';
import '../../../core/utils/link_launcher_helper.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';

/// Full-screen sandboxed viewer for encrypted offline Web Snapshots (`qp://document/<UUID>`).
class WebSnapshotViewerScreen extends ConsumerStatefulWidget {
  const WebSnapshotViewerScreen({
    super.key,
    required this.documentId,
    this.title = 'Web Snapshot',
    this.sourceUrl,
  });

  final String documentId;
  final String title;
  final String? sourceUrl;

  static Future<void> open(
    BuildContext context, {
    required String documentId,
    String title = 'Web Snapshot',
    String? sourceUrl,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WebSnapshotViewerScreen(
          documentId: documentId,
          title: title,
          sourceUrl: sourceUrl,
        ),
      ),
    );
  }

  @override
  ConsumerState<WebSnapshotViewerScreen> createState() =>
      _WebSnapshotViewerScreenState();
}

class _WebSnapshotViewerScreenState
    extends ConsumerState<WebSnapshotViewerScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _htmlContent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final docService = ref.read(documentServiceProvider);
      final resolution = await docService.resolveDocument(widget.documentId);

      if (!resolution.isAvailable || resolution.data == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = resolution.isLocked
                ? 'Notebook is locked. Unlock encryption to view this snapshot.'
                : 'Web snapshot document unavailable.';
          });
        }
        return;
      }

      final htmlBytes = resolution.data!.pdfBytes;
      final html = utf8.decode(htmlBytes, allowMalformed: true);

      if (mounted) {
        _htmlContent = html;
        _initWebView(html);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load web snapshot: $e';
        });
      }
    }
  }

  void _initWebView(String html) {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(JavaScriptMode.disabled);
      controller.loadHtmlString(html);
      _webViewController = controller;
    } catch (e) {
      debugPrint('WebView initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to Note',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: AppTypography.headline.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.sourceUrl != null && widget.sourceUrl!.isNotEmpty)
              Text(
                Uri.tryParse(widget.sourceUrl!)?.host.replaceFirst('www.', '') ??
                    widget.sourceUrl!,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (widget.sourceUrl != null && widget.sourceUrl!.isNotEmpty)
            QuietIconButton(
              icon: Icons.open_in_browser_rounded,
              tooltip: 'Open live URL in browser',
              onPressed: () => LinkLauncherHelper.handleLinkTap(
                context,
                widget.sourceUrl!,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Decrypting web snapshot…',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style:
                    AppTypography.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              QuietButton(
                label: 'Retry',
                onPressed: _loadSnapshot,
              ),
            ],
          ),
        ),
      );
    }

    if (_webViewController != null && !kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: WebViewWidget(controller: _webViewController!),
        ),
      );
    }

    // Fallback if WebView platform channel is unavailable
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: SelectableText(
            _htmlContent ?? '',
            style: AppTypography.body.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
