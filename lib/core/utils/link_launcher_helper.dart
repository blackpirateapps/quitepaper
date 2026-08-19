import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../widgets/quiet_button.dart';

abstract final class LinkLauncherHelper {
  static const String _trustedDomainsKey = 'trusted_domains';

  /// Extracts normalized domain (host) from a URL string.
  static String? extractDomain(String urlString) {
    var raw = urlString.trim();
    if (raw.isEmpty) return null;

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }

    try {
      final uri = Uri.parse(raw);
      if (uri.host.isNotEmpty) {
        return uri.host.toLowerCase();
      }
    } catch (_) {}
    return null;
  }

  /// Checks if a domain is saved in trusted domains list.
  static Future<bool> isDomainTrusted(String domain) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_trustedDomainsKey) ?? [];
      return list.contains(domain.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Adds a domain to the trusted domains list.
  static Future<void> trustDomain(String domain) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_trustedDomainsKey) ?? [];
      final normalized = domain.toLowerCase();
      if (!list.contains(normalized)) {
        list.add(normalized);
        await prefs.setStringList(_trustedDomainsKey, list);
      }
    } catch (_) {}
  }

  /// Handles clicking a link in markdown or frontmatter.
  /// If the domain is trusted, opens immediately in the browser.
  /// Otherwise, prompts the user with a confirmation dialog.
  static Future<void> handleLinkTap(BuildContext context, String urlString) async {
    var rawUrl = urlString.trim();
    if (rawUrl.isEmpty) return;

    // Internal Quiet Paper URIs (qp://asset/... or qp://note/...) are application resources
    // and must never be treated as external URLs or routed to the external browser.
    if (rawUrl.toLowerCase().startsWith('qp://')) {
      return;
    }

    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://') && !rawUrl.startsWith('mailto:')) {
      rawUrl = 'https://$rawUrl';
    }

    final domain = extractDomain(rawUrl);

    if (domain != null && await isDomainTrusted(domain)) {
      if (context.mounted) {
        await _openUrl(context, rawUrl);
      }
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => LinkConfirmationDialog(
        url: rawUrl,
        domain: domain ?? rawUrl,
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $urlString'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// A clean, warm editorial modal asking the user to confirm opening an external link.
/// Displays the full URL with safe wrapping and an option to trust the domain.
class LinkConfirmationDialog extends StatefulWidget {
  const LinkConfirmationDialog({
    super.key,
    required this.url,
    required this.domain,
  });

  final String url;
  final String domain;

  @override
  State<LinkConfirmationDialog> createState() => _LinkConfirmationDialogState();
}

class _LinkConfirmationDialogState extends State<LinkConfirmationDialog> {
  bool _trustDomain = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.tagBackground,
                      borderRadius: AppRadii.borderMd,
                    ),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      color: colors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open External Link?',
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'You are leaving Quiet Paper to open a web page.',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Full URL display container (scrollable and selectable for long URLs)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(color: colors.divider),
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SelectableText(
                    widget.url,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textPrimary,
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Trust domain checkbox
              InkWell(
                borderRadius: AppRadii.borderSm,
                onTap: () {
                  setState(() {
                    _trustDomain = !_trustDomain;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _trustDomain,
                          activeColor: colors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _trustDomain = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Trust links from ${widget.domain} in the future',
                          style: AppTypography.bodySmallMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions: Cancel & Open Link
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  QuietButton(
                    label: 'Cancel',
                    variant: QuietButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  QuietButton(
                    label: 'Open Link',
                    icon: Icons.open_in_new_rounded,
                    variant: QuietButtonVariant.primary,
                    onPressed: () async {
                      if (_trustDomain) {
                        await LinkLauncherHelper.trustDomain(widget.domain);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        await LinkLauncherHelper._openUrl(context, widget.url);
                      }
                    },
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
