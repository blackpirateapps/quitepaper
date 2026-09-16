import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/storage/cloud_storage_models.dart';
import '../../../core/storage/cloud_storage_provider.dart';
import 'storage_management_screen.dart';

/// Screen presenting the user's authoritative cloud storage quota, plan entitlements,
/// categorized usage breakdown, and storage management entry points.
class CloudStorageScreen extends ConsumerStatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  ConsumerState<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends ConsumerState<CloudStorageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cloudStorageProvider.notifier).fetchQuota();
    });
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return 'Never';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final storageState = ref.watch(cloudStorageProvider);

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
          'Cloud Storage',
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
            child: _buildBody(context, colors, storageState),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppColors colors,
    CloudStorageState state,
  ) {
    if (state.isLoading && !state.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: colors.accent, radius: 14),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading cloud storage...',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state.hasError && !state.hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                size: 48,
                color: colors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                state.isOffline
                    ? 'Cloud storage offline'
                    : 'Unable to load cloud storage',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.isOffline
                    ? 'Unable to load storage information while offline. Your local notes and files remain safe on this device.'
                    : (state.errorMessage ?? 'An unexpected error occurred while fetching your quota.'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.btn),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                onPressed: () => ref.read(cloudStorageProvider.notifier).fetchQuota(force: true),
              ),
            ],
          ),
        ),
      );
    }

    final quota = state.quota ?? CloudStorageQuota.defaultFree();

    return RefreshIndicator(
      color: colors.accent,
      backgroundColor: colors.surface,
      onRefresh: () => ref.read(cloudStorageProvider.notifier).fetchQuota(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          if (state.isOffline || (state.hasError && state.hasData))
            _buildOfflineStaleBanner(colors, state),
          _buildUsageCard(colors, quota),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'STORAGE BREAKDOWN'),
          _buildBreakdownGroup(colors, quota),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'PLAN & LIMITS'),
          _buildPlanLimitsGroup(context, colors, quota),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'MANAGE STORAGE'),
          _buildManageStorageGroup(context, colors),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildOfflineStaleBanner(AppColors colors, CloudStorageState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(
            state.isOffline ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              state.isOffline
                  ? 'Offline • Showing cached profile (${_formatTimeAgo(state.lastFetchedAt)})'
                  : 'Storage sync pending • Last updated ${_formatTimeAgo(state.lastFetchedAt)}',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(AppColors colors, CloudStorageQuota quota) {
    final progressColor = quota.isOverQuota
        ? colors.error
        : (quota.isNearQuota ? (colors.warning) : colors.accent);

    final clampedUsage = quota.usageFraction.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cloud Storage',
                  style: AppTypography.bodySmallMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildPlanBadge(colors, quota.plan),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (quota.isOverQuota) ...[
            Text(
              quota.usedFormatted,
              style: AppTypography.display.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'of ${quota.limitFormatted} limit (${quota.overQuotaFormatted} over limit)',
              style: AppTypography.bodySmall.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Text.rich(
              TextSpan(
                style: AppTypography.display.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: quota.usedFormatted),
                  TextSpan(
                    text: ' of ${quota.limitFormatted} used',
                    style: AppTypography.title.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Cloud storage usage',
            value: '${quota.usedFormatted} of ${quota.limitFormatted} used',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: clampedUsage,
                minHeight: 10,
                backgroundColor: colors.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  quota.isOverQuota
                      ? 'Uploads paused until space is freed'
                      : '${quota.remainingFormatted} remaining',
                  style: AppTypography.bodySmall.copyWith(
                    color: quota.isOverQuota ? colors.error : colors.textSecondary,
                    fontWeight: quota.isOverQuota ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(quota.usageFraction * 100).toStringAsFixed(1)}%',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: progressColor,
                ),
              ),
            ],
          ),
          if (quota.isOverQuota) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: colors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your existing files remain safe. Free up space to resume cloud uploads.',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (quota.isNearQuota) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: colors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'You are approaching your cloud storage limit.',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanBadge(AppColors colors, StoragePlan plan) {
    final isPremium = plan == StoragePlan.premium;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPremium ? colors.accentSoft : colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: isPremium ? colors.accentLight : colors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPremium) ...[
            Icon(Icons.star_rounded, size: 14, color: colors.accent),
            const SizedBox(width: 4),
          ],
          Text(
            isPremium ? 'Premium' : 'Free',
            style: AppTypography.caption.copyWith(
              color: isPremium ? colors.accentDark : colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownGroup(AppColors colors, CloudStorageQuota quota) {
    final breakdown = quota.breakdown ?? const StorageBreakdown();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _buildBreakdownRow(
            colors: colors,
            icon: Icons.image_outlined,
            label: 'Images',
            countText: '${breakdown.imageCount} file${breakdown.imageCount == 1 ? '' : 's'}',
            sizeText: breakdown.imageFormatted,
          ),
          _buildGroupDivider(colors),
          _buildBreakdownRow(
            colors: colors,
            icon: Icons.description_outlined,
            label: 'Documents & PDFs',
            countText: '${breakdown.documentCount} file${breakdown.documentCount == 1 ? '' : 's'}',
            sizeText: breakdown.documentFormatted,
          ),
          _buildGroupDivider(colors),
          _buildBreakdownRow(
            colors: colors,
            icon: Icons.folder_open_outlined,
            label: 'Other files',
            countText: '${breakdown.otherCount} file${breakdown.otherCount == 1 ? '' : 's'}',
            sizeText: breakdown.otherFormatted,
          ),
          _buildGroupDivider(colors),
          _buildBreakdownRow(
            colors: colors,
            icon: Icons.cloud_outlined,
            label: 'Total Used',
            countText: '${breakdown.totalCount} file${breakdown.totalCount == 1 ? '' : 's'}',
            sizeText: quota.usedFormatted,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required String countText,
    required String sizeText,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isTotal ? colors.accent : colors.iconSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: (isTotal ? AppTypography.bodyMedium : AppTypography.bodySmallMedium)
                      .copyWith(
                    color: colors.textPrimary,
                    fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  countText,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            sizeText,
            style: (isTotal ? AppTypography.bodyMedium : AppTypography.bodySmallMedium)
                .copyWith(
              color: colors.textPrimary,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanLimitsGroup(
    BuildContext context,
    AppColors colors,
    CloudStorageQuota quota,
  ) {
    final isPremium = quota.isPremium;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _buildLimitRow(
            colors: colors,
            icon: Icons.cloud_done_outlined,
            label: 'Cloud Storage Limit',
            value: quota.limitFormatted,
          ),
          _buildGroupDivider(colors),
          _buildLimitRow(
            colors: colors,
            icon: Icons.upload_file_outlined,
            label: 'Max Individual File Size',
            value: quota.maxFileFormatted,
          ),
          _buildGroupDivider(colors),
          _buildLimitRow(
            colors: colors,
            icon: Icons.lock_outline_rounded,
            label: 'Zero-Knowledge Encryption',
            value: 'AES-256-GCM',
          ),
          if (!isPremium) ...[
            _buildGroupDivider(colors),
            _buildUpgradeCard(context, colors),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.iconSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmallMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(BuildContext context, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.lg),
          bottomRight: Radius.circular(AppRadii.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Need more room?',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Upgrade to Premium for 10 GB of zero-knowledge encrypted cloud storage across all your synced devices.',
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: colors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () => _showUpgradeInfoDialog(context, colors),
              icon: const Text('Learn More'),
              label: const Icon(CupertinoIcons.chevron_forward, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeInfoDialog(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: colors.accent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quiet Paper Premium',
                style: AppTypography.headline.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Premium includes:',
                style: AppTypography.bodySmallMedium.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildDialogFeature(colors, '10 GB Zero-Knowledge Encrypted Cloud Storage'),
              _buildDialogFeature(colors, 'Sync seamlessly across unlimited active devices'),
              _buildDialogFeature(colors, 'Up to 10 MB per individual note attachment/PDF'),
              _buildDialogFeature(colors, 'Automatic multi-device maintenance & garbage collection'),
              const SizedBox(height: 12),
              Text(
                'Billing integration will be available in an upcoming release. Your Free plan currently includes 1 GB of storage.',
                style: AppTypography.caption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Got it',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFeature(AppColors colors, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageStorageGroup(BuildContext context, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _buildNavigationRow(
            colors: colors,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Storage & Cleanup',
            subtitle: 'Storage breakdown, GC maintenance, and reclaimable space',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageManagementScreen(initialTab: 0),
                ),
              );
            },
          ),
          _buildGroupDivider(colors),
          _buildNavigationRow(
            colors: colors,
            icon: Icons.attachment_rounded,
            title: 'Attached Assets',
            subtitle: 'Active images & scanned documents',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageManagementScreen(initialTab: 1),
                ),
              );
            },
          ),
          _buildGroupDivider(colors),
          _buildNavigationRow(
            colors: colors,
            icon: Icons.delete_sweep_outlined,
            title: 'Orphaned Assets',
            subtitle: 'Unreferenced cloud assets pending destruction',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageManagementScreen(initialTab: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.iconPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodySmallMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 48,
      color: colors.divider,
    );
  }
}
