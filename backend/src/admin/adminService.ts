import { Client } from '@libsql/client';
import { profileUserStorage, StorageProfileReport } from '../gc/storageProfiler.js';
import { runGarbageCollection, GcExecutionSummary } from '../gc/garbageCollector.js';
import {
  UserPlan,
  PLAN_LIMITS,
  getUserQuotaProfile,
  changeUserPlan,
  reconcileUserStorageUsage,
  StorageQuotaProfile,
} from '../storage/quotaService.js';
import {
  backfillMissingUserEmails,
  syncSingleUserEmail,
  EmailSyncResult,
} from '../auth/emailSyncService.js';

export interface AdminOverview {
  dbPingMs: number;
  users: {
    total: number;
    free: number;
    premium: number;
  };
  storageQuota: {
    totalCloudStorageUsed: number;
    freeStorageUsed: number;
    premiumStorageUsed: number;
    usersNearQuota: number;
    usersOverQuota: number;
  };
  notes: {
    total: number;
    active: number;
    archived: number;
    trashed: number;
    deleted: number;
    totalEncryptedBytes: number;
  };
  attachments: {
    total: number;
    totalBytes: number;
    deleted: number;
  };
  documents: {
    total: number;
    totalPages: number;
    totalBytes: number;
  };
  tags: {
    total: number;
  };
  devices: {
    total: number;
    activeLast30Days: number;
  };
  syncActivity: {
    changesLast24Hours: number;
    changesLast7Days: number;
    totalChanges: number;
  };
  destructionJobs: {
    pending: number;
    failed: number;
    completed: number;
  };
}

export interface AdminUserListItem {
  id: string;
  firebaseUid: string;
  email: string | null;
  plan: UserPlan;
  storageUsedBytes: number;
  storageLimitBytes: number;
  isOverQuota: boolean;
  createdAt: string;
  updatedAt: string;
  notesCount: number;
  devicesCount: number;
  attachmentsCount: number;
  documentsCount: number;
}

export interface AdminUsersResult {
  users: AdminUserListItem[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface AdminAuditLogEntry {
  id: string;
  adminIdentifier: string | null;
  action: string;
  oldValue: string | null;
  newValue: string | null;
  details: string | null;
  createdAt: string;
}

export interface AdminUserDetail {
  user: {
    id: string;
    firebaseUid: string;
    email: string | null;
    createdAt: string;
    updatedAt: string;
  };
  quota: StorageQuotaProfile;
  encryptionKey: {
    configured: boolean;
    keyVersion?: number;
    kdfAlgorithm?: string;
    hasRecoveryKey?: boolean;
    formatVersion?: number;
    updatedAt?: string;
  };
  devices: Array<{
    id: string;
    deviceName: string | null;
    clientVersion: string | null;
    lastAcknowledgedRevision: number;
    lastSeenAt: string;
    createdAt: string;
  }>;
  recentChanges: Array<{
    id: string;
    noteId: string;
    revision: number;
    changeType: string;
    timestamp: string;
  }>;
  auditLogs: AdminAuditLogEntry[];
  storageProfile: StorageProfileReport;
}

export interface AdminStorageOverview {
  totalAttachmentBytes: number;
  totalDocumentBytes: number;
  attachmentsCount: number;
  documentsCount: number;
  totalUsers: number;
  freeUsers: number;
  premiumUsers: number;
  aggregateFreeUsage: number;
  aggregatePremiumUsage: number;
  usersOverQuota: number;
  usersNearQuota: number;
  destructionJobs: Array<{
    id: string;
    userId: string;
    resourceType: string;
    resourceId: string;
    cloudinaryPublicId: string | null;
    operation: string;
    state: string;
    attemptCount: number;
    availableAt: string;
    lastError: string | null;
    createdAt: string;
    updatedAt: string;
  }>;
}

/**
 * Gathers aggregate metrics and Turso latency for the admin overview dashboard.
 */
export async function getAdminOverview(db: Client): Promise<AdminOverview> {
  const startPing = Date.now();
  await db.execute('SELECT 1');
  const dbPingMs = Date.now() - startPing;

  const now = new Date();
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

  // 1. Users & Storage Quota aggregate statistics
  const userStatsRes = await db.execute(`
    SELECT
      COUNT(*) as total_users,
      COUNT(CASE WHEN plan = 'free' OR plan IS NULL THEN 1 END) as free_users,
      COUNT(CASE WHEN plan = 'premium' THEN 1 END) as premium_users,
      COALESCE(SUM(storage_used_bytes), 0) as total_storage_used,
      COALESCE(SUM(CASE WHEN plan = 'free' OR plan IS NULL THEN storage_used_bytes ELSE 0 END), 0) as free_storage_used,
      COALESCE(SUM(CASE WHEN plan = 'premium' THEN storage_used_bytes ELSE 0 END), 0) as premium_storage_used,
      COUNT(CASE
        WHEN (plan = 'free' OR plan IS NULL) AND storage_used_bytes >= 800000000 AND storage_used_bytes <= 1000000000 THEN 1
        WHEN plan = 'premium' AND storage_used_bytes >= 8000000000 AND storage_used_bytes <= 10000000000 THEN 1
      END) as near_quota_count,
      COUNT(CASE
        WHEN (plan = 'free' OR plan IS NULL) AND storage_used_bytes > 1000000000 THEN 1
        WHEN plan = 'premium' AND storage_used_bytes > 10000000000 THEN 1
      END) as over_quota_count
    FROM users
  `);
  const userStatsRow = userStatsRes.rows[0];

  const totalUsers = Number(userStatsRow?.total_users || 0);
  const freeUsers = Number(userStatsRow?.free_users || 0);
  const premiumUsers = Number(userStatsRow?.premium_users || 0);
  const totalCloudStorageUsed = Number(userStatsRow?.total_storage_used || 0);
  const freeStorageUsed = Number(userStatsRow?.free_storage_used || 0);
  const premiumStorageUsed = Number(userStatsRow?.premium_storage_used || 0);
  const usersNearQuota = Number(userStatsRow?.near_quota_count || 0);
  const usersOverQuota = Number(userStatsRow?.over_quota_count || 0);

  // 2. Notes
  const notesRes = await db.execute(`
    SELECT
      COUNT(*) as total,
      COUNT(CASE WHEN deleted_at IS NULL AND archived = 0 AND trashed = 0 THEN 1 END) as active,
      COUNT(CASE WHEN deleted_at IS NULL AND archived = 1 THEN 1 END) as archived,
      COUNT(CASE WHEN deleted_at IS NULL AND trashed = 1 THEN 1 END) as trashed,
      COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted,
      COALESCE(SUM(LENGTH(content_ciphertext) + LENGTH(content_nonce)), 0) as total_bytes
    FROM notes
  `);
  const notesRow = notesRes.rows[0];

  // 3. Attachments
  const attachmentsRes = await db.execute(`
    SELECT
      COUNT(CASE WHEN is_deleted = 0 THEN 1 END) as total,
      COUNT(CASE WHEN is_deleted = 1 THEN 1 END) as deleted,
      COALESCE(SUM(CASE WHEN is_deleted = 0 THEN byte_size ELSE 0 END), 0) as total_bytes
    FROM attachments
  `);
  const attRow = attachmentsRes.rows[0];

  // 4. Documents
  const documentsRes = await db.execute(`
    SELECT
      COUNT(CASE WHEN is_deleted = 0 THEN 1 END) as total,
      COALESCE(SUM(CASE WHEN is_deleted = 0 THEN page_count ELSE 0 END), 0) as total_pages,
      COALESCE(SUM(CASE WHEN is_deleted = 0 THEN byte_size ELSE 0 END), 0) as total_bytes
    FROM documents
  `);
  const docRow = documentsRes.rows[0];

  // 5. Tags
  let totalTags = 0;
  try {
    const tagsRes = await db.execute('SELECT COUNT(*) as count FROM tags WHERE is_deleted = 0');
    totalTags = Number(tagsRes.rows[0]?.count || 0);
  } catch {
    // Tags table may be empty or newly migrated
  }

  // 6. Devices
  let totalDevices = 0;
  let activeLast30Days = 0;
  try {
    const devicesRes = await db.execute({
      sql: `SELECT
              COUNT(*) as total,
              COUNT(CASE WHEN last_seen_at >= ? THEN 1 END) as active_30d
            FROM sync_devices`,
      args: [thirtyDaysAgo],
    });
    totalDevices = Number(devicesRes.rows[0]?.total || 0);
    activeLast30Days = Number(devicesRes.rows[0]?.active_30d || 0);
  } catch {
    // sync_devices fallback
  }

  // 7. Sync Activity
  const syncRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total,
            COUNT(CASE WHEN timestamp >= ? THEN 1 END) as last_24h,
            COUNT(CASE WHEN timestamp >= ? THEN 1 END) as last_7d
          FROM sync_changes`,
    args: [dayAgo, weekAgo],
  });
  const syncRow = syncRes.rows[0];

  // 8. Destruction Jobs
  let pendingJobs = 0;
  let failedJobs = 0;
  let completedJobs = 0;
  try {
    const jobsRes = await db.execute(`
      SELECT
        COUNT(CASE WHEN state IN ('pending', 'processing', 'retrying') THEN 1 END) as pending,
        COUNT(CASE WHEN state = 'failed' THEN 1 END) as failed,
        COUNT(CASE WHEN state = 'completed' THEN 1 END) as completed
      FROM destruction_jobs
    `);
    pendingJobs = Number(jobsRes.rows[0]?.pending || 0);
    failedJobs = Number(jobsRes.rows[0]?.failed || 0);
    completedJobs = Number(jobsRes.rows[0]?.completed || 0);
  } catch {
    // destruction_jobs table may be newly created
  }

  return {
    dbPingMs,
    users: {
      total: totalUsers,
      free: freeUsers,
      premium: premiumUsers,
    },
    storageQuota: {
      totalCloudStorageUsed,
      freeStorageUsed,
      premiumStorageUsed,
      usersNearQuota,
      usersOverQuota,
    },
    notes: {
      total: Number(notesRow?.total || 0),
      active: Number(notesRow?.active || 0),
      archived: Number(notesRow?.archived || 0),
      trashed: Number(notesRow?.trashed || 0),
      deleted: Number(notesRow?.deleted || 0),
      totalEncryptedBytes: Number(notesRow?.total_bytes || 0),
    },
    attachments: {
      total: Number(attRow?.total || 0),
      totalBytes: Number(attRow?.total_bytes || 0),
      deleted: Number(attRow?.deleted || 0),
    },
    documents: {
      total: Number(docRow?.total || 0),
      totalPages: Number(docRow?.total_pages || 0),
      totalBytes: Number(docRow?.total_bytes || 0),
    },
    tags: {
      total: totalTags,
    },
    devices: {
      total: totalDevices,
      activeLast30Days,
    },
    syncActivity: {
      changesLast24Hours: Number(syncRow?.last_24h || 0),
      changesLast7Days: Number(syncRow?.last_7d || 0),
      totalChanges: Number(syncRow?.total || 0),
    },
    destructionJobs: {
      pending: pendingJobs,
      failed: failedJobs,
      completed: completedJobs,
    },
  };
}

/**
 * Retrieves paginated list of users with email, plan, storage counters, and counts.
 */
export async function getAdminUsers(
  db: Client,
  options: { search?: string; page?: number; limit?: number } = {}
): Promise<AdminUsersResult> {
  const page = Math.max(1, options.page || 1);
  const limit = Math.max(1, Math.min(100, options.limit || 20));
  const offset = (page - 1) * limit;
  const search = options.search?.trim();

  let countSql = 'SELECT COUNT(*) as count FROM users u';
  let dataSql = `
    SELECT
      u.id,
      u.firebase_uid,
      u.email,
      u.plan,
      u.storage_used_bytes,
      u.created_at,
      u.updated_at,
      (SELECT COUNT(*) FROM notes n WHERE n.user_id = u.id AND n.deleted_at IS NULL) as notes_count,
      (SELECT COUNT(*) FROM sync_devices d WHERE d.user_id = u.id) as devices_count,
      (SELECT COUNT(*) FROM attachments a WHERE a.user_id = u.id AND a.is_deleted = 0) as attachments_count,
      (SELECT COUNT(*) FROM documents doc WHERE doc.user_id = u.id AND doc.is_deleted = 0) as documents_count
    FROM users u
  `;
  const countArgs: any[] = [];
  const dataArgs: any[] = [];

  if (search) {
    const searchPattern = `%${search}%`;
    const whereClause = ' WHERE (u.id LIKE ? OR u.firebase_uid LIKE ? OR LOWER(u.email) LIKE LOWER(?))';
    countSql += whereClause;
    countArgs.push(searchPattern, searchPattern, searchPattern);
    dataSql += whereClause;
    dataArgs.push(searchPattern, searchPattern, searchPattern);
  }

  dataSql += ' ORDER BY u.created_at DESC LIMIT ? OFFSET ?';
  dataArgs.push(limit, offset);

  const countRes = await db.execute({ sql: countSql, args: countArgs });
  const total = Number(countRes.rows[0]?.count || 0);

  const dataRes = await db.execute({ sql: dataSql, args: dataArgs });
  const users: AdminUserListItem[] = dataRes.rows.map((row) => {
    const plan: UserPlan = ((row.plan as string) || 'free').toLowerCase() === 'premium' ? 'premium' : 'free';
    const storageUsedBytes = Math.max(0, Number(row.storage_used_bytes || 0));
    const storageLimitBytes = PLAN_LIMITS[plan];
    const isOverQuota = storageUsedBytes > storageLimitBytes;

    return {
      id: String(row.id),
      firebaseUid: String(row.firebase_uid),
      email: row.email ? String(row.email) : null,
      plan,
      storageUsedBytes,
      storageLimitBytes,
      isOverQuota,
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
      notesCount: Number(row.notes_count || 0),
      devicesCount: Number(row.devices_count || 0),
      attachmentsCount: Number(row.attachments_count || 0),
      documentsCount: Number(row.documents_count || 0),
    };
  });

  return {
    users,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit) || 1,
  };
}

/**
 * Retrieves detailed user inspection information including plan, storage quota, devices, crypto parameters, and audit history.
 */
export async function getAdminUserDetail(db: Client, userId: string): Promise<AdminUserDetail | null> {
  const userRes = await db.execute({
    sql: 'SELECT id, firebase_uid, email, plan, storage_used_bytes, storage_reserved_bytes, created_at, updated_at FROM users WHERE id = ? LIMIT 1',
    args: [userId],
  });

  if (userRes.rows.length === 0) {
    return null;
  }

  const uRow = userRes.rows[0];

  // Storage Quota Profile
  const quota = await getUserQuotaProfile(db, userId);

  // Key metadata
  const keyRes = await db.execute({
    sql: 'SELECT key_version, kdf_algorithm, encryption_format_version, recovery_wrapped_master_key, updated_at FROM encryption_keys WHERE user_id = ? ORDER BY key_version DESC LIMIT 1',
    args: [userId],
  });

  let encryptionKey: AdminUserDetail['encryptionKey'] = { configured: false };
  if (keyRes.rows.length > 0) {
    const kRow = keyRes.rows[0];
    encryptionKey = {
      configured: true,
      keyVersion: Number(kRow.key_version),
      kdfAlgorithm: String(kRow.kdf_algorithm),
      formatVersion: Number(kRow.encryption_format_version),
      hasRecoveryKey: kRow.recovery_wrapped_master_key !== null,
      updatedAt: String(kRow.updated_at),
    };
  }

  // Devices
  const devicesRes = await db.execute({
    sql: 'SELECT id, device_name, client_version, last_acknowledged_revision, last_seen_at, created_at FROM sync_devices WHERE user_id = ? ORDER BY last_seen_at DESC',
    args: [userId],
  });

  const devices = devicesRes.rows.map((row) => ({
    id: String(row.id),
    deviceName: row.device_name ? String(row.device_name) : null,
    clientVersion: row.client_version ? String(row.client_version) : null,
    lastAcknowledgedRevision: Number(row.last_acknowledged_revision || 0),
    lastSeenAt: String(row.last_seen_at),
    createdAt: String(row.created_at),
  }));

  // Recent changes
  const changesRes = await db.execute({
    sql: 'SELECT id, note_id, revision, change_type, timestamp FROM sync_changes WHERE user_id = ? ORDER BY revision DESC LIMIT 15',
    args: [userId],
  });

  const recentChanges = changesRes.rows.map((row) => ({
    id: String(row.id),
    noteId: String(row.note_id),
    revision: Number(row.revision),
    changeType: String(row.change_type),
    timestamp: String(row.timestamp),
  }));

  // Audit Logs
  let auditLogs: AdminAuditLogEntry[] = [];
  try {
    const auditRes = await db.execute({
      sql: 'SELECT id, admin_identifier, action, old_value, new_value, details_json, created_at FROM admin_audit_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT 20',
      args: [userId],
    });
    auditLogs = auditRes.rows.map((row) => ({
      id: String(row.id),
      adminIdentifier: row.admin_identifier ? String(row.admin_identifier) : null,
      action: String(row.action),
      oldValue: row.old_value ? String(row.old_value) : null,
      newValue: row.new_value ? String(row.new_value) : null,
      details: row.details_json ? String(row.details_json) : null,
      createdAt: String(row.created_at),
    }));
  } catch {
    // table may be empty
  }

  // Safe storage profile
  const storageProfile = await profileUserStorage(db, userId);

  return {
    user: {
      id: String(uRow.id),
      firebaseUid: String(uRow.firebase_uid),
      email: uRow.email ? String(uRow.email) : null,
      createdAt: String(uRow.created_at),
      updatedAt: String(uRow.updated_at),
    },
    quota,
    encryptionKey,
    devices,
    recentChanges,
    auditLogs,
    storageProfile,
  };
}

/**
 * Administrative action to change a user's plan.
 */
export async function changeUserPlanAdmin(
  db: Client,
  userId: string,
  newPlan: UserPlan,
  adminIdentifier: string = 'admin',
  reason?: string
): Promise<{ user: { id: string; email: string | null; plan: UserPlan; previousPlan: UserPlan }; quota: StorageQuotaProfile }> {
  return await changeUserPlan(db, userId, newPlan, { adminIdentifier, reason });
}

/**
 * Administrative action to reconcile storage counters against authoritative metadata.
 */
export async function reconcileUserStorageAdmin(
  db: Client,
  userId: string,
  dryRun: boolean = false
) {
  return await reconcileUserStorageUsage(db, userId, dryRun);
}

/**
 * Triggers user garbage collection (dry run or active reclamation).
 */
export async function triggerUserGC(
  db: Client,
  userId: string,
  dryRun: boolean
): Promise<GcExecutionSummary> {
  return await runGarbageCollection(db, userId, { dryRun });
}

/**
 * Retrieves storage overview and destruction jobs list for the Storage & GC tab.
 */
export async function getAdminStorageDetails(db: Client): Promise<AdminStorageOverview> {
  const attRes = await db.execute(
    'SELECT COUNT(*) as count, COALESCE(SUM(byte_size), 0) as bytes FROM attachments WHERE is_deleted = 0'
  );
  const docRes = await db.execute(
    'SELECT COUNT(*) as count, COALESCE(SUM(byte_size), 0) as bytes FROM documents WHERE is_deleted = 0'
  );

  const userStatsRes = await db.execute(`
    SELECT
      COUNT(*) as total_users,
      COUNT(CASE WHEN plan = 'free' OR plan IS NULL THEN 1 END) as free_users,
      COUNT(CASE WHEN plan = 'premium' THEN 1 END) as premium_users,
      COALESCE(SUM(CASE WHEN plan = 'free' OR plan IS NULL THEN storage_used_bytes ELSE 0 END), 0) as free_storage,
      COALESCE(SUM(CASE WHEN plan = 'premium' THEN storage_used_bytes ELSE 0 END), 0) as premium_storage,
      COUNT(CASE
        WHEN (plan = 'free' OR plan IS NULL) AND storage_used_bytes > 1000000000 THEN 1
        WHEN plan = 'premium' AND storage_used_bytes > 10000000000 THEN 1
      END) as over_quota,
      COUNT(CASE
        WHEN (plan = 'free' OR plan IS NULL) AND storage_used_bytes >= 800000000 AND storage_used_bytes <= 1000000000 THEN 1
        WHEN plan = 'premium' AND storage_used_bytes >= 8000000000 AND storage_used_bytes <= 10000000000 THEN 1
      END) as near_quota
    FROM users
  `);
  const userStats = userStatsRes.rows[0];

  let destructionJobs: any[] = [];
  try {
    const jobsRes = await db.execute(
      'SELECT * FROM destruction_jobs ORDER BY created_at DESC LIMIT 50'
    );
    destructionJobs = jobsRes.rows.map((row) => ({
      id: String(row.id),
      userId: String(row.user_id),
      resourceType: String(row.resource_type),
      resourceId: String(row.resource_id),
      cloudinaryPublicId: row.cloudinary_public_id ? String(row.cloudinary_public_id) : null,
      operation: String(row.operation),
      state: String(row.state),
      attemptCount: Number(row.attempt_count || 0),
      availableAt: String(row.available_at),
      lastError: row.last_error ? String(row.last_error) : null,
      createdAt: String(row.created_at),
      updatedAt: String(row.updated_at),
    }));
  } catch {
    // destruction_jobs table might not exist
  }

  return {
    totalAttachmentBytes: Number(attRes.rows[0]?.bytes || 0),
    totalDocumentBytes: Number(docRes.rows[0]?.bytes || 0),
    attachmentsCount: Number(attRes.rows[0]?.count || 0),
    documentsCount: Number(docRes.rows[0]?.count || 0),
    totalUsers: Number(userStats?.total_users || 0),
    freeUsers: Number(userStats?.free_users || 0),
    premiumUsers: Number(userStats?.premium_users || 0),
    aggregateFreeUsage: Number(userStats?.free_storage || 0),
    aggregatePremiumUsage: Number(userStats?.premium_storage || 0),
    usersOverQuota: Number(userStats?.over_quota || 0),
    usersNearQuota: Number(userStats?.near_quota || 0),
    destructionJobs,
  };
}

/**
 * Retries a failed or processing destruction job.
 */
export async function retryDestructionJob(db: Client, jobId: string): Promise<boolean> {
  const nowIso = new Date().toISOString();
  const res = await db.execute({
    sql: `UPDATE destruction_jobs
          SET state = 'pending', available_at = ?, attempt_count = 0, last_error = NULL, updated_at = ?
          WHERE id = ?`,
    args: [nowIso, nowIso, jobId],
  });
  return res.rowsAffected > 0;
}

/**
 * Deletes a destruction job record.
 */
export async function deleteDestructionJob(db: Client, jobId: string): Promise<boolean> {
  const res = await db.execute({
    sql: 'DELETE FROM destruction_jobs WHERE id = ?',
    args: [jobId],
  });
  return res.rowsAffected > 0;
}

/**
 * Synchronizes missing or unpopulated user emails from Firebase Auth across the database.
 */
export async function syncMissingEmailsAdmin(
  db: Client,
  dryRun: boolean = false
): Promise<EmailSyncResult> {
  return backfillMissingUserEmails(db, {
    dryRun,
    force: false,
    batchSize: 100,
  });
}

/**
 * Synchronizes email for a specific user from Firebase Auth.
 */
export async function syncSingleUserEmailAdmin(
  db: Client,
  userId: string
): Promise<{ success: boolean; email: string | null; updated: boolean; message: string }> {
  return syncSingleUserEmail(db, userId);
}

