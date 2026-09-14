import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/device/device_info_service.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../application/devices_provider.dart';
import '../domain/device.dart';
import 'device_detail_sheet.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _isRevokingOthers = false;

  IconData _iconForDevice(Device device) {
    final plat = (device.platform ?? '').toLowerCase();
    final model = (device.model ?? '').toLowerCase();

    if (plat.contains('ipad') || model.contains('ipad') || model.contains('tablet')) {
      return Icons.tablet_rounded;
    }
    if (plat.contains('android') || plat.contains('ios') || model.contains('phone') || model.contains('pixel') || model.contains('galaxy')) {
      return Icons.smartphone_rounded;
    }
    if (plat.contains('mac') || plat.contains('windows') || plat.contains('linux') || model.contains('book') || model.contains('laptop')) {
      return Icons.laptop_rounded;
    }
    return Icons.devices_rounded;
  }

  Future<void> _confirmRevokeAllOthers(String currentDeviceId) async {
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
            'Sign out all other devices?',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This will sign out Quiet Paper from every other device connected to your account. This device will remain signed in.',
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
                'Sign Out All',
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
      setState(() => _isRevokingOthers = true);
      try {
        final count = await ref
            .read(devicesActionNotifierProvider.notifier)
            .revokeOthers(currentDeviceId);
        if (mounted) {
          setState(() => _isRevokingOthers = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed out of $count other device${count == 1 ? '' : 's'}.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRevokingOthers = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out other devices: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final devicesAsync = ref.watch(devicesListProvider);
    final currentDeviceIdAsync = ref.watch(currentDeviceIdProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Devices & Sessions',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18.0,
          ),
        ),
        actions: [
          QuietIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh devices',
            onPressed: () => ref.refresh(devicesListProvider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: devicesAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: colors.accent,
              ),
            ),
            error: (error, _) {
              final errStr = error.toString();
              final isOffline = errStr.contains('SocketException') ||
                  errStr.contains('ClientException') ||
                  errStr.contains('Network') ||
                  errStr.contains('Failed host lookup');

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                        size: 44,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isOffline
                            ? 'Device management requires an internet connection.'
                            : 'Unable to load devices',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOffline
                            ? 'Your local notes remain fully available offline.'
                            : errStr.replaceFirst(RegExp(r'^Exception:\s*'), ''),
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      QuietButton(
                        label: 'Try Again',
                        variant: QuietButtonVariant.secondary,
                        onPressed: () => ref.refresh(devicesListProvider),
                      ),
                    ],
                  ),
                ),
              );
            },
            data: (devices) {
              final currentDeviceId = currentDeviceIdAsync.value ?? '';

              // Sort with current device first, then by last active
              final sortedDevices = List<Device>.from(devices)
                ..sort((a, b) {
                  if (a.isCurrent(currentDeviceId)) return -1;
                  if (b.isCurrent(currentDeviceId)) return 1;
                  return b.lastActiveAt.compareTo(a.lastActiveAt);
                });

              final hasOtherDevices = sortedDevices.any((d) => !d.isCurrent(currentDeviceId));

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(devicesListProvider);
                  await ref.read(devicesListProvider.future);
                },
                color: colors.accent,
                backgroundColor: colors.surface,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  children: [
                    // Section header
                    _buildSectionHeader(
                      context,
                      'DEVICES & SESSIONS',
                      subtitle: sortedDevices.length == 1
                          ? 'Your account is signed in on 1 device.'
                          : 'Your account is signed in on ${sortedDevices.length} devices.',
                    ),
                    const SizedBox(height: 8),

                    // Grouped Devices Container
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: colors.divider.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < sortedDevices.length; i++) ...[
                            if (i > 0) _buildDivider(colors),
                            _buildDeviceRow(
                              context,
                              device: sortedDevices[i],
                              isCurrent: sortedDevices[i].isCurrent(currentDeviceId),
                              onTap: () {
                                DeviceDetailSheet.show(
                                  context,
                                  device: sortedDevices[i],
                                  currentDeviceId: currentDeviceId,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (hasOtherDevices) ...[
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: colors.divider.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isRevokingOthers
                                ? null
                                : () => _confirmRevokeAllOthers(currentDeviceId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 14.0,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Center(
                                      child: Icon(
                                        Icons.logout_rounded,
                                        size: 20,
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Sign Out All Other Devices',
                                      style: AppTypography.bodySmallMedium.copyWith(
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_isRevokingOthers)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.error,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: colors.textTertiary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
  }) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                fontSize: 13.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context, {
    required Device device,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    final icon = _iconForDevice(device);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 13.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: isCurrent ? colors.accent : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.displayTitle,
                            style: AppTypography.bodySmallMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'This device',
                              style: AppTypography.caption.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.displaySubtitle,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      device.displayLastActive,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 0.6,
      color: colors.divider.withValues(alpha: 0.5),
      indent: 52,
      endIndent: 0,
    );
  }
}
