import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/maintenance/maintenance_models.dart';
import '../../../../core/maintenance/maintenance_provider.dart';
import '../../../../core/widgets/quiet_button.dart';

/// Modal bottom sheet presenting real-time progress for batch maintenance tasks
/// (e.g. downloading attachments, re-running OCR) with cancellation support.
class MaintenanceProgressSheet extends ConsumerStatefulWidget {
  const MaintenanceProgressSheet({
    super.key,
    required this.taskType,
  });

  final MaintenanceTaskType taskType;

  /// Presents the maintenance progress sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required MaintenanceTaskType taskType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaintenanceProgressSheet(taskType: taskType),
    );
  }

  @override
  ConsumerState<MaintenanceProgressSheet> createState() =>
      _MaintenanceProgressSheetState();
}

class _MaintenanceProgressSheetState
    extends ConsumerState<MaintenanceProgressSheet> {
  final MaintenanceCancellationToken _cancelToken =
      MaintenanceCancellationToken();

  late MaintenanceProgress _progress;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _progress = MaintenanceProgress(
      taskType: widget.taskType,
      phase: MaintenancePhase.preparing,
      statusMessage: 'Preparing task...',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTask();
    });
  }

  Future<void> _startTask() async {
    final service = ref.read(attachmentMaintenanceServiceProvider);

    try {
      if (widget.taskType == MaintenanceTaskType.downloadAttachments) {
        await service.downloadAllAttachments(
          cancelToken: _cancelToken,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _progress = p;
              });
            }
          },
        );
      } else if (widget.taskType == MaintenanceTaskType.rerunOcr) {
        await service.rerunOcrForAll(
          cancelToken: _cancelToken,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _progress = p;
              });
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = _progress.copyWith(
            phase: MaintenancePhase.failed,
            statusMessage: 'Operation failed: $e',
            errorMessages: [e.toString()],
          );
        });
      }
    }
  }

  void _handleCancel() {
    setState(() {
      _isCancelling = true;
    });
    _cancelToken.cancel();
  }

  String get _taskTitle {
    switch (widget.taskType) {
      case MaintenanceTaskType.downloadAttachments:
        return 'Downloading Attachments';
      case MaintenanceTaskType.rerunOcr:
        return 'Running OCR Recognition';
      case MaintenanceTaskType.rebuildSearchIndex:
        return 'Rebuilding Search Index';
    }
  }

  IconData get _taskIcon {
    switch (widget.taskType) {
      case MaintenanceTaskType.downloadAttachments:
        return Icons.cloud_download_outlined;
      case MaintenanceTaskType.rerunOcr:
        return Icons.document_scanner_outlined;
      case MaintenanceTaskType.rebuildSearchIndex:
        return Icons.manage_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isFinished = _progress.isFinished;
    final isCancelled = _progress.phase == MaintenancePhase.cancelled;
    final isFailed = _progress.phase == MaintenancePhase.failed;
    final isCompleted = _progress.phase == MaintenancePhase.completed;

    return PopScope(
      canPop: isFinished,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
          border: Border(
            top: BorderSide(color: colors.divider),
            left: BorderSide(color: colors.divider),
            right: BorderSide(color: colors.divider),
          ),
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Row: Icon + Title
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.tagBackground,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Center(
                    child: Icon(
                      _taskIcon,
                      size: 20,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _taskTitle,
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isFinished)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status message
            Text(
              _progress.statusMessage.isNotEmpty
                  ? _progress.statusMessage
                  : 'Processing...',
              style: AppTypography.bodySmall.copyWith(
                color: isFailed ? colors.error : colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Progress Bar
            ClipRRect(
              borderRadius: AppRadii.borderSm,
              child: LinearProgressIndicator(
                value: isFinished
                    ? (isCompleted ? 1.0 : _progress.progressFraction)
                    : (_progress.progressFraction > 0
                        ? _progress.progressFraction
                        : null),
                backgroundColor: colors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFailed
                      ? colors.error
                      : (isCancelled ? colors.textSecondary : colors.accent),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Progress Metadata Counter / Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _progress.currentItemName.isNotEmpty
                        ? _progress.currentItemName
                        : (_progress.totalItems > 0
                            ? '${_progress.completedItems} of ${_progress.totalItems} items'
                            : ''),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isCompleted
                      ? '100%'
                      : '${(_progress.progressFraction * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Error warnings if any
            if (_progress.hasErrors && !isFailed) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: colors.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${_progress.failedItems} item(s) could not be processed.',
                        style: AppTypography.caption.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            if (!isFinished) ...[
              QuietButton(
                label: _isCancelling ? 'Cancelling...' : 'Cancel',
                variant: QuietButtonVariant.secondary,
                isFullWidth: true,
                isLoading: _isCancelling,
                onPressed: _isCancelling ? null : _handleCancel,
              ),
            ] else ...[
              QuietButton(
                label: 'Done',
                variant: QuietButtonVariant.primary,
                isFullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
