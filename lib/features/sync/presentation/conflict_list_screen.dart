import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/sync/conflict/conflict_model.dart';
import '../../../../core/sync/conflict/merge_result.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import 'conflict_resolution_screen.dart';

class ConflictListScreen extends ConsumerWidget {
  const ConflictListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final conflictsAsync = ref.watch(pendingConflictsStreamProvider);

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
          'Sync Conflicts',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          QuietIconButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sync Now',
            onPressed: () => ref.read(syncEngineProvider).syncNow(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: conflictsAsync.when(
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 32,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No Sync Conflicts',
                      style: AppTypography.headline.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'All your notes are up to date and merged cleanly across all your devices.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(syncEngineProvider).syncNow(),
            color: colors.accent,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: conflicts.length,
              itemBuilder: (context, index) {
                final conflict = conflicts[index];
                return _ConflictCard(conflict: conflict);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CupertinoActivityIndicator(),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Failed to load conflicts: $error',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final timeStr = DateFormatter.formatNoteTileTime(conflict.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConflictResolutionScreen(conflict: conflict),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      conflict.effectiveDisplayTitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildConflictBadge(colors, conflict.conflictType),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Detected $timeStr • Base rev ${conflict.baseRevision} vs Server rev ${conflict.remoteRevision}',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              if (conflict.explanation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  conflict.explanation!,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Resolve Conflict',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: colors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConflictBadge(AppColors colors, ConflictType type) {
    String label;
    Color badgeColor;

    switch (type) {
      case ConflictType.content:
        label = 'Content Conflict';
        badgeColor = colors.accent;
        break;
      case ConflictType.title:
        label = 'Title Conflict';
        badgeColor = Colors.orange;
        break;
      case ConflictType.deleteVsEdit:
        label = 'Delete vs Edit';
        badgeColor = Colors.redAccent;
        break;
      case ConflictType.metadata:
        label = 'Metadata Conflict';
        badgeColor = Colors.amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w600,
          fontSize: 11.0,
        ),
      ),
    );
  }
}
