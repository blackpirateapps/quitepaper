import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/web_clipper/web_clipper_provider.dart';
import '../../../core/widgets/quiet_button.dart';
import 'browser/web_clip_browser_screen.dart';
import 'web_clip_preview_sheet.dart';

/// Modal dialog for entering or pasting a webpage URL to clip.
class WebClipDialog extends ConsumerStatefulWidget {
  const WebClipDialog({
    super.key,
    this.initialUrl,
  });

  final String? initialUrl;

  static Future<void> show(BuildContext context, {String? initialUrl}) {
    return showDialog<void>(
      context: context,
      builder: (_) => WebClipDialog(initialUrl: initialUrl),
    );
  }

  @override
  ConsumerState<WebClipDialog> createState() => _WebClipDialogState();
}

class _WebClipDialogState extends ConsumerState<WebClipDialog> {
  late TextEditingController _urlController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialUrl == null || widget.initialUrl!.isEmpty) {
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipData?.text?.trim();
      if (text != null && (text.startsWith('http://') || text.startsWith('https://'))) {
        if (mounted && _urlController.text.isEmpty) {
          setState(() {
            _urlController.text = text;
            _urlController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: text.length,
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openInBrowser([String? urlOverride]) async {
    final rawUrl = (urlOverride ?? _urlController.text).trim();
    final uri = Uri.tryParse(rawUrl);
    final targetUrl = (uri != null && (uri.isScheme('http') || uri.isScheme('https')))
        ? rawUrl
        : (rawUrl.isNotEmpty ? 'https://$rawUrl' : 'https://google.com');

    Navigator.of(context).pop();
    await WebClipBrowserScreen.open(context, initialUrl: targetUrl);
  }

  Future<void> _scanUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid webpage URL');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      setState(() => _errorMessage = 'URL must start with http:// or https://');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clipper = ref.read(webClipperServiceProvider);
      final scanResult = await clipper.scanUrl(rawUrl);

      if (mounted) {
        Navigator.of(context).pop(); // Close input dialog
        WebClipPreviewSheet.show(context, scanResult: scanResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.language_rounded,
                        color: colors.accent, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clip Webpage',
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Extract article, download images & save snapshot',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // URL Text Field
              TextField(
                controller: _urlController,
                autofocus: true,
                enabled: !_isLoading,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _scanUrl(),
                decoration: InputDecoration(
                  hintText: 'https://example.com/article',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              size: 18, color: colors.textTertiary),
                          onPressed: () {
                            setState(() {
                              _urlController.clear();
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
                ),
              ),

              // Error banner with In-App Browser suggestion
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.error_outline_rounded,
                                size: 14, color: Colors.red.shade400),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.caption.copyWith(
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: Icon(Icons.open_in_browser_rounded,
                              size: 15, color: colors.accent),
                          label: Text(
                            'Open in In-App Browser →',
                            style: AppTypography.caption.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => _openInBrowser(_urlController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading ? null : () => _openInBrowser(),
                    icon: Icon(Icons.language_rounded,
                        size: 16, color: colors.textSecondary),
                    label: Text(
                      'Browser',
                      style: AppTypography.body.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: AppTypography.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      QuietButton(
                        label: 'Continue',
                        variant: QuietButtonVariant.primary,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _scanUrl,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
