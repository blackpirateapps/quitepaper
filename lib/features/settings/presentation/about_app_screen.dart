import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/utils/link_launcher_helper.dart';
import 'package:quitepaper/core/version/app_version_provider.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'widgets/settings_shared_widgets.dart';

/// Detailed "About" screen presenting author hero media, app vision, and resources.
class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  static const String authorUrl = 'https://blackpiratex.com';
  static const String authorBlogUrl = 'https://blackpiratex.com/blog';
  static const String githubRepoUrl =
      'https://github.com/blackpirateapps/quitepaper';
  static const String privacyPolicyUrl =
      'https://quitepaper.vercel.app/privacy.html';
  static const String termsOfServiceUrl =
      'https://quitepaper.vercel.app/terms.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final appVersionInfo = ref.watch(appVersionInfoProvider);
    final baseUrl = ref.watch(syncApiClientProvider).baseUrl;
    final imageUrl = '$baseUrl/images/DSC01473-3.jpg';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About Quiet Paper',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // ==========================================
                // Author Hero Card
                // ==========================================
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Author Hero Image (Served from Backend)
                      SizedBox(
                        height: 280,
                        width: double.infinity,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            final total = loadingProgress.expectedTotalBytes;
                            final loaded =
                                loadingProgress.cumulativeBytesLoaded;
                            return Container(
                              color: colors.surfaceElevated,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CupertinoActivityIndicator(radius: 12),
                                    if (total != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        '${((loaded / total) * 100).toInt()}%',
                                        style: AppTypography.caption.copyWith(
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: colors.surfaceElevated,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 56,
                                      color: colors.textTertiary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sudip Mandal',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Author Info & Attribution
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Designed and developed by Sudip Mandal',
                              style: AppTypography.headline.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18.0,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            InkWell(
                              onTap: () => LinkLauncherHelper.handleLinkTap(
                                context,
                                authorUrl,
                              ),
                              borderRadius: BorderRadius.circular(4.0),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.language_rounded,
                                      size: 15,
                                      color: colors.accent,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      'blackpiratex.com',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: colors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Icon(
                                      Icons.arrow_outward_rounded,
                                      size: 13,
                                      color: colors.accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // App Overview & Description
                // ==========================================
                buildSectionHeader(context, 'About Quiet Paper'),
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: colors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quiet Paper',
                                  style: AppTypography.title.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18.0,
                                  ),
                                ),
                                Text(
                                  '${appVersionInfo.displayVersion} • Offline-First',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A calm, distraction-free writing environment built for clarity, speed, and privacy. Inspired by the warm editorial feel of traditional notebooks and deliberate typography, Quiet Paper provides a sanctuary for your thoughts and creative work.',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Everything you write remains private by default. Notes and attachments are stored locally in a high-performance SQLite database on your device, remaining fast and operable without network connectivity.',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'When cloud sync is enabled, all note content and attachments are protected with zero-knowledge end-to-end encryption using Argon2id key derivation and XChaCha20-Poly1305 AEAD cipher envelopes before leaving your device. The cloud server and database are crypto-blind and never possess your plaintext content or master keys.',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Links & Resources
                // ==========================================
                buildSectionHeader(context, 'Links & Resources'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.article_outlined,
                      title: 'Author Blog',
                      subtitle: 'Articles, essays, and engineering notes',
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                      onTap: () => LinkLauncherHelper.handleLinkTap(
                        context,
                        authorBlogUrl,
                      ),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.language_rounded,
                      title: 'Author Website',
                      subtitle: 'blackpiratex.com',
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                      onTap: () => LinkLauncherHelper.handleLinkTap(
                        context,
                        authorUrl,
                      ),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.code_rounded,
                      title: 'GitHub Repository',
                      subtitle: 'blackpirateapps/quitepaper',
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                      onTap: () => LinkLauncherHelper.handleLinkTap(
                        context,
                        githubRepoUrl,
                      ),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => LinkLauncherHelper.handleLinkTap(
                        context,
                        termsOfServiceUrl,
                      ),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => LinkLauncherHelper.handleLinkTap(
                        context,
                        privacyPolicyUrl,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
