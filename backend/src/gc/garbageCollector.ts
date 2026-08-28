import { Client } from '@libsql/client';
import crypto from 'crypto';
import { profileUserStorage, StorageProfileReport } from './storageProfiler.js';
import { processDestructionJobs, DestructionJobResult } from './destructionJobProcessor.js';

export interface GcRunOptions {
  dryRun?: boolean;
  batchSize?: number;
  orphanGracePeriodDays?: number;
  staleDeviceDays?: number;
  expiredDeviceDays?: number;
}

export interface GcExecutionSummary {
  runId: string;
  userId: string;
  dryRun: boolean;
  startedAt: string;
  finishedAt: string;
  durationMs: number;
  safeSyncBoundaryRevision: number;

  syncChangesInspected: number;
  syncChangesDeleted: number;

  noteVersionsInspected: number;
  noteVersionsDeleted: number;

  idempotencyKeysDeleted: number;

  orphanedAttachmentsIdentified: number;
  orphanedDocumentsIdentified: number;

  destructionJobsCreated: number;
  destructionJobsProcessed: number;
  destructionJobsCompleted: number;
  destructionJobsFailed: number;

  tombstonesCleaned: number;
  estimatedBytesReclaimed: number;
  profile: StorageProfileReport;
}

/**
 * Calculates the safe synchronization boundary revision for a user based on active device checkpoints.
 */
export async function getSafeSyncBoundary(
  db: Client,
  userId: string,
  staleDeviceDays: number = 30
): Promise<number> {
  const activeCutoffIso = new Date(Date.now() - staleDeviceDays * 24 * 60 * 60 * 1000).toISOString();

  // Find all active devices for this user
  const activeDevicesRes = await db.execute({
    sql: `SELECT last_acknowledged_revision
          FROM sync_devices
          WHERE user_id = ? AND last_seen_at >= ?`,
    args: [userId, activeCutoffIso],
  });

  if (activeDevicesRes.rows.length === 0) {
    // If no active devices with checkpoints are recorded, use min(revision) or 0
    return 0;
  }

  let minAck = Number.MAX_SAFE_INTEGER;
  for (const row of activeDevicesRes.rows) {
    const rev = Number(row.last_acknowledged_revision || 0);
    if (rev < minAck) {
      minAck = rev;
    }
  }

  return minAck === Number.MAX_SAFE_INTEGER ? 0 : minAck;
}

/**
 * Central Incremental Garbage Collector for Quiet Paper Cloud Storage.
 */
export async function runGarbageCollection(
  db: Client,
  userId: string,
  options: GcRunOptions = {}
): Promise<GcExecutionSummary> {
  const runId = crypto.randomUUID();
  const startedAt = new Date();
  const dryRun = options.dryRun ?? false;
  const batchSize = Math.max(1, Math.min(options.batchSize ?? 100, 500));
  const orphanGracePeriodDays = options.orphanGracePeriodDays ?? 14;
  const staleDeviceDays = options.staleDeviceDays ?? 30;

  const safeBoundaryRevision = await getSafeSyncBoundary(db, userId, staleDeviceDays);
  const initialProfile = await profileUserStorage(db, userId, safeBoundaryRevision, orphanGracePeriodDays);

  if (dryRun) {
    const finishedAt = new Date();
    return {
      runId,
      userId,
      dryRun: true,
      startedAt: startedAt.toISOString(),
      finishedAt: finishedAt.toISOString(),
      durationMs: finishedAt.getTime() - startedAt.getTime(),
      safeSyncBoundaryRevision: safeBoundaryRevision,
      syncChangesInspected: initialProfile.tables.syncChanges.rowCount,
      syncChangesDeleted: initialProfile.tables.syncChanges.eligibleRowCount,
      noteVersionsInspected: initialProfile.tables.noteVersions.rowCount,
      noteVersionsDeleted: initialProfile.tables.noteVersions.eligibleRowCount,
      idempotencyKeysDeleted: initialProfile.tables.idempotencyKeys.eligibleRowCount,
      orphanedAttachmentsIdentified: initialProfile.tables.attachments.eligibleRowCount,
      orphanedDocumentsIdentified: initialProfile.tables.documents.eligibleRowCount,
      destructionJobsCreated: 0,
      destructionJobsProcessed: 0,
      destructionJobsCompleted: 0,
      destructionJobsFailed: 0,
      tombstonesCleaned: initialProfile.tables.notes.eligibleRowCount,
      estimatedBytesReclaimed: initialProfile.totalReclaimableBytes,
      profile: initialProfile,
    };
  }

  const nowIso = new Date().toISOString();
  const orphanCutoffIso = new Date(Date.now() - orphanGracePeriodDays * 24 * 60 * 60 * 1000).toISOString();
  const idempotencyCutoffIso = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  let syncChangesDeleted = 0;
  let noteVersionsDeleted = 0;
  let idempotencyKeysDeleted = 0;
  let orphanedAttachmentsIdentified = 0;
  let orphanedDocumentsIdentified = 0;
  let destructionJobsCreated = 0;
  let tombstonesCleaned = 0;

  // =========================================================================
  // 1. RevisionCollector: Prune sync_changes older than safe sync boundary
  // =========================================================================
  if (safeBoundaryRevision > 0) {
    const candidateChangesRes = await db.execute({
      sql: `SELECT id FROM sync_changes
            WHERE user_id = ? AND revision < ?
            LIMIT ?`,
      args: [userId, safeBoundaryRevision, batchSize],
    });

    if (candidateChangesRes.rows.length > 0) {
      const ids = candidateChangesRes.rows.map(r => r.id as string);
      const placeholders = ids.map(() => '?').join(',');
      const delRes = await db.execute({
        sql: `DELETE FROM sync_changes WHERE user_id = ? AND id IN (${placeholders})`,
        args: [userId, ...ids],
      });
      syncChangesDeleted = Number(delRes.rowsAffected || ids.length);
    }
  }

  // =========================================================================
  // 2. VersionCollector: Prune versions of deleted notes & older excess versions
  // =========================================================================
  const candidateVersionsRes = await db.execute({
    sql: `SELECT v.id FROM note_versions v
          LEFT JOIN notes n ON v.note_id = n.id AND v.user_id = n.user_id
          WHERE v.user_id = ? AND (n.deleted_at IS NOT NULL OR n.id IS NULL)
          LIMIT ?`,
    args: [userId, batchSize],
  });

  if (candidateVersionsRes.rows.length > 0) {
    const vIds = candidateVersionsRes.rows.map(r => r.id as string);
    const placeholders = vIds.map(() => '?').join(',');
    const delRes = await db.execute({
      sql: `DELETE FROM note_versions WHERE user_id = ? AND id IN (${placeholders})`,
      args: [userId, ...vIds],
    });
    noteVersionsDeleted = Number(delRes.rowsAffected || vIds.length);
  }

  // Also prune excess versions beyond 50 for active notes
  const notesWithManyVersions = await db.execute({
    sql: `SELECT note_id, COUNT(*) as cnt
          FROM note_versions WHERE user_id = ?
          GROUP BY note_id HAVING cnt > 50
          LIMIT 10`,
    args: [userId],
  });

  for (const row of notesWithManyVersions.rows) {
    const noteId = row.note_id as string;
    const excessCount = Number(row.cnt) - 50;
    if (excessCount > 0) {
      const excessRes = await db.execute({
        sql: `SELECT id FROM note_versions
              WHERE user_id = ? AND note_id = ?
              ORDER BY version_number ASC
              LIMIT ?`,
        args: [userId, noteId, excessCount],
      });
      if (excessRes.rows.length > 0) {
        const ids = excessRes.rows.map(r => r.id as string);
        const placeholders = ids.map(() => '?').join(',');
        await db.execute({
          sql: `DELETE FROM note_versions WHERE user_id = ? AND id IN (${placeholders})`,
          args: [userId, ...ids],
        });
        noteVersionsDeleted += ids.length;
      }
    }
  }

  // =========================================================================
  // 3. IdempotencyCollector: Clean up expired idempotency keys
  // =========================================================================
  const idemRes = await db.execute({
    sql: `DELETE FROM idempotency_keys WHERE user_id = ? AND created_at < ?`,
    args: [userId, idempotencyCutoffIso],
  });
  idempotencyKeysDeleted = Number(idemRes.rowsAffected || 0);

  // =========================================================================
  // 4. OrphanCollector (Attachments): Transition unreferenced to orphaned or pending_deletion
  // =========================================================================
  // 4a. Transition newly unreferenced attachments to orphaned
  const unrefAttsRes = await db.execute({
    sql: `SELECT a.id FROM attachments a
          LEFT JOIN attachment_references r ON a.id = r.resource_id AND a.user_id = r.user_id AND r.resource_type = 'attachment'
          WHERE a.user_id = ? AND a.status = 'referenced' AND r.id IS NULL
          LIMIT ?`,
    args: [userId, batchSize],
  });

  for (const row of unrefAttsRes.rows) {
    const attId = row.id as string;
    await db.execute({
      sql: `UPDATE attachments SET status = 'orphaned', orphaned_at = ? WHERE id = ? AND user_id = ?`,
      args: [nowIso, attId, userId],
    });
    orphanedAttachmentsIdentified++;
  }

  // 4b. Recover attachments that are now referenced again
  await db.execute({
    sql: `UPDATE attachments SET status = 'referenced', orphaned_at = NULL
          WHERE user_id = ? AND status = 'orphaned' AND id IN (
            SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'attachment'
          )`,
    args: [userId, userId],
  });

  // 4c. Eligible orphaned attachments past grace period -> queue destruction jobs
  const eligibleAttsRes = await db.execute({
    sql: `SELECT id, cloud_public_id FROM attachments
          WHERE user_id = ? AND ((status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1)
          LIMIT ?`,
    args: [userId, orphanCutoffIso, batchSize],
  });

  for (const row of eligibleAttsRes.rows) {
    const attId = row.id as string;
    const cloudPublicId = row.cloud_public_id as string | null;

    // Check if destruction job already exists
    const existingJob = await db.execute({
      sql: `SELECT id FROM destruction_jobs WHERE user_id = ? AND resource_id = ? AND state IN ('pending', 'processing', 'retrying')`,
      args: [userId, attId],
    });

    if (existingJob.rows.length === 0) {
      await db.execute({
        sql: `INSERT INTO destruction_jobs (
                id, user_id, resource_type, resource_id, cloudinary_public_id, operation,
                state, attempt_count, available_at, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        args: [
          crypto.randomUUID(),
          userId,
          'attachment',
          attId,
          cloudPublicId || null,
          'delete_attachment',
          'pending',
          0,
          nowIso,
          nowIso,
          nowIso,
        ],
      });
      destructionJobsCreated++;
    }
    await db.execute({
      sql: `UPDATE attachments SET status = 'pending_deletion', updated_at = ? WHERE id = ? AND user_id = ?`,
      args: [nowIso, attId, userId],
    });
  }

  // =========================================================================
  // 5. OrphanCollector (Documents): Transition unreferenced to orphaned or pending_deletion
  // =========================================================================
  // 5a. Transition newly unreferenced documents to orphaned
  const unrefDocsRes = await db.execute({
    sql: `SELECT d.id FROM documents d
          LEFT JOIN attachment_references r ON d.id = r.resource_id AND d.user_id = r.user_id AND r.resource_type = 'document'
          WHERE d.user_id = ? AND d.status = 'referenced' AND r.id IS NULL
          LIMIT ?`,
    args: [userId, batchSize],
  });

  for (const row of unrefDocsRes.rows) {
    const docId = row.id as string;
    await db.execute({
      sql: `UPDATE documents SET status = 'orphaned', orphaned_at = ? WHERE id = ? AND user_id = ?`,
      args: [nowIso, docId, userId],
    });
    orphanedDocumentsIdentified++;
  }

  // 5b. Recover documents that are referenced again
  await db.execute({
    sql: `UPDATE documents SET status = 'referenced', orphaned_at = NULL
          WHERE user_id = ? AND status = 'orphaned' AND id IN (
            SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'document'
          )`,
    args: [userId, userId],
  });

  // 5c. Eligible orphaned documents past grace period -> queue destruction jobs
  const eligibleDocsRes = await db.execute({
    sql: `SELECT id, cloud_public_id FROM documents
          WHERE user_id = ? AND ((status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1)
          LIMIT ?`,
    args: [userId, orphanCutoffIso, batchSize],
  });

  for (const row of eligibleDocsRes.rows) {
    const docId = row.id as string;
    const cloudPublicId = row.cloud_public_id as string | null;

    const existingJob = await db.execute({
      sql: `SELECT id FROM destruction_jobs WHERE user_id = ? AND resource_id = ? AND state IN ('pending', 'processing', 'retrying')`,
      args: [userId, docId],
    });

    if (existingJob.rows.length === 0) {
      await db.execute({
        sql: `INSERT INTO destruction_jobs (
                id, user_id, resource_type, resource_id, cloudinary_public_id, operation,
                state, attempt_count, available_at, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        args: [
          crypto.randomUUID(),
          userId,
          'document',
          docId,
          cloudPublicId || null,
          'delete_document',
          'pending',
          0,
          nowIso,
          nowIso,
          nowIso,
        ],
      });
      destructionJobsCreated++;
    }
    await db.execute({
      sql: `UPDATE documents SET status = 'pending_deletion', updated_at = ? WHERE id = ? AND user_id = ?`,
      args: [nowIso, docId, userId],
    });
  }

  // =========================================================================
  // 6. DestructionJobProcessor: Execute pending Cloudinary & DB deletions
  // =========================================================================
  const jobResult: DestructionJobResult = await processDestructionJobs(db, userId, 20);

  // =========================================================================
  // 7. TombstoneCollector: Clean up permanently deleted notes past safe boundary
  // =========================================================================
  if (safeBoundaryRevision > 0) {
    const candidateTombstonesRes = await db.execute({
      sql: `SELECT id FROM notes
            WHERE user_id = ? AND deleted_at IS NOT NULL AND revision < ?
            LIMIT ?`,
      args: [userId, safeBoundaryRevision, batchSize],
    });

    if (candidateTombstonesRes.rows.length > 0) {
      const tIds = candidateTombstonesRes.rows.map(r => r.id as string);
      const placeholders = tIds.map(() => '?').join(',');
      const delRes = await db.execute({
        sql: `DELETE FROM notes WHERE user_id = ? AND id IN (${placeholders})`,
        args: [userId, ...tIds],
      });
      tombstonesCleaned = Number(delRes.rowsAffected || tIds.length);
    }
  }

  const finishedAt = new Date();
  const finalProfile = await profileUserStorage(db, userId, safeBoundaryRevision, orphanGracePeriodDays);

  return {
    runId,
    userId,
    dryRun: false,
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: finishedAt.getTime() - startedAt.getTime(),
    safeSyncBoundaryRevision: safeBoundaryRevision,
    syncChangesInspected: initialProfile.tables.syncChanges.rowCount,
    syncChangesDeleted,
    noteVersionsInspected: initialProfile.tables.noteVersions.rowCount,
    noteVersionsDeleted,
    idempotencyKeysDeleted,
    orphanedAttachmentsIdentified,
    orphanedDocumentsIdentified,
    destructionJobsCreated,
    destructionJobsProcessed: jobResult.jobsProcessed,
    destructionJobsCompleted: jobResult.jobsCompleted,
    destructionJobsFailed: jobResult.jobsFailed,
    tombstonesCleaned,
    estimatedBytesReclaimed: Math.max(0, initialProfile.totalEstimatedBytes - finalProfile.totalEstimatedBytes),
    profile: finalProfile,
  };
}
