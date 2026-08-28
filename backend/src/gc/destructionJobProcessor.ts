import { Client } from '@libsql/client';
import { deleteCloudinaryResource } from '../attachments/cloudinaryService.js';

export interface DestructionJobResult {
  jobsProcessed: number;
  jobsCompleted: number;
  jobsRetried: number;
  jobsFailed: number;
  details: Array<{
    id: string;
    resourceType: string;
    resourceId: string;
    state: string;
    error?: string;
  }>;
}

export async function processDestructionJobs(
  db: Client,
  userId: string,
  batchSize: number = 20
): Promise<DestructionJobResult> {
  const now = new Date();
  const nowIso = now.toISOString();

  // Find eligible jobs: state IN ('pending', 'retrying') AND available_at <= now
  const pendingJobsRes = await db.execute({
    sql: `SELECT id, resource_type, resource_id, cloudinary_public_id, operation, attempt_count
          FROM destruction_jobs
          WHERE user_id = ? AND state IN ('pending', 'retrying') AND available_at <= ?
          ORDER BY created_at ASC
          LIMIT ?`,
    args: [userId, nowIso, batchSize],
  });

  let completed = 0;
  let retried = 0;
  let failed = 0;
  const details: DestructionJobResult['details'] = [];

  for (const row of pendingJobsRes.rows) {
    const jobId = row.id as string;
    const resourceType = row.resource_type as string;
    const resourceId = row.resource_id as string;
    const cloudinaryPublicId = row.cloudinary_public_id as string | null;
    const attemptCount = Number(row.attempt_count || 0);

    // Transition job to processing
    await db.execute({
      sql: `UPDATE destruction_jobs SET state = 'processing', updated_at = ? WHERE id = ? AND user_id = ?`,
      args: [nowIso, jobId, userId],
    });

    let deleteOk = true;
    let errorMessage: string | undefined;
    let isRetryable = false;

    // 1. Delete from Cloudinary if public ID exists
    if (cloudinaryPublicId && cloudinaryPublicId.trim().length > 0) {
      const cloudRes = await deleteCloudinaryResource(cloudinaryPublicId.trim());
      if (!cloudRes.success && cloudRes.result === 'error') {
        deleteOk = false;
        errorMessage = cloudRes.error || 'Failed to destroy Cloudinary resource';
        isRetryable = cloudRes.retryable;
      }
    }

    if (deleteOk) {
      // 2. Remove DB records cleanly
      if (resourceType === 'attachment') {
        await db.execute({
          sql: 'DELETE FROM attachments WHERE id = ? AND user_id = ?',
          args: [resourceId, userId],
        });
        await db.execute({
          sql: 'DELETE FROM attachment_references WHERE resource_id = ? AND user_id = ?',
          args: [resourceId, userId],
        });
      } else if (resourceType === 'document') {
        await db.execute({
          sql: 'DELETE FROM document_ocr_pages WHERE document_id = ? AND user_id = ?',
          args: [resourceId, userId],
        });
        await db.execute({
          sql: 'DELETE FROM documents WHERE id = ? AND user_id = ?',
          args: [resourceId, userId],
        });
        await db.execute({
          sql: 'DELETE FROM attachment_references WHERE resource_id = ? AND user_id = ?',
          args: [resourceId, userId],
        });
      }

      await db.execute({
        sql: `UPDATE destruction_jobs SET state = 'completed', updated_at = ? WHERE id = ? AND user_id = ?`,
        args: [new Date().toISOString(), jobId, userId],
      });

      completed++;
      details.push({
        id: jobId,
        resourceType,
        resourceId,
        state: 'completed',
      });
    } else {
      const nextAttempt = attemptCount + 1;
      const maxAttempts = 5;
      if (nextAttempt >= maxAttempts || !isRetryable) {
        await db.execute({
          sql: `UPDATE destruction_jobs
                SET state = 'failed', attempt_count = ?, last_error = ?, updated_at = ?
                WHERE id = ? AND user_id = ?`,
          args: [nextAttempt, errorMessage || 'Maximum retry attempts exceeded', new Date().toISOString(), jobId, userId],
        });
        failed++;
        details.push({
          id: jobId,
          resourceType,
          resourceId,
          state: 'failed',
          error: errorMessage,
        });
      } else {
        // Exponential backoff: 2^attempt * 10 seconds
        const delaySeconds = Math.pow(2, nextAttempt) * 10;
        const nextAvailableAt = new Date(Date.now() + delaySeconds * 1000).toISOString();
        await db.execute({
          sql: `UPDATE destruction_jobs
                SET state = 'retrying', attempt_count = ?, available_at = ?, last_error = ?, updated_at = ?
                WHERE id = ? AND user_id = ?`,
          args: [nextAttempt, nextAvailableAt, errorMessage || 'Transient error', new Date().toISOString(), jobId, userId],
        });
        retried++;
        details.push({
          id: jobId,
          resourceType,
          resourceId,
          state: 'retrying',
          error: errorMessage,
        });
      }
    }
  }

  return {
    jobsProcessed: pendingJobsRes.rows.length,
    jobsCompleted: completed,
    jobsRetried: retried,
    jobsFailed: failed,
    details,
  };
}
