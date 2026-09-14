import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/vault/vault_erase_service.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../application/devices_provider.dart';
import '../domain/device.dart';

class DeviceDetailSheet extends ConsumerStatefulWidget {
  const DeviceDetailSheet({
    super.key,
    required this.device,
    required this.currentDeviceId,
  });

  final Device device;
  final String currentDeviceId;

  static Future<void> show(
    BuildContext context, {
    required Device device,
    required String currentDeviceId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceDetailSheet(
        device: device,
        currentDeviceId: currentDeviceId,
      ),
    );
  }

  @override
  ConsumerState<DeviceDetailSheet> createState() => _DeviceDetailSheetState();
}

class _DeviceDetailSheetState extends ConsumerState<DeviceDetailSheet> {
  late Device _device;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  bool get _isCurrentDevice => _device.isCurrent(widget.currentDeviceId);

  Future<void> _showRenameDialog() async {
    final colors = context.appColors;
    final controller = TextEditingController(text: _device.deviceName ?? _device.model ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Rename Device',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a name to easily identify this device installation.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 64,
                    decoration: InputDecoration(
                      hintText: 'e.g. My Phone, Work Laptop',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: colors.textTertiary,
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(() {
                        errorText = 'Device name cannot be empty';
                      });
                      return;
                    }
                    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(text)) {
                      setDialogState(() {
                        errorText = 'Control characters are not allowed';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: Text(
                    'Save',
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() => _isProcessing = true);
      try {
        final updated = await ref
            .read(devicesActionNotifierProvider.notifier)
            .rename(_device.deviceId, newName);
        if (mounted && updated != null) {
          setState(() {
            _device = updated;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device renamed to "$newName"'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to rename device: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _revokeDevice() async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Sign Out Device',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Sign out of "${_device.displayTitle}"? That device will be disconnected from cloud synchronization.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Sign Out',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await ref
            .read(devicesActionNotifierProvider.notifier)
            .revoke(_device.deviceId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed out of "${_device.displayTitle}"'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out device: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _normalSignOutCurrentDevice() async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Sign out of this device?',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Your local notes will stay on this device and remain available offline. Cloud synchronization will stop until you sign in again.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Sign Out',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop(); // Exit devices screen to settings
      }
    }
  }

  Future<void> _signOutAndEraseCurrentDevice() async {
    final colors = context.appColors;
    final db = ref.read(databaseProvider);
    final unsyncedCount = await db.getUnsyncedChangesCount();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final unsyncedWarning = unsyncedCount > 0
            ? 'You have $unsyncedCount local change${unsyncedCount == 1 ? '' : 's'} that ${unsyncedCount == 1 ? 'has' : 'have'} not reached the cloud. Erasing local data will permanently remove those local changes.\n\n'
            : '';

        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Sign out & erase local data?',
            style: AppTypography.headline.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '${unsyncedWarning}This will completely remove the local Quiet Paper vault from this device, including locally stored encrypted notes and attachments. This cannot be undone.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Erase Local Data',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      await ref.read(vaultEraseServiceProvider).eraseLocalVault();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      padding: EdgeInsets.only(
        top: 12.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
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
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _device.displayTitle,
                                  style: AppTypography.headline.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isCurrentDevice) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'This device',
                                    style: AppTypography.caption.copyWith(
                                      color: colors.accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _device.displaySubtitle,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    QuietIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Rename device',
                      onPressed: _isProcessing ? null : _showRenameDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Grouped details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _buildDetailRow(
                        context,
                        label: 'Operating System',
                        value: _device.osVersion ?? _device.platform ?? 'Unknown',
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        context,
                        label: 'Quiet Paper',
                        value: _device.appVersion != null && _device.appVersion!.isNotEmpty
                            ? 'Quiet Paper ${_device.appVersion}'
                            : 'Quiet Paper',
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        context,
                        label: 'Last Active',
                        value: _device.displayLastActive,
                      ),
                      _buildDivider(colors),
                      _buildDetailRow(
                        context,
                        label: 'Device ID',
                        value: _device.deviceId,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isCurrentDevice) ...[
                      QuietButton(
                        label: 'Sign Out Device',
                        variant: QuietButtonVariant.destructive,
                        isLoading: _isProcessing,
                        onPressed: _revokeDevice,
                      ),
                    ] else ...[
                      QuietButton(
                        label: 'Sign Out',
                        variant: QuietButtonVariant.secondary,
                        isLoading: _isProcessing,
                        onPressed: _normalSignOutCurrentDevice,
                      ),
                      const SizedBox(height: 12),
                      QuietButton(
                        label: 'Sign Out & Erase Local Data',
                        variant: QuietButtonVariant.destructive,
                        isLoading: _isProcessing,
                        onPressed: _signOutAndEraseCurrentDevice,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 0.6,
      color: colors.divider.withValues(alpha: 0.5),
      indent: 16,
      endIndent: 16,
    );
  }
}
