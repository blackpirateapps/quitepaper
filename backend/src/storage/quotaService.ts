import { Client } from '@libsql/client';
import crypto from 'crypto';
import { ApiError } from '../errors/apiError.js';

/**
 * Storage & Plan Constants (Authoritative definitions for Quiet Paper Backend)
 * 1 MB = 1,000,000 bytes
 * 1 GB = 1,000,000,000 bytes
 * 10 MB = 10,000,000 bytes
 * 10 GB = 10,000,000,000 bytes
 */
export const BYTES_PER_MB = 1_000_000;
export const BYTES_PER_GB = 1_000_000_000;

export const MAX_FILE_SIZE_BYTES = 10 * BYTES_PER_MB; // 10,000,000 bytes (10 MB)
export const FREE_STORAGE_BYTES = 1 * BYTES_PER_GB;   // 1,000,000,000 bytes (1 GB)
export const PREMIUM_STORAGE_BYTES = 10 * BYTES_PER_GB; // 10,000,000,000 bytes (10 GB)

export const PLAN_LIMITS = {
  free: FREE_STORAGE_BYTES,
  premium: PREMIUM_STORAGE_BYTES,
} as const;

export type UserPlan = 'free' | 'premium';

export const RESERVATION_EXPIRY_SECONDS = 1800; // 30 minutes TTL for upload reservations
export const NEAR_QUOTA_THRESHOLD_RATIO = 0.8; // 80% capacity warning

export interface StorageQuotaProfile {
  plan: UserPlan;
  usedBytes: number;
  reservedBytes: number;
  limitBytes: number;
  remainingBytes: number;
  isOverQuota: boolean;
  overQuotaBytes: number;
  usageFraction: number;
  maxFileSizeBytes: number;
}

export interface StorageReservationRecord {
  id: string;
  userId: string;
  resourceType: 'attachment' | 'document';
  resourceId: string;
  reservedBytes: number;
  status: 'pending' | 'finalized' | 'released' | 'expired';
  createdAt: string;
  expiresAt: string;
  finalizedAt: string | null;
}

/**
 * Retrieves the user's storage quota profile, cleaning up any expired reservations first.
 */
export async function getUserQuotaProfile(db: Client, userId: string): Promise<StorageQuotaProfile> {
  // Prune any expired reservations for this user before calculating available capacity
  await cleanupExpiredReservations(db, userId);

  const res = await db.execute({
    sql: 'SELECT plan, storage_used_bytes, storage_reserved_bytes FROM users WHERE id = ? LIMIT 1',
    args: [userId],
  });

  if (res.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'User not found', 404);
  }

  const row = res.rows[0];
  const plan = ((row.plan as string) || 'free').toLowerCase() === 'premium' ? 'premium' : 'free';
  const usedBytes = Math.max(0, Number(row.storage_used_bytes || 0));
  const reservedBytes = Math.max(0, Number(row.storage_reserved_bytes || 0));
  const limitBytes = PLAN_LIMITS[plan];

  const totalCommittedAndReserved = usedBytes + reservedBytes;
  const remainingBytes = Math.max(0, limitBytes - totalCommittedAndReserved);
  const isOverQuota = usedBytes > limitBytes;
  const overQuotaBytes = isOverQuota ? usedBytes - limitBytes : 0;
  const usageFraction = limitBytes > 0 ? Number((usedBytes / limitBytes).toFixed(4)) : 1.0;

  return {
    plan,
    usedBytes,
    reservedBytes,
    limitBytes,
    remainingBytes,
    isOverQuota,
    overQuotaBytes,
    usageFraction,
    maxFileSizeBytes: MAX_FILE_SIZE_BYTES,
  };
}

/**
 * Releases expired pending reservations and adjusts users.storage_reserved_bytes atomically.
 */
export async function cleanupExpiredReservations(db: Client, userId?: string): Promise<number> {
  const nowIso = new Date().toISOString();

  let expiredRes;
  if (userId) {
    expiredRes = await db.execute({
      sql: `SELECT id, user_id, reserved_bytes
            FROM storage_reservations
            WHERE user_id = ? AND status = 'pending' AND expires_at < ?`,
      args: [userId, nowIso],
    });
  } else {
    expiredRes = await db.execute({
      sql: `SELECT id, user_id, reserved_bytes
            FROM storage_reservations
            WHERE status = 'pending' AND expires_at < ?
            LIMIT 200`,
      args: [nowIso],
    });
  }

  if (expiredRes.rows.length === 0) {
    return 0;
  }

  for (const row of expiredRes.rows) {
    const resId = row.id as string;
    const uId = row.user_id as string;
    const bytes = Number(row.reserved_bytes || 0);

    await db.execute({
      sql: `UPDATE storage_reservations SET status = 'expired' WHERE id = ? AND status = 'pending'`,
      args: [resId],
    });

    if (bytes > 0) {
      await db.execute({
        sql: `UPDATE users SET storage_reserved_bytes = MAX(0, storage_reserved_bytes - ?) WHERE id = ?`,
        args: [bytes, uId],
      });
    }
  }

  return expiredRes.rows.length;
}

/**
 * Validates file size and reserves storage quota for an upcoming Cloudinary upload.
 * Prevents race conditions during concurrent uploads using atomic DB updates.
 */
export async function reserveUploadStorage(
  db: Client,
  userId: string,
  resourceType: 'attachment' | 'document',
  resourceId: string,
  requestedBytes: number,
  previousBytes: number = 0
): Promise<{ reservationId: string; reservedBytes: number }> {
  // 1. Validate individual file size limit (10 MB maximum for all plans)
  if (requestedBytes > MAX_FILE_SIZE_BYTES) {
    throw new ApiError(
      'FILE_TOO_LARGE',
      `File size (${requestedBytes} bytes) exceeds maximum limit of 10 MB (${MAX_FILE_SIZE_BYTES} bytes).`,
      400,
      {
        maxBytes: MAX_FILE_SIZE_BYTES,
        providedBytes: requestedBytes,
      }
    );
  }

  // 2. Clean up expired reservations for this user first
  await cleanupExpiredReservations(db, userId);

  // 3. Check if an active pending reservation already exists for this exact resource
  const existingRes = await db.execute({
    sql: `SELECT id, reserved_bytes, expires_at
          FROM storage_reservations
          WHERE user_id = ? AND resource_type = ? AND resource_id = ? AND status = 'pending'
          LIMIT 1`,
    args: [userId, resourceType, resourceId],
  });

  const now = new Date();
  const nowIso = now.toISOString();
  const expiresAtIso = new Date(now.getTime() + RESERVATION_EXPIRY_SECONDS * 1000).toISOString();

  if (existingRes.rows.length > 0) {
    const existing = existingRes.rows[0];
    const prevReserved = Number(existing.reserved_bytes || 0);

    if (prevReserved === requestedBytes) {
      // Refresh expiry timestamp
      await db.execute({
        sql: `UPDATE storage_reservations SET expires_at = ? WHERE id = ?`,
        args: [expiresAtIso, existing.id as string],
      });
      return { reservationId: existing.id as string, reservedBytes: requestedBytes };
    }

    // Release previous reservation before re-reserving
    await db.execute({
      sql: `UPDATE storage_reservations SET status = 'released' WHERE id = ?`,
      args: [existing.id as string],
    });
    if (prevReserved > 0) {
      await db.execute({
        sql: `UPDATE users SET storage_reserved_bytes = MAX(0, storage_reserved_bytes - ?) WHERE id = ?`,
        args: [prevReserved, userId],
      });
    }
  }

  // 4. Check if we are replacing an existing committed resource (e.g. re-uploading)
  let existingCommittedBytes = previousBytes || 0;
  if (existingCommittedBytes === 0) {
    if (resourceType === 'attachment') {
      const attRow = await db.execute({
        sql: 'SELECT byte_size FROM attachments WHERE id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1',
        args: [resourceId, userId],
      });
      if (attRow.rows.length > 0) {
        existingCommittedBytes = Number(attRow.rows[0].byte_size || 0);
      }
    } else if (resourceType === 'document') {
      const docRow = await db.execute({
        sql: 'SELECT byte_size FROM documents WHERE id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1',
        args: [resourceId, userId],
      });
      if (docRow.rows.length > 0) {
        existingCommittedBytes = Number(docRow.rows[0].byte_size || 0);
      }
    }
  }

  // 5. Query user quota & plan
  const userRes = await db.execute({
    sql: 'SELECT plan, storage_used_bytes, storage_reserved_bytes FROM users WHERE id = ? LIMIT 1',
    args: [userId],
  });

  if (userRes.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'User not found', 404);
  }

  const userRow = userRes.rows[0];
  const plan = ((userRow.plan as string) || 'free').toLowerCase() === 'premium' ? 'premium' : 'free';
  const usedBytes = Math.max(0, Number(userRow.storage_used_bytes || 0));
  const reservedBytes = Math.max(0, Number(userRow.storage_reserved_bytes || 0));
  const limitBytes = PLAN_LIMITS[plan];

  // The additional capacity needed takes into account replacing the old resource
  const deltaBytesNeeded = Math.max(0, requestedBytes - existingCommittedBytes);
  const remainingBytes = Math.max(0, limitBytes - (usedBytes + reservedBytes));

  if (deltaBytesNeeded > remainingBytes || (usedBytes + reservedBytes + deltaBytesNeeded) > limitBytes) {
    throw new ApiError(
      'STORAGE_QUOTA_EXCEEDED',
      `Storage quota exceeded. Your ${plan} plan allows up to ${limitBytes / BYTES_PER_GB} GB.`,
      400,
      {
        plan,
        usedBytes,
        reservedBytes,
        limitBytes,
        remainingBytes,
        requiredBytes: requestedBytes,
      }
    );
  }

  // 6. Concurrency Safety: Atomically update reserved bytes with conditional check
  const updateRes = await db.execute({
    sql: `UPDATE users
          SET storage_reserved_bytes = storage_reserved_bytes + ?
          WHERE id = ? AND (storage_used_bytes + storage_reserved_bytes + ?) <= ?`,
    args: [deltaBytesNeeded, userId, deltaBytesNeeded, limitBytes],
  });

  if (updateRes.rowsAffected === 0) {
    // Re-check state to provide accurate remaining capacity error
    const freshProfile = await getUserQuotaProfile(db, userId);
    throw new ApiError(
      'STORAGE_QUOTA_EXCEEDED',
      `Storage quota exceeded due to concurrent upload reservations.`,
      400,
      {
        plan: freshProfile.plan,
        usedBytes: freshProfile.usedBytes,
        reservedBytes: freshProfile.reservedBytes,
        limitBytes: freshProfile.limitBytes,
        remainingBytes: freshProfile.remainingBytes,
        requiredBytes: requestedBytes,
      }
    );
  }

  // 7. Record the reservation
  const reservationId = crypto.randomUUID();
  await db.execute({
    sql: `INSERT INTO storage_reservations (
            id, user_id, resource_type, resource_id, reserved_bytes, status,
            created_at, expires_at, finalized_at
          ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, NULL)`,
    args: [reservationId, userId, resourceType, resourceId, deltaBytesNeeded, nowIso, expiresAtIso],
  });

  return { reservationId, reservedBytes: deltaBytesNeeded };
}

/**
 * Commits an uploaded resource into authoritative storage_used_bytes and finalizes its reservation.
 * Idempotent under network retries and duplicate confirmations.
 */
export async function commitUploadStorage(
  db: Client,
  userId: string,
  resourceType: 'attachment' | 'document',
  resourceId: string,
  actualBytes: number,
  previousBytes?: number
): Promise<void> {
  // 1. Validate actual file size limit
  if (actualBytes > MAX_FILE_SIZE_BYTES) {
    throw new ApiError(
      'FILE_TOO_LARGE',
      `Uploaded file size (${actualBytes} bytes) exceeds maximum limit of 10 MB (${MAX_FILE_SIZE_BYTES} bytes).`,
      400,
      {
        maxBytes: MAX_FILE_SIZE_BYTES,
        providedBytes: actualBytes,
      }
    );
  }

  const nowIso = new Date().toISOString();

  // 2. Check previous committed byte size for this resource
  let previousCommittedBytes = 0;
  let resourceRowFound = false;

  if (previousBytes !== undefined) {
    previousCommittedBytes = previousBytes;
    resourceRowFound = true;
  } else if (resourceType === 'attachment') {
    const existing = await db.execute({
      sql: 'SELECT byte_size, is_deleted FROM attachments WHERE id = ? AND user_id = ? LIMIT 1',
      args: [resourceId, userId],
    });
    if (existing.rows.length > 0) {
      resourceRowFound = true;
      previousCommittedBytes = Number(existing.rows[0].byte_size || 0);
    }
  } else if (resourceType === 'document') {
    const existing = await db.execute({
      sql: 'SELECT byte_size, is_deleted FROM documents WHERE id = ? AND user_id = ? LIMIT 1',
      args: [resourceId, userId],
    });
    if (existing.rows.length > 0) {
      resourceRowFound = true;
      previousCommittedBytes = Number(existing.rows[0].byte_size || 0);
    }
  }

  // 3. Find and finalize any reservation for this resource
  const resQuery = await db.execute({
    sql: `SELECT id, reserved_bytes, status
          FROM storage_reservations
          WHERE user_id = ? AND resource_type = ? AND resource_id = ?
          ORDER BY created_at DESC
          LIMIT 1`,
    args: [userId, resourceType, resourceId],
  });

  let reservedBytesToRelease = 0;
  if (resQuery.rows.length > 0) {
    const rRow = resQuery.rows[0];
    if (rRow.status === 'finalized') {
      if (resourceRowFound && previousCommittedBytes === actualBytes) {
        return;
      }
      if (!resourceRowFound) {
        return;
      }
    } else if (rRow.status === 'pending') {
      reservedBytesToRelease = Number(rRow.reserved_bytes || 0);
      await db.execute({
        sql: `UPDATE storage_reservations SET status = 'finalized', finalized_at = ? WHERE id = ?`,
        args: [nowIso, rRow.id as string],
      });
    }
  } else {
    if (resourceRowFound && previousCommittedBytes === actualBytes) {
      return;
    }
  }

  // 4. Calculate used delta
  const usedDelta = actualBytes - previousCommittedBytes;

  // 5. Transactionally update user counters
  await db.execute({
    sql: `UPDATE users
          SET storage_used_bytes = MAX(0, storage_used_bytes + ?),
              storage_reserved_bytes = MAX(0, storage_reserved_bytes - ?)
          WHERE id = ?`,
    args: [usedDelta, reservedBytesToRelease, userId],
  });
}

/**
 * Releases committed storage and any lingering reservations when a resource is permanently deleted.
 * Idempotent and never allows usage counters to become negative.
 */
export async function releaseStorageForResource(
  db: Client,
  userId: string,
  resourceType: 'attachment' | 'document',
  resourceId: string,
  committedBytes: number
): Promise<void> {
  // 1. Release any lingering pending reservation
  const pendingRes = await db.execute({
    sql: `SELECT id, reserved_bytes FROM storage_reservations
          WHERE user_id = ? AND resource_type = ? AND resource_id = ? AND status = 'pending'`,
    args: [userId, resourceType, resourceId],
  });

  let reservedBytesToRelease = 0;
  for (const row of pendingRes.rows) {
    reservedBytesToRelease += Number(row.reserved_bytes || 0);
    await db.execute({
      sql: `UPDATE storage_reservations SET status = 'released' WHERE id = ?`,
      args: [row.id as string],
    });
  }

  // 2. Decrement storage counters safely
  if (committedBytes > 0 || reservedBytesToRelease > 0) {
    await db.execute({
      sql: `UPDATE users
            SET storage_used_bytes = MAX(0, storage_used_bytes - ?),
                storage_reserved_bytes = MAX(0, storage_reserved_bytes - ?)
            WHERE id = ?`,
      args: [Math.max(0, committedBytes), reservedBytesToRelease, userId],
    });
  }
}

/**
 * Recalculates exact authoritative storage used from attachments and documents tables.
 */
export async function recalculateUserStorageUsage(
  db: Client,
  userId: string
): Promise<{ authoritativeUsedBytes: number; authoritativeReservedBytes: number }> {
  const nowIso = new Date().toISOString();

  // 1. Attachments storage
  const attRes = await db.execute({
    sql: `SELECT COALESCE(SUM(byte_size), 0) as total_bytes
          FROM attachments
          WHERE user_id = ? AND is_deleted = 0 AND (status IS NULL OR status != 'pending_deletion')`,
    args: [userId],
  });
  const attBytes = Number(attRes.rows[0]?.total_bytes || 0);

  // 2. Documents storage
  const docRes = await db.execute({
    sql: `SELECT COALESCE(SUM(byte_size), 0) as total_bytes
          FROM documents
          WHERE user_id = ? AND is_deleted = 0 AND (status IS NULL OR status != 'pending_deletion')`,
    args: [userId],
  });
  const docBytes = Number(docRes.rows[0]?.total_bytes || 0);

  // 3. Active pending reservations
  const resRes = await db.execute({
    sql: `SELECT COALESCE(SUM(reserved_bytes), 0) as total_bytes
          FROM storage_reservations
          WHERE user_id = ? AND status = 'pending' AND expires_at >= ?`,
    args: [userId, nowIso],
  });
  const reservedBytes = Number(resRes.rows[0]?.total_bytes || 0);

  return {
    authoritativeUsedBytes: attBytes + docBytes,
    authoritativeReservedBytes: reservedBytes,
  };
}

/**
 * Reconciles materialized counter with true authoritative storage in case of drift.
 */
export async function reconcileUserStorageUsage(
  db: Client,
  userId: string,
  dryRun: boolean = false
): Promise<{
  userId: string;
  previousUsedBytes: number;
  newUsedBytes: number;
  previousReservedBytes: number;
  newReservedBytes: number;
  discrepancyFixed: boolean;
}> {
  const userRes = await db.execute({
    sql: 'SELECT storage_used_bytes, storage_reserved_bytes FROM users WHERE id = ? LIMIT 1',
    args: [userId],
  });

  if (userRes.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'User not found', 404);
  }

  const previousUsedBytes = Number(userRes.rows[0].storage_used_bytes || 0);
  const previousReservedBytes = Number(userRes.rows[0].storage_reserved_bytes || 0);

  const { authoritativeUsedBytes, authoritativeReservedBytes } = await recalculateUserStorageUsage(db, userId);

  const hasDiscrepancy =
    previousUsedBytes !== authoritativeUsedBytes ||
    previousReservedBytes !== authoritativeReservedBytes;

  if (hasDiscrepancy && !dryRun) {
    await db.execute({
      sql: `UPDATE users
            SET storage_used_bytes = ?, storage_reserved_bytes = ?
            WHERE id = ?`,
      args: [authoritativeUsedBytes, authoritativeReservedBytes, userId],
    });
  }

  return {
    userId,
    previousUsedBytes,
    newUsedBytes: authoritativeUsedBytes,
    previousReservedBytes,
    newReservedBytes: authoritativeReservedBytes,
    discrepancyFixed: hasDiscrepancy && !dryRun,
  };
}

/**
 * Changes a user's plan (Free <-> Premium) and records an immutable administrative audit log.
 */
export async function changeUserPlan(
  db: Client,
  userId: string,
  newPlan: UserPlan,
  auditContext?: { adminIdentifier?: string; reason?: string }
): Promise<{
  user: { id: string; email: string | null; plan: UserPlan; previousPlan: UserPlan };
  quota: StorageQuotaProfile;
}> {
  const normalizedPlan: UserPlan = newPlan.toLowerCase() === 'premium' ? 'premium' : 'free';

  const userRes = await db.execute({
    sql: 'SELECT id, email, plan, storage_used_bytes FROM users WHERE id = ? LIMIT 1',
    args: [userId],
  });

  if (userRes.rows.length === 0) {
    throw new ApiError('NOT_FOUND', `User ${userId} not found`, 404);
  }

  const userRow = userRes.rows[0];
  const oldPlan: UserPlan = ((userRow.plan as string) || 'free').toLowerCase() === 'premium' ? 'premium' : 'free';
  const email = (userRow.email as string) || null;

  if (oldPlan !== normalizedPlan) {
    const nowIso = new Date().toISOString();

    // 1. Update user plan
    await db.execute({
      sql: 'UPDATE users SET plan = ?, updated_at = ? WHERE id = ?',
      args: [normalizedPlan, nowIso, userId],
    });

    // 2. Record audit log
    const auditId = crypto.randomUUID();
    await db.execute({
      sql: `INSERT INTO admin_audit_logs (
              id, admin_identifier, user_id, action, old_value, new_value, details_json, created_at
            ) VALUES (?, ?, ?, 'PLAN_CHANGED', ?, ?, ?, ?)`,
      args: [
        auditId,
        auditContext?.adminIdentifier || 'admin',
        userId,
        oldPlan,
        normalizedPlan,
        JSON.stringify({ reason: auditContext?.reason || 'Administrative action via Quiet Paper Admin' }),
        nowIso,
      ],
    });
  }

  const quota = await getUserQuotaProfile(db, userId);

  return {
    user: {
      id: userId,
      email,
      plan: normalizedPlan,
      previousPlan: oldPlan,
    },
    quota,
  };
}
