import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../core/web_clipper/link_title_fetcher.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';

/// Compact, editorial icon button displayed next to hyperlinks allowing the user
/// to manually trigger link enhancement (fetching webpage/OG title and updating
/// display text in-place).
class LinkEnhanceButton extends StatefulWidget {
  const LinkEnhanceButton({
    super.key,
    required this.url,
    this.onEnhanced,
    this.onTap,
    this.enabled = true,
    this.size = 14.0,
    this.tooltip = 'Enhance link title',
    this.titleFetcher,
  });

  /// The target web URL to enhance.
  final String url;

  /// Callback invoked with the fetched title when enhancement succeeds.
  final Future<void> Function(String title)? onEnhanced;

  /// Custom tap override if the parent manages the fetch directly.
  final Future<void> Function()? onTap;

  /// Whether the button is interactive.
  final bool enabled;

  /// Icon size in logical pixels.
  final double size;

  /// Tooltip message.
  final String tooltip;

  /// Optional custom title fetcher (useful for dependency injection in tests).
  final LinkTitleFetcher? titleFetcher;

  @override
  State<LinkEnhanceButton> createState() => _LinkEnhanceButtonState();
}

class _LinkEnhanceButtonState extends State<LinkEnhanceButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (!widget.enabled || _isLoading) return;

    if (widget.onTap != null) {
      setState(() => _isLoading = true);
      try {
        await widget.onTap!();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fetcher = widget.titleFetcher ?? LinkTitleFetcher();
      final title = await fetcher.fetchTitle(widget.url);
      if (!mounted) return;

      if (title != null && title.isNotEmpty) {
        if (widget.onEnhanced != null) {
          await widget.onEnhanced!(title);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Enhanced link: "$title"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not fetch title for link'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch link title'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final childWidget = _isLoading
        ? SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          )
        : Icon(
            PhosphorIconsRegular.sparkle,
            size: widget.size,
            color: colors.accent,
          );

    return Semantics(
      button: widget.enabled,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            borderRadius: AppRadii.borderSm,
            onTap: widget.enabled && !_isLoading ? _handleTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
              child: childWidget,
            ),
          ),
        ),
      ),
    );
  }
}
