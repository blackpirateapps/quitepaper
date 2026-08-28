import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/documents/presentation/document_viewer_screen.dart';
import '../../../core/storage/storage_management_service.dart';
import '../../../core/sync/sync_models.dart';

class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab; // 0 = Overview & GC, 1 = Attached, 2 = Orphaned

  @override
  ConsumerState<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends ConsumerState<StorageManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCleaningUp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _showCleanupDialog(BuildContext context) async {
    final colors = context.appColors;
    final storageService = ref.read(storageManagementServiceProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => FutureBuilder<GcExecutionSummary>(
        future: storageService.runDryRunGc(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              title: Text('Analyzing Cloud Storage', style: AppTypography.headline.copyWith(color: colors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  CupertinoActivityIndicator(color: colors.accent, radius: 12),
                  const SizedBox(height: 16),
                  Text('Calculating reclaimable space and safe synchronization boundaries...',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
              title: Text('Analysis Failed', style: AppTypography.headline.copyWith(color: colors.error)),
              content: Text(snapshot.error.toString(), style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Close', style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
                ),
              ],
            );
          }

          final summary = snapshot.data!;
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
            title: Text('Cloud Storage Cleanup', style: AppTypography.headline.copyWith(color: colors.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reclaimable Space: ${_formatBytes(summary.estimatedBytesReclaimed)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCleanupItem(colors, 'Sync History Entries', '${summary.syncChangesDeleted} items'),
                  _buildCleanupItem(colors, 'Pruned Note Versions', '${summary.noteVersionsDeleted} items'),
                  _buildCleanupItem(colors, 'Expired Idempotency Keys', '${summary.idempotencyKeysDeleted} items'),
                  _buildCleanupItem(colors, 'Orphaned Attachments', '${summary.orphanedAttachmentsIdentified} items'),
                  _buildCleanupItem(colors, 'Orphaned Documents', '${summary.orphanedDocumentsIdentified} items'),
                  _buildCleanupItem(colors, 'Cleaned Tombstones', '${summary.tombstonesCleaned} items'),
                  const SizedBox(height: 12),
                  Text(
                    'Cleanup is device-aware and only removes data acknowledged by all active devices. Plaintext note content and attachments referenced in notes remain intact.',
                    style: AppTypography.caption.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  setState(() => _isCleaningUp = true);
                  try {
                    final res = await storageService.runGarbageCollection();
                    ref.invalidate(storageProfileProvider);
                    ref.invalidate(storageResourcesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cleanup complete: Reclaimed ${_formatBytes(res.estimatedBytesReclaimed)}'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cleanup failed: $e'),
                          backgroundColor: colors.error,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isCleaningUp = false);
                  }
                },
                child: Text('Clean Up Now', style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCleanupItem(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
          Text(value, style: AppTypography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
          'Cloud Storage & Assets',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.accent,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.accent,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Attached'),
            Tab(text: 'Orphaned'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context),
          _buildAttachedTab(context),
          _buildOrphanedTab(context),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final colors = context.appColors;
    final profileAsync = ref.watch(storageProfileProvider);

    return profileAsync.when(
      loading: () => Center(child: CupertinoActivityIndicator(color: colors.accent)),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: colors.textTertiary),
              const SizedBox(height: 12),
              Text('Unable to fetch cloud storage profile',
                  style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 6),
              Text(err.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: colors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(storageProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (profile) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(colors, profile),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(context, 'Storage Breakdown'),
            _buildTableMetricsGroup(colors, profile),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(context, 'Maintenance & Cleanup'),
            _buildMaintenanceGroup(colors, profile),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppColors colors, StorageProfileReport profile) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: colors.accent, size: 24),
              const SizedBox(width: 8),
              Text('Total Cloud Storage', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatBytes(profile.totalEstimatedBytes),
            style: AppTypography.display.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reclaimable Space', style: AppTypography.caption.copyWith(color: colors.textTertiary)),
                  const SizedBox(height: 2),
                  Text(_formatBytes(profile.totalReclaimableBytes),
                      style: AppTypography.bodySmall.copyWith(color: colors.accent, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Active Checkpoints', style: AppTypography.caption.copyWith(color: colors.textTertiary)),
                  const SizedBox(height: 2),
                  Text('${profile.activeDevicesCount} active device(s)',
                      style: AppTypography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableMetricsGroup(AppColors colors, StorageProfileReport profile) {
    final t = profile.tables;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _buildStorageRow(colors, 'Notes (Ciphertext)', t['notes']?.rowCount ?? 0, t['notes']?.approximatePayloadBytes ?? 0),
          _buildDivider(colors),
          _buildStorageRow(colors, 'Note Versions History', t['noteVersions']?.rowCount ?? 0, t['noteVersions']?.approximatePayloadBytes ?? 0),
          _buildDivider(colors),
          _buildStorageRow(colors, 'Sync History & Revisions', t['syncChanges']?.rowCount ?? 0, t['syncChanges']?.approximatePayloadBytes ?? 0),
          _buildDivider(colors),
          _buildStorageRow(colors, 'Image Attachments', t['attachments']?.rowCount ?? 0, t['attachments']?.approximatePayloadBytes ?? 0),
          _buildDivider(colors),
          _buildStorageRow(colors, 'Scanned Documents (PDF)', t['documents']?.rowCount ?? 0, t['documents']?.approximatePayloadBytes ?? 0),
          _buildDivider(colors),
          _buildStorageRow(colors, 'Encrypted Document OCR', t['documentOcrPages']?.rowCount ?? 0, t['documentOcrPages']?.approximatePayloadBytes ?? 0),
        ],
      ),
    );
  }

  Widget _buildStorageRow(AppColors colors, String title, int count, int bytes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodySmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
              Text('$count record${count == 1 ? '' : 's'}', style: AppTypography.caption.copyWith(color: colors.textTertiary)),
            ],
          ),
          Text(_formatBytes(bytes), style: AppTypography.bodySmall.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMaintenanceGroup(AppColors colors, StorageProfileReport profile) {
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.cleaning_services_rounded, color: colors.accent),
            title: Text('Run Storage Cleanup (GC)', style: AppTypography.bodyMedium.copyWith(color: colors.accent, fontWeight: FontWeight.w600)),
            subtitle: Text('Analyze and prune stale revisions, idempotency keys, and expired orphans',
                style: AppTypography.caption.copyWith(color: colors.textSecondary)),
            trailing: _isCleaningUp ? const CupertinoActivityIndicator(radius: 8) : const Icon(CupertinoIcons.chevron_forward, size: 14),
            onTap: _isCleaningUp ? null : () => _showCleanupDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedTab(BuildContext context) {
    final colors = context.appColors;
    final resourcesAsync = ref.watch(storageResourcesProvider);

    return resourcesAsync.when(
      loading: () => Center(child: CupertinoActivityIndicator(color: colors.accent)),
      error: (err, _) => Center(child: Text(err.toString(), style: AppTypography.bodySmall.copyWith(color: colors.textSecondary))),
      data: (res) {
        final items = res.attached;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attachment_rounded, size: 48, color: colors.textTertiary),
                const SizedBox(height: 12),
                Text('No attached resources found in cloud', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final item = items[idx];
            return _buildResourceTile(colors, item, isOrphan: false);
          },
        );
      },
    );
  }

  Widget _buildOrphanedTab(BuildContext context) {
    final colors = context.appColors;
    final resourcesAsync = ref.watch(storageResourcesProvider);

    return resourcesAsync.when(
      loading: () => Center(child: CupertinoActivityIndicator(color: colors.accent)),
      error: (err, _) => Center(child: Text(err.toString(), style: AppTypography.bodySmall.copyWith(color: colors.textSecondary))),
      data: (res) {
        final items = res.orphaned;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 48, color: colors.accent),
                const SizedBox(height: 12),
                Text('No orphaned resources found', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text('All cloud assets are actively referenced by notes', style: AppTypography.caption.copyWith(color: colors.textTertiary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final item = items[idx];
            return _buildResourceTile(colors, item, isOrphan: true);
          },
        );
      },
    );
  }

  Widget _buildResourceTile(AppColors colors, StorageResourceItem item, {required bool isOrphan}) {
    final isDoc = item.type == 'document';
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDoc ? Colors.red : colors.accent).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            isDoc ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            color: isDoc ? Colors.red : colors.accent,
            size: 22,
          ),
        ),
        title: Text(
          item.title.isNotEmpty ? item.title : (isDoc ? 'Scanned Document' : 'Image Attachment'),
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatBytes(item.byteSize)} • ${item.mimeType}',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
            if (isOrphan) ...[
              const SizedBox(height: 2),
              Text(
                item.isEligibleForDeletion ? 'Eligible for destruction' : 'In 14-day safety grace period',
                style: AppTypography.caption.copyWith(
                  color: item.isEligibleForDeletion ? colors.error : colors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        trailing: isOrphan
            ? IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: colors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                      title: Text('Delete Orphaned Asset', style: AppTypography.headline.copyWith(color: colors.textPrimary)),
                      content: Text(
                        'Are you sure you want to permanently delete this asset from cloud and local storage? This action cannot be undone.',
                        style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.error,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                          ),
                          onPressed: () => Navigator.of(dCtx).pop(true),
                          child: Text('Delete', style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    try {
                      await ref.read(storageManagementServiceProvider).deleteOrphanedResource(
                            resourceType: item.type,
                            resourceId: item.id,
                          );
                      ref.invalidate(storageResourcesProvider);
                      ref.invalidate(storageProfileProvider);
                    } catch (err) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete asset: $err'), backgroundColor: colors.error),
                        );
                      }
                    }
                  }
                },
              )
            : (isDoc
                ? IconButton(
                    icon: Icon(Icons.open_in_new_rounded, color: colors.textSecondary, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(documentId: item.id),
                        ),
                      );
                    },
                  )
                : null),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: colors.textTertiary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md,
      color: colors.divider,
    );
  }
}
