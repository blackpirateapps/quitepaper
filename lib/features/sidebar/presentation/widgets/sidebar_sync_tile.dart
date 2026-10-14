import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../../sync/presentation/conflict_list_screen.dart';
import '../../../sync/presentation/sync_auth_screen.dart';
import '../../../tags/domain/phosphor_icons.dart';

class SidebarSyncTile extends ConsumerStatefulWidget {
  const SidebarSyncTile({
    super.key,
    this.onItemSelected,
  });

  final VoidCallback? onItemSelected;

  @override
  ConsumerState<SidebarSyncTile> createState() => _SidebarSyncTileState();
}

class _SidebarSyncTileState extends ConsumerState<SidebarSyncTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncRotationController;

  @override
  void initState() {
    super.initState();
    _syncRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _syncRotationController.dispose();
    super.dispose();
  }

  void _updateAnimationState(SyncStatus status) {
    if (status == SyncStatus.syncing) {
      if (!_syncRotationController.isAnimating) {
        _syncRotationController.repeat();
      }
    } else {
      if (_syncRotationController.isAnimating) {
        _syncRotationController.stop();
        _syncRotationController.reset();
      }
    }
  }

  Future<void> _handleSyncTap(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await _showOfflineInfoDialog(context);
      return;
    }

    final keyManager = ref.read(keyManagerProvider);
    if (!keyManager.isUnlocked) {
      final colors = context.appColors;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Encryption locked. Please enter your encryption password in Settings.',
          ),
          backgroundColor: colors.elevated,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Settings',
            textColor: colors.accent,
            onPressed: () {
              widget.onItemSelected?.call();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    final currentState = ref.read(syncStateProvider);
    if (currentState.status == SyncStatus.syncing) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final colors = context.appColors;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Syncing notes...'),
        duration: const Duration(seconds: 1),
        backgroundColor: colors.elevated,
      ),
    );

    await ref.read(syncEngineProvider).syncNow();

    if (!context.mounted) return;
    final resultState = ref.read(syncStateProvider);
    messenger.hideCurrentSnackBar();

    if (resultState.status == SyncStatus.syncError) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  resultState.errorMessage ?? 'Sync error occurred.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: colors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (resultState.status == SyncStatus.offline) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Offline • Changes preserved on device'),
          duration: const Duration(seconds: 3),
          backgroundColor: colors.elevated,
        ),
      );
    } else if (resultState.status == SyncStatus.conflict ||
        resultState.conflictsCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sync complete with ${resultState.conflictsCount} conflict(s) requiring review.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Review',
            textColor: Colors.white,
            onPressed: () {
              widget.onItemSelected?.call();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConflictListScreen()),
              );
            },
          ),
        ),
      );
    } else if (resultState.status == SyncStatus.synced) {
      final attSynced = resultState.attachmentsSynced;
      final successText = attSynced > 0
          ? 'Sync complete: Notes & $attSynced image(s) synced'
          : 'Sync complete: All notes up to date';

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: colors.accent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openConflicts(BuildContext context) {
    widget.onItemSelected?.call();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConflictListScreen()),
    );
  }

  Future<void> _showOfflineInfoDialog(BuildContext context) async {
    final colors = context.appColors;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: colors.divider, width: 0.8),
        ),
        title: Row(
          children: [
            Icon(
              PhosphorIconsRegular.cloudSlash,
              color: colors.accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offline Storage',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Quiet Paper keeps your notes private and stored locally on this device. Sign in and configure your encryption password to synchronize seamlessly and securely across all your devices.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Close',
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          QuietButton(
            label: 'Set up Encrypted Sync',
            variant: QuietButtonVariant.primary,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              widget.onItemSelected?.call();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncAuthScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;

    final defaultTextColor =
        isSidebarDark ? const Color(0xFFF1F2F4) : colors.textPrimary;
    final defaultSecondaryColor =
        isSidebarDark ? const Color(0xFF9CA3AF) : colors.textSecondary;
    final defaultTertiaryColor =
        isSidebarDark ? const Color(0xFF9CA3AF) : colors.textTertiary;

    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final conflictsAsync = ref.watch(pendingConflictsCountStreamProvider);
    final conflictsCount = conflictsAsync.valueOrNull ?? syncState.conflictsCount;

    _updateAnimationState(syncState.status);

    final IconData iconData;
    final Color iconColor;
    final String titleText;
    final String statusDetail;

    if (currentUser == null) {
      iconData = PhosphorIconsRegular.cloudSlash;
      iconColor = defaultSecondaryColor;
      titleText = 'Local Vault';
      statusDetail = 'Tap to set up sync';
    } else {
      switch (syncState.status) {
        case SyncStatus.syncing:
          iconData = PhosphorIconsRegular.arrowsClockwise;
          iconColor = colors.accent;
          titleText = 'Syncing...';
          statusDetail = 'Updating changes...';
          break;
        case SyncStatus.synced:
          iconData = PhosphorIconsRegular.cloudCheck;
          iconColor = colors.accent;
          titleText = 'Sync';
          if (syncState.lastSyncedAt != null) {
            statusDetail =
                'Synced ${DateFormatter.formatRelative(syncState.lastSyncedAt!)}';
          } else {
            statusDetail = 'All notes up to date';
          }
          break;
        case SyncStatus.pendingSync:
          iconData = PhosphorIconsRegular.lock;
          iconColor = colors.warning;
          titleText = 'Encryption Locked';
          statusDetail = 'Unlock to sync';
          break;
        case SyncStatus.offline:
          iconData = PhosphorIconsRegular.cloudSlash;
          iconColor = defaultSecondaryColor;
          titleText = 'Offline';
          statusDetail = 'Saved locally';
          break;
        case SyncStatus.conflict:
          iconData = PhosphorIconsRegular.warning;
          iconColor = isSidebarDark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFB45309);
          titleText = 'Sync Conflict';
          statusDetail = 'Review needed';
          break;
        case SyncStatus.syncError:
          iconData = PhosphorIconsRegular.cloudWarning;
          iconColor = colors.error;
          titleText = 'Sync Error';
          statusDetail = syncState.errorMessage != null
              ? 'Error • Tap to retry'
              : 'Tap to retry';
          break;
        case SyncStatus.localOnly:
          iconData = PhosphorIconsRegular.cloudSlash;
          iconColor = defaultSecondaryColor;
          titleText = 'Local Only';
          statusDetail = 'Cloud sync inactive';
          break;
      }
    }

    final amberTextColor = isSidebarDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    final amberIconColor = amberTextColor;
    final amberBgColor = isSidebarDark
        ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
        : const Color(0xFFFDE68A).withValues(alpha: 0.45);
    final amberBorderColor = isSidebarDark
        ? const Color(0xFFFBBF24).withValues(alpha: 0.3)
        : const Color(0xFFB45309).withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: InkWell(
              onTap: () => _handleSyncTap(context),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              splashColor: colors.accent.withValues(alpha: 0.1),
              highlightColor: colors.selection.withValues(alpha: 0.3),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      RotationTransition(
                        turns: _syncRotationController,
                        child: Icon(
                          iconData,
                          size: 20,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titleText,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: defaultTextColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (currentUser != null &&
                                    syncState.status == SyncStatus.synced &&
                                    syncState.lastSyncedAt != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormatter.formatRelative(
                                      syncState.lastSyncedAt!,
                                    ),
                                    style: AppTypography.caption.copyWith(
                                      color: defaultTertiaryColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              currentUser != null
                                  ? currentUser.email
                                  : statusDetail,
                              style: AppTypography.caption.copyWith(
                                color: defaultSecondaryColor,
                                fontSize: 12.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentUser != null &&
                                syncState.status != SyncStatus.synced) ...[
                              const SizedBox(height: 1.5),
                              Text(
                                statusDetail,
                                style: AppTypography.caption.copyWith(
                                  color: syncState.status == SyncStatus.syncError
                                      ? colors.error
                                      : defaultTertiaryColor,
                                  fontSize: 11.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (conflictsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                2.0,
                AppSpacing.sm,
                4.0,
              ),
              child: Material(
                color: amberBgColor,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: InkWell(
                  onTap: () => _openConflicts(context),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(
                        color: amberBorderColor,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.warning,
                          size: 15,
                          color: amberIconColor,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            '$conflictsCount conflict${conflictsCount > 1 ? 's' : ''} require review',
                            style: AppTypography.caption.copyWith(
                              color: amberTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 13,
                          color: amberIconColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
