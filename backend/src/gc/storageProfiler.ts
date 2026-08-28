import { Client } from '@libsql/client';

export interface TableStorageMetric {
  rowCount: number;
  approximatePayloadBytes: number;
  oldestTimestamp: string | null;
  newestTimestamp: string | null;
  eligibleRowCount: number;
  estimatedReclaimableBytes: number;
}

export interface StorageProfileReport {
  userId: string;
  generatedAt: string;
  totalEstimatedBytes: number;
  totalReclaimableBytes: number;
  safeSyncBoundaryRevision: number;
  activeDevicesCount: number;
  staleDevicesCount: number;
  expiredDevicesCount: number;
  tables: {
    notes: TableStorageMetric;
    noteVersions: TableStorageMetric;
    syncChanges: TableStorageMetric;
    idempotencyKeys: TableStorageMetric;
    attachments: TableStorageMetric;
    documents: TableStorageMetric;
    documentOcrPages: TableStorageMetric;
    attachmentReferences: TableStorageMetric;
    destructionJobs: TableStorageMetric;
  };
}

export async function profileUserStorage(
  db: Client,
  userId: string,
  safeBoundaryRevision: number = 0,
  orphanGracePeriodDays: number = 14
): Promise<StorageProfileReport> {
  const now = new Date();
  const nowIso = now.toISOString();
  const orphanCutoffIso = new Date(now.getTime() - orphanGracePeriodDays * 24 * 60 * 60 * 1000).toISOString();
  const idempotencyCutoffIso = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // 1. Devices summary
  const devicesRes = await db.execute({
    sql: 'SELECT last_seen_at FROM sync_devices WHERE user_id = ?',
    args: [userId],
  });

  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

  let activeDevices = 0;
  let staleDevices = 0;
  let expiredDevices = 0;

  for (const row of devicesRes.rows) {
    const lastSeen = new Date(row.last_seen_at as string);
    if (lastSeen >= thirtyDaysAgo) {
      activeDevices++;
    } else if (lastSeen >= ninetyDaysAgo) {
      staleDevices++;
    } else {
      expiredDevices++;
    }
  }

  // 2. Notes table
  const notesRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(LENGTH(content_ciphertext) + LENGTH(content_nonce)), 0) as total_bytes,
            MIN(created_at) as oldest,
            MAX(updated_at) as newest,
            COUNT(CASE WHEN deleted_at IS NOT NULL THEN 1 END) as deleted_rows
          FROM notes WHERE user_id = ?`,
    args: [userId],
  });
  const notesRow = notesRes.rows[0];
  const notesMetric: TableStorageMetric = {
    rowCount: Number(notesRow?.total_rows || 0),
    approximatePayloadBytes: Number(notesRow?.total_bytes || 0),
    oldestTimestamp: (notesRow?.oldest as string) || null,
    newestTimestamp: (notesRow?.newest as string) || null,
    eligibleRowCount: Number(notesRow?.deleted_rows || 0),
    estimatedReclaimableBytes: 0,
  };

  // 3. Note Versions table
  const versionsRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(LENGTH(content_ciphertext) + LENGTH(content_nonce)), 0) as total_bytes,
            MIN(created_at) as oldest,
            MAX(created_at) as newest
          FROM note_versions WHERE user_id = ?`,
    args: [userId],
  });
  const versionsRow = versionsRes.rows[0];

  // Eligible versions: versions belonging to deleted notes OR versions beyond 50 per note
  const eligibleVersionsRes = await db.execute({
    sql: `SELECT
            COUNT(*) as eligible_count,
            COALESCE(SUM(LENGTH(v.content_ciphertext) + LENGTH(v.content_nonce)), 0) as eligible_bytes
          FROM note_versions v
          LEFT JOIN notes n ON v.note_id = n.id AND v.user_id = n.user_id
          WHERE v.user_id = ? AND (n.deleted_at IS NOT NULL OR n.id IS NULL)`,
    args: [userId],
  });
  const eligibleVersionsRow = eligibleVersionsRes.rows[0];
  const noteVersionsMetric: TableStorageMetric = {
    rowCount: Number(versionsRow?.total_rows || 0),
    approximatePayloadBytes: Number(versionsRow?.total_bytes || 0),
    oldestTimestamp: (versionsRow?.oldest as string) || null,
    newestTimestamp: (versionsRow?.newest as string) || null,
    eligibleRowCount: Number(eligibleVersionsRow?.eligible_count || 0),
    estimatedReclaimableBytes: Number(eligibleVersionsRow?.eligible_bytes || 0),
  };

  // 4. Sync Changes table
  const syncChangesRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(LENGTH(payload_json)), 0) as total_bytes,
            MIN(timestamp) as oldest,
            MAX(timestamp) as newest
          FROM sync_changes WHERE user_id = ?`,
    args: [userId],
  });
  const syncRow = syncChangesRes.rows[0];

  let eligibleSyncRows = 0;
  let eligibleSyncBytes = 0;
  if (safeBoundaryRevision > 0) {
    const eligibleSyncRes = await db.execute({
      sql: `SELECT
              COUNT(*) as eligible_count,
              COALESCE(SUM(LENGTH(payload_json)), 0) as eligible_bytes
            FROM sync_changes WHERE user_id = ? AND revision < ?`,
      args: [userId, safeBoundaryRevision],
    });
    eligibleSyncRows = Number(eligibleSyncRes.rows[0]?.eligible_count || 0);
    eligibleSyncBytes = Number(eligibleSyncRes.rows[0]?.eligible_bytes || 0);
  }

  const syncChangesMetric: TableStorageMetric = {
    rowCount: Number(syncRow?.total_rows || 0),
    approximatePayloadBytes: Number(syncRow?.total_bytes || 0),
    oldestTimestamp: (syncRow?.oldest as string) || null,
    newestTimestamp: (syncRow?.newest as string) || null,
    eligibleRowCount: eligibleSyncRows,
    estimatedReclaimableBytes: eligibleSyncBytes,
  };

  // 5. Idempotency Keys table
  const idemRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(LENGTH(response_body)), 0) as total_bytes,
            MIN(created_at) as oldest,
            MAX(created_at) as newest,
            COUNT(CASE WHEN created_at < ? THEN 1 END) as expired_count,
            COALESCE(SUM(CASE WHEN created_at < ? THEN LENGTH(response_body) ELSE 0 END), 0) as expired_bytes
          FROM idempotency_keys WHERE user_id = ?`,
    args: [idempotencyCutoffIso, idempotencyCutoffIso, userId],
  });
  const idemRow = idemRes.rows[0];
  const idempotencyKeysMetric: TableStorageMetric = {
    rowCount: Number(idemRow?.total_rows || 0),
    approximatePayloadBytes: Number(idemRow?.total_bytes || 0),
    oldestTimestamp: (idemRow?.oldest as string) || null,
    newestTimestamp: (idemRow?.newest as string) || null,
    eligibleRowCount: Number(idemRow?.expired_count || 0),
    estimatedReclaimableBytes: Number(idemRow?.expired_bytes || 0),
  };

  // 6. Attachments table
  const attRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(byte_size), 0) as total_bytes,
            MIN(created_at) as oldest,
            MAX(updated_at) as newest,
            COUNT(CASE WHEN (status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1 THEN 1 END) as eligible_count,
            COALESCE(SUM(CASE WHEN (status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1 THEN byte_size ELSE 0 END), 0) as eligible_bytes
          FROM attachments WHERE user_id = ?`,
    args: [orphanCutoffIso, orphanCutoffIso, userId],
  });
  const attRow = attRes.rows[0];
  const attachmentsMetric: TableStorageMetric = {
    rowCount: Number(attRow?.total_rows || 0),
    approximatePayloadBytes: Number(attRow?.total_bytes || 0),
    oldestTimestamp: (attRow?.oldest as string) || null,
    newestTimestamp: (attRow?.newest as string) || null,
    eligibleRowCount: Number(attRow?.eligible_count || 0),
    estimatedReclaimableBytes: Number(attRow?.eligible_bytes || 0),
  };

  // 7. Documents table
  const docRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(byte_size), 0) as total_bytes,
            MIN(created_at) as oldest,
            MAX(updated_at) as newest,
            COUNT(CASE WHEN (status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1 THEN 1 END) as eligible_count,
            COALESCE(SUM(CASE WHEN (status = 'orphaned' AND orphaned_at < ?) OR is_deleted = 1 THEN byte_size ELSE 0 END), 0) as eligible_bytes
          FROM documents WHERE user_id = ?`,
    args: [orphanCutoffIso, orphanCutoffIso, userId],
  });
  const docRow = docRes.rows[0];
  const documentsMetric: TableStorageMetric = {
    rowCount: Number(docRow?.total_rows || 0),
    approximatePayloadBytes: Number(docRow?.total_bytes || 0),
    oldestTimestamp: (docRow?.oldest as string) || null,
    newestTimestamp: (docRow?.newest as string) || null,
    eligibleRowCount: Number(docRow?.eligible_count || 0),
    estimatedReclaimableBytes: Number(docRow?.eligible_bytes || 0),
  };

  // 8. Document OCR Pages table
  const ocrRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            COALESCE(SUM(LENGTH(encrypted_payload)), 0) as total_bytes,
            MIN(processed_at) as oldest,
            MAX(processed_at) as newest
          FROM document_ocr_pages WHERE user_id = ?`,
    args: [userId],
  });
  const ocrRow = ocrRes.rows[0];

  const eligibleOcrRes = await db.execute({
    sql: `SELECT
            COUNT(*) as eligible_count,
            COALESCE(SUM(LENGTH(o.encrypted_payload)), 0) as eligible_bytes
          FROM document_ocr_pages o
          LEFT JOIN documents d ON o.document_id = d.id AND o.user_id = d.user_id
          WHERE o.user_id = ? AND ((d.status = 'orphaned' AND d.orphaned_at < ?) OR d.is_deleted = 1 OR d.id IS NULL)`,
    args: [userId, orphanCutoffIso],
  });
  const eligibleOcrRow = eligibleOcrRes.rows[0];
  const documentOcrPagesMetric: TableStorageMetric = {
    rowCount: Number(ocrRow?.total_rows || 0),
    approximatePayloadBytes: Number(ocrRow?.total_bytes || 0),
    oldestTimestamp: (ocrRow?.oldest as string) || null,
    newestTimestamp: (ocrRow?.newest as string) || null,
    eligibleRowCount: Number(eligibleOcrRow?.eligible_count || 0),
    estimatedReclaimableBytes: Number(eligibleOcrRow?.eligible_bytes || 0),
  };

  // 9. Attachment References table
  const refRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            MIN(last_confirmed_at) as oldest,
            MAX(last_confirmed_at) as newest
          FROM attachment_references WHERE user_id = ?`,
    args: [userId],
  });
  const refRow = refRes.rows[0];
  const attachmentReferencesMetric: TableStorageMetric = {
    rowCount: Number(refRow?.total_rows || 0),
    approximatePayloadBytes: Number(refRow?.total_rows || 0) * 128,
    oldestTimestamp: (refRow?.oldest as string) || null,
    newestTimestamp: (refRow?.newest as string) || null,
    eligibleRowCount: 0,
    estimatedReclaimableBytes: 0,
  };

  // 10. Destruction Jobs table
  const jobsRes = await db.execute({
    sql: `SELECT
            COUNT(*) as total_rows,
            MIN(created_at) as oldest,
            MAX(updated_at) as newest,
            COUNT(CASE WHEN state = 'completed' THEN 1 END) as completed_count
          FROM destruction_jobs WHERE user_id = ?`,
    args: [userId],
  });
  const jobsRow = jobsRes.rows[0];
  const destructionJobsMetric: TableStorageMetric = {
    rowCount: Number(jobsRow?.total_rows || 0),
    approximatePayloadBytes: Number(jobsRow?.total_rows || 0) * 256,
    oldestTimestamp: (jobsRow?.oldest as string) || null,
    newestTimestamp: (jobsRow?.newest as string) || null,
    eligibleRowCount: Number(jobsRow?.completed_count || 0),
    estimatedReclaimableBytes: 0,
  };

  const totalEstimatedBytes =
    notesMetric.approximatePayloadBytes +
    noteVersionsMetric.approximatePayloadBytes +
    syncChangesMetric.approximatePayloadBytes +
    idempotencyKeysMetric.approximatePayloadBytes +
    attachmentsMetric.approximatePayloadBytes +
    documentsMetric.approximatePayloadBytes +
    documentOcrPagesMetric.approximatePayloadBytes;

  const totalReclaimableBytes =
    notesMetric.estimatedReclaimableBytes +
    noteVersionsMetric.estimatedReclaimableBytes +
    syncChangesMetric.estimatedReclaimableBytes +
    idempotencyKeysMetric.estimatedReclaimableBytes +
    attachmentsMetric.estimatedReclaimableBytes +
    documentsMetric.estimatedReclaimableBytes +
    documentOcrPagesMetric.estimatedReclaimableBytes;

  return {
    userId,
    generatedAt: nowIso,
    totalEstimatedBytes,
    totalReclaimableBytes,
    safeSyncBoundaryRevision: safeBoundaryRevision,
    activeDevicesCount: activeDevices,
    staleDevicesCount: staleDevices,
    expiredDevicesCount: expiredDevices,
    tables: {
      notes: notesMetric,
      noteVersions: noteVersionsMetric,
      syncChanges: syncChangesMetric,
      idempotencyKeys: idempotencyKeysMetric,
      attachments: attachmentsMetric,
      documents: documentsMetric,
      documentOcrPages: documentOcrPagesMetric,
      attachmentReferences: attachmentReferencesMetric,
      destructionJobs: destructionJobsMetric,
    },
  };
}
