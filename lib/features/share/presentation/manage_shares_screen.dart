import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../application/share_providers.dart';
import '../domain/note_share.dart';

/// Settings sub-screen listing the user's active public shares with controls to
/// change visibility, set/clear a password, or delete (unshare) each one.
class ManageSharesScreen extends ConsumerWidget {
  const ManageSharesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final sharesAsync = ref.watch(sharesListProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Shared links',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: sharesAsync.when(
              loading: () => Center(
                child: CupertinoActivityIndicator(color: colors.accent, radius: 14),
              ),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(sharesListProvider),
              ),
              data: (shares) => _buildList(context, ref, colors, shares),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    List<NoteShare> shares,
  ) {
    if (shares.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 44, color: colors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No shared links',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Share a note as a URL to see it here.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: colors.accent,
      onRefresh: () async => ref.invalidate(sharesListProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: shares.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _ShareCard(share: shares[i]),
      ),
    );
  }
}

// PLACEHOLDER_WIDGETS

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load shares',
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            QuietButton(
              label: 'Retry',
              variant: QuietButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends ConsumerWidget {
  const _ShareCard({required this.share});

  final NoteShare share;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  share.title.isNotEmpty ? share.title : 'Untitled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _VisibilityChip(visibility: share.visibility),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            share.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '${share.viewCount} views · expires in ${share.daysRemaining} days',
            style: AppTypography.caption.copyWith(color: colors.textTertiary, fontSize: 11.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: QuietButton(
                  label: 'Change visibility',
                  icon: Icons.visibility_outlined,
                  variant: QuietButtonVariant.ghost,
                  onPressed: () => _changeVisibility(context, ref),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuietButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                variant: QuietButtonVariant.destructive,
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeVisibility(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<ShareVisibility>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) => _VisibilityPicker(current: share.visibility),
    );
    if (choice == null || choice == share.visibility) return;

    String? password;
    if (choice == ShareVisibility.password) {
      if (!context.mounted) return;
      password = await _promptPassword(context);
      if (password == null || password.isEmpty) return;
    }

    final service = ref.read(shareServiceProvider);
    try {
      await service.updateShare(
        share.shareId,
        visibility: choice,
        password: password,
      );
      ref.invalidate(sharesListProvider);
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppRadii.rLg),
          ),
          title: Text(
            'Delete shared link?',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'The public page and its uploaded copies will be removed. This '
            'cannot be undone.',
            style: AppTypography.bodySmall.copyWith(color: colors.textSecondary, height: 1.4),
          ),
          actions: [
            QuietButton(
              label: 'Cancel',
              variant: QuietButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(width: AppSpacing.xs),
            QuietButton(
              label: 'Delete',
              variant: QuietButtonVariant.destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final service = ref.read(shareServiceProvider);
    try {
      await service.deleteShare(share.shareId, noteId: share.noteId);
      ref.invalidate(sharesListProvider);
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(AppRadii.rLg),
          ),
          title: Text(
            'Set page password',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
            decoration: const InputDecoration(hintText: 'Password'),
          ),
          actions: [
            QuietButton(
              label: 'Cancel',
              variant: QuietButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(width: AppSpacing.xs),
            QuietButton(
              label: 'Set',
              variant: QuietButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        );
      },
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});

  final ShareVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        visibility.label,
        style: AppTypography.caption.copyWith(
          color: colors.accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({required this.current});

  final ShareVisibility current;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          for (final v in ShareVisibility.values)
            ListTile(
              leading: Icon(
                v == ShareVisibility.public
                    ? Icons.public_rounded
                    : v == ShareVisibility.unlisted
                        ? Icons.link_off_rounded
                        : Icons.lock_outline_rounded,
                color: v == current ? colors.accent : colors.textSecondary,
              ),
              title: Text(
                v.label,
                style: AppTypography.bodyMedium.copyWith(
                  color: v == current ? colors.accent : colors.textPrimary,
                ),
              ),
              trailing: v == current
                  ? Icon(Icons.check_rounded, color: colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(v),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

