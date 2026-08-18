import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../widgets/quiet_button.dart';
import '../widgets/quiet_icon_button.dart';
import 'update_models.dart';
import 'update_provider.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    this.currentVersion = '1.2.0',
    this.isManualCheck = false,
  });

  final AppReleaseInfo release;
  final String currentVersion;
  final bool isManualCheck;

  static Future<void> show(
    BuildContext context,
    AppReleaseInfo release, {
    String currentVersion = '1.2.0',
    bool isManualCheck = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        release: release,
        currentVersion: currentVersion,
        isManualCheck: isManualCheck,
      ),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _dontRemindFor30Days = false;
  DownloadProgress _progress = const DownloadProgress();
  StreamSubscription<DownloadProgress>? _downloadSub;
  bool _needsPermission = false;

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  void _onLater() async {
    final updateService = ref.read(updateServiceProvider);
    if (_dontRemindFor30Days) {
      await updateService.snoozeUpdate(widget.release.version, days: 30);
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _startDownload() {
    final updateService = ref.read(updateServiceProvider);

    setState(() {
      _progress = const DownloadProgress(status: DownloadStatus.downloading);
      _needsPermission = false;
    });

    _downloadSub?.cancel();
    _downloadSub = updateService.downloadApk(widget.release).listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
        });

        if (progress.status == DownloadStatus.completed &&
            progress.filePath != null) {
          _checkPermissionAndInstall(progress.filePath!);
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _progress = DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage: err.toString(),
          );
        });
      },
    );
  }

  void _cancelDownload() {
    _downloadSub?.cancel();
    setState(() {
      _progress = const DownloadProgress(status: DownloadStatus.idle);
    });
  }

  Future<void> _checkPermissionAndInstall(String filePath) async {
    final updateService = ref.read(updateServiceProvider);
    final canInstall = await updateService.canRequestPackageInstalls();

    if (!canInstall) {
      setState(() {
        _needsPermission = true;
      });
    } else {
      await updateService.installApk(filePath);
    }
  }

  Future<void> _requestPermissionAndInstall() async {
    final updateService = ref.read(updateServiceProvider);
    await updateService.openInstallPermissionSettings();

    // After returning from settings, check and trigger install
    if (_progress.filePath != null) {
      final canInstall = await updateService.canRequestPackageInstalls();
      if (canInstall) {
        setState(() {
          _needsPermission = false;
        });
        await updateService.installApk(_progress.filePath!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDownloading = _progress.status == DownloadStatus.downloading;
    final isCompleted = _progress.status == DownloadStatus.completed;
    final isFailed = _progress.status == DownloadStatus.failed;

    return PopScope(
      canPop: !isDownloading,
      child: Dialog(
        backgroundColor: colors.background,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: AppRadii.borderMd,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: colors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Available',
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quiet Paper v${widget.release.version}',
                            style: AppTypography.caption.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDownloading)
                      QuietIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onPressed: _onLater,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Version comparison and architecture badges
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadii.borderSm,
                        border: Border.all(color: colors.divider),
                      ),
                      child: Text(
                        'v${widget.currentVersion}  →  v${widget.release.version}',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.release.architecture.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadii.borderSm,
                          border: Border.all(color: colors.divider),
                        ),
                        child: Text(
                          '${widget.release.architecture} • ${widget.release.formattedSize}',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Release notes (if present)
                if (widget.release.releaseNotes.trim().isNotEmpty) ...[
                  Text(
                    "What's New",
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadii.borderMd,
                      border: Border.all(color: colors.divider),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        widget.release.releaseNotes.trim(),
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Downloading Progress Bar
                if (isDownloading) ...[
                  ClipRRect(
                    borderRadius: AppRadii.borderSm,
                    child: LinearProgressIndicator(
                      value: _progress.progress > 0 ? _progress.progress : null,
                      backgroundColor: colors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading update...',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        _progress.formattedProgress,
                        style: AppTypography.caption.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Download Failed State
                if (isFailed) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadii.borderSm,
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 18, color: colors.error),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _progress.errorMessage ?? 'Download failed',
                            style: AppTypography.caption.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Permission Warning Cue
                if (_needsPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.1),
                      borderRadius: AppRadii.borderSm,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded,
                                size: 18, color: colors.accent),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Install Permission Required',
                              style: AppTypography.caption.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Android requires permission to install APK updates from Quiet Paper. Tap below to enable "Install unknown apps".',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 30-Day Snooze Checkbox (only when idle)
                if (!isDownloading && !isCompleted) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _dontRemindFor30Days = !_dontRemindFor30Days;
                      });
                    },
                    borderRadius: AppRadii.borderSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _dontRemindFor30Days,
                              activeColor: colors.accent,
                              checkColor: Colors.white,
                              side: BorderSide(
                                color: colors.textTertiary,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _dontRemindFor30Days = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              "Don't remind me for 30 days",
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isDownloading && !isCompleted) ...[
                      QuietButton(
                        label: 'Later',
                        variant: QuietButtonVariant.tonal,
                        onPressed: _onLater,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      QuietButton(
                        label: isFailed ? 'Retry Download' : 'Update Now',
                        icon: Icons.download_rounded,
                        variant: QuietButtonVariant.primary,
                        onPressed: _startDownload,
                      ),
                    ] else if (isDownloading) ...[
                      QuietButton(
                        label: 'Cancel',
                        variant: QuietButtonVariant.tonal,
                        onPressed: _cancelDownload,
                      ),
                    ] else if (isCompleted) ...[
                      QuietButton(
                        label: 'Dismiss',
                        variant: QuietButtonVariant.tonal,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (_needsPermission)
                        QuietButton(
                          label: 'Grant Permission',
                          icon: Icons.settings_outlined,
                          variant: QuietButtonVariant.primary,
                          onPressed: _requestPermissionAndInstall,
                        )
                      else
                        QuietButton(
                          label: 'Install Update',
                          icon: Icons.install_mobile_rounded,
                          variant: QuietButtonVariant.primary,
                          onPressed: () {
                            if (_progress.filePath != null) {
                              _checkPermissionAndInstall(_progress.filePath!);
                            }
                          },
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
