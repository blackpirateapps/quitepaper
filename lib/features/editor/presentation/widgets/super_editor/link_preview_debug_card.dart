import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/utils/link_launcher_helper.dart';
import '../../../../../core/web_clipper/link_fetch_diagnostics.dart';

/// A diagnostic card rendered in Super Editor when link preview fetching fails,
/// providing detailed failure reasons, technical telemetry, and action affordances
/// (Retry, Copy Debug Info, Convert to Plain Link).
class LinkPreviewDebugCard extends StatefulWidget {
  const LinkPreviewDebugCard({
    super.key,
    required this.diagnostics,
    this.onRetry,
    this.onConvertToLink,
    this.onRemove,
  });

  final LinkFetchDiagnostics diagnostics;
  final VoidCallback? onRetry;
  final VoidCallback? onConvertToLink;
  final VoidCallback? onRemove;

  @override
  State<LinkPreviewDebugCard> createState() => _LinkPreviewDebugCardState();
}

class _LinkPreviewDebugCardState extends State<LinkPreviewDebugCard> {
  bool _expanded = false;

  void _copyDiagnostics(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.diagnostics.toFormattedReport()));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link preview diagnostics copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final d = widget.diagnostics;
    final domain = LinkLauncherHelper.extractDomain(d.url) ?? d.url;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.6),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Icon, domain, and expand toggle
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: colors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Link Preview Fetch Failed — $domain',
                  style: AppTypography.bodySmallMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Less' : 'Details',
                        style: AppTypography.caption.copyWith(
                          color: colors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Diagnostic chip badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(
                label: 'Stage: ${d.stage.displayLabel}',
                colors: colors,
              ),
              if (d.httpStatusCode != null)
                _buildBadge(
                  label: 'HTTP ${d.httpStatusCode}${d.httpStatusReason != null ? " ${d.httpStatusReason}" : ""}',
                  colors: colors,
                  isError: d.httpStatusCode! >= 400,
                ),
              if (d.duration != null)
                _buildBadge(
                  label: '${d.duration!.inMilliseconds}ms',
                  colors: colors,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // High-level explanation
          Text(
            d.reason,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),

          // Expanded technical breakdown
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: colors.divider, width: 0.6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('URL', d.url, colors),
                  if (d.contentType != null)
                    _buildDetailRow('Content-Type', d.contentType!, colors),
                  if (d.resolvedRedirectUri != null && d.resolvedRedirectUri != d.url)
                    _buildDetailRow('Redirected To', d.resolvedRedirectUri!, colors),
                  if (d.rawException != null)
                    _buildDetailRow('Exception', d.rawException!, colors),
                  if (d.leadImageUrl != null)
                    _buildDetailRow('Lead Image', d.leadImageUrl!, colors),
                  if (d.leadImageError != null)
                    _buildDetailRow('Image Error', d.leadImageError!, colors),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Actions Row
          Row(
            children: [
              if (widget.onRetry != null)
                TextButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.accent,
                    textStyle: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _copyDiagnostics(context),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Info'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.textSecondary,
                  textStyle: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              if (widget.onConvertToLink != null)
                TextButton.icon(
                  onPressed: widget.onConvertToLink,
                  icon: const Icon(Icons.link_rounded, size: 14),
                  label: const Text('Plain Link'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.textSecondary,
                    textStyle: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  tooltip: 'Remove preview',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.textTertiary,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required AppColors colors,
    bool isError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isError
            ? colors.error.withValues(alpha: 0.12)
            : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isError
              ? colors.error.withValues(alpha: 0.3)
              : colors.divider,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: isError ? colors.error : colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              '$label:',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: colors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
