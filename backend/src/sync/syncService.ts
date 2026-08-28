import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import {
  PushSyncInput,
  pushSyncSchema,
  PullSyncInput,
  pullSyncSchema,
  syncReferencesSchema,
} from '../validation/schemas.js';
import crypto from 'crypto';
import { deleteCloudinaryResource } from '../attachments/cloudinaryService.js';

export interface PushResultItem {
  id: string;
  revision: number;
  status: 'applied' | 'conflict';
  updatedAt: string;
}

export interface ServerHeadItem {
  revision: number;
  contentCiphertext: string;
  contentNonce: string;
  contentVersion: number;
  encryptionKeyVersion: number;
  isDeleted: boolean;
  deletedAt?: string | null;
  archived?: boolean;
  trashed?: boolean;
  pinned?: boolean;
  folderId?: string | null;
  sortOrder?: number | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface ConflictItem {
  id: string;
  noteId?: string;
  serverRevision: number;
  baseRevision?: number | null;
  code: string;
  message: string;
  serverHead?: ServerHeadItem;
}

export interface PushResponse {
  results: PushResultItem[];
  conflicts: ConflictItem[];
  cursor: number;
}

export interface PullChangeItem {
  id: string;
  revision: number;
  changeType: 'upsert' | 'delete';
  createdAt: string;
  updatedAt: string;
  archived: boolean;
  trashed: boolean;
  pinned: boolean;
  folderId?: string | null;
  sortOrder?: number | null;
  contentCiphertext: string;
  contentNonce: string;
  contentVersion: number;
  encryptionKeyVersion: number;
  deletedAt?: string | null;
}

export interface PullResponse {
  changes: PullChangeItem[];
  cursor: number;
  hasMore: boolean;
}

export interface StorageResourceItem {
  id: string;
  type: 'attachment' | 'document';
  title: string;
  mimeType: string;
  byteSize: number;
  createdAt: string;
  updatedAt: string;
  status: 'referenced' | 'orphaned' | 'pending_deletion';
  orphanedAt: string | null;
  isEligibleForDeletion: boolean;
  parentNoteId: string | null;
  cloudUrl: string | null;
}

export interface StorageResourcesResponse {
  attached: StorageResourceItem[];
  orphaned: StorageResourceItem[];
  totalAttachedCount: number;
  totalOrphanedCount: number;
  totalStorageBytes: number;
}

/**
 * Records or updates an active device's sync checkpoint.
 */
export async function recordDeviceCheckpoint(
  db: Client,
  userId: string,
  deviceId: string,
  deviceName?: string,
  clientVersion?: string,
  acknowledgedRev?: number
): Promise<void> {
  const now = new Date().toISOString();
  await db.execute({
    sql: `INSERT INTO sync_devices (id, user_id, device_name, client_version, last_acknowledged_revision, last_seen_at, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            device_name = COALESCE(excluded.device_name, sync_devices.device_name),
            client_version = COALESCE(excluded.client_version, sync_devices.client_version),
            last_acknowledged_revision = CASE
              WHEN excluded.last_acknowledged_revision > 0 THEN excluded.last_acknowledged_revision
              ELSE sync_devices.last_acknowledged_revision
            END,
            last_seen_at = excluded.last_seen_at,
            updated_at = excluded.updated_at`,
    args: [
      deviceId,
      userId,
      deviceName || null,
      clientVersion || null,
      acknowledgedRev || 0,
      now,
      now,
      now,
    ],
  });
}

export async function pushSyncChanges(db: Client, userId: string, rawInput: unknown): Promise<PushResponse> {
  const parsed = pushSyncSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid sync push body: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { idempotencyKey, deviceId, clientVersion, changes } = parsed.data;

  // Idempotency check
  if (idempotencyKey) {
    const existingIdem = await db.execute({
      sql: 'SELECT response_body FROM idempotency_keys WHERE user_id = ? AND key = ? LIMIT 1',
      args: [userId, idempotencyKey],
    });
    if (existingIdem.rows.length > 0) {
      return JSON.parse(existingIdem.rows[0].response_body as string);
    }
  }

  const appliedResults: PushResultItem[] = [];
  const conflicts: ConflictItem[] = [];
  const now = new Date().toISOString();

  // Get current max revision for user
  const maxRevResult = await db.execute({
    sql: 'SELECT COALESCE(MAX(revision), 0) as max_rev FROM sync_changes WHERE user_id = ?',
    args: [userId],
  });
  let currentMaxRev = Number(maxRevResult.rows[0]?.max_rev || 0);

  for (const change of changes) {
    // Check existing note
    const existingResult = await db.execute({
      sql: `SELECT revision, deleted_at, updated_at, created_at, archived, trashed, pinned,
                   folder_id, sort_order, content_ciphertext, content_nonce, content_version,
                   encryption_key_version
            FROM notes WHERE id = ? AND user_id = ? LIMIT 1`,
      args: [change.id, userId],
    });

    const existingRow = existingResult.rows[0];
    const serverRevision = existingRow ? Number(existingRow.revision) : 0;

    // Conflict detection: if baseRevision is specified and smaller than existing serverRevision
    if (change.baseRevision != null && serverRevision > 0 && change.baseRevision < serverRevision) {
      const isDeleted = existingRow.deleted_at != null || Number(existingRow.trashed) === 1;
      conflicts.push({
        id: change.id,
        noteId: change.id,
        serverRevision,
        baseRevision: change.baseRevision,
        code: 'SYNC_CONFLICT',
        message: `Conflict detected. Server note is at revision ${serverRevision}, client base revision was ${change.baseRevision}.`,
        serverHead: {
          revision: serverRevision,
          contentCiphertext: (existingRow.content_ciphertext as string) || '',
          contentNonce: (existingRow.content_nonce as string) || '',
          contentVersion: Number(existingRow.content_version || 1),
          encryptionKeyVersion: Number(existingRow.encryption_key_version || 1),
          isDeleted,
          deletedAt: existingRow.deleted_at as string | null,
          archived: Number(existingRow.archived) === 1,
          trashed: Number(existingRow.trashed) === 1,
          pinned: Number(existingRow.pinned) === 1,
          folderId: existingRow.folder_id as string | null,
          sortOrder: existingRow.sort_order != null ? Number(existingRow.sort_order) : null,
          createdAt: existingRow.created_at as string,
          updatedAt: existingRow.updated_at as string,
        },
      });
      continue;
    }

    currentMaxRev += 1;
    const newRevision = currentMaxRev;

    const isPermanentDelete = change.isDeleted === true;
    const isTrashed = change.trashed === true;
    const deletedAt = isPermanentDelete ? (change.deletedAt || now) : (isTrashed ? (change.deletedAt || now) : null);

    if (isPermanentDelete) {
      // 1. Permanent hard delete tombstone: clear note content in durable table
      await db.execute({
        sql: `INSERT INTO notes (
                id, user_id, created_at, updated_at, archived, trashed, pinned,
                folder_id, sort_order, content_ciphertext, content_nonce, content_version,
                encryption_key_version, revision, deleted_at, updated_by_device
              ) VALUES (?, ?, ?, ?, 0, 1, 0, NULL, NULL, '', '', 1, 1, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                content_ciphertext = '',
                content_nonce = '',
                trashed = 1,
                deleted_at = excluded.deleted_at,
                revision = excluded.revision,
                updated_at = excluded.updated_at,
                updated_by_device = excluded.updated_by_device`,
        args: [
          change.id,
          userId,
          change.createdAt,
          change.updatedAt,
          newRevision,
          deletedAt,
          deviceId || null,
        ],
      });

      // 2. Delete all note versions belonging to permanently deleted note
      await db.execute({
        sql: 'DELETE FROM note_versions WHERE note_id = ? AND user_id = ?',
        args: [change.id, userId],
      });

      // 3. Remove attachment references belonging to this note
      await db.execute({
        sql: 'DELETE FROM attachment_references WHERE note_id = ? AND user_id = ?',
        args: [change.id, userId],
      });

      // 4. Mark unreferenced attachments/documents as orphaned
      await db.execute({
        sql: `UPDATE attachments SET status = 'orphaned', orphaned_at = ?
              WHERE user_id = ? AND status = 'referenced' AND id NOT IN (
                SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'attachment'
              )`,
        args: [now, userId, userId],
      });

      await db.execute({
        sql: `UPDATE documents SET status = 'orphaned', orphaned_at = ?
              WHERE user_id = ? AND status = 'referenced' AND id NOT IN (
                SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'document'
              )`,
        args: [now, userId, userId],
      });
    } else {
      // Upsert note in durable notes table (Active or Trashed)
      await db.execute({
        sql: `INSERT INTO notes (
                id, user_id, created_at, updated_at, archived, trashed, pinned,
                folder_id, sort_order, content_ciphertext, content_nonce, content_version,
                encryption_key_version, revision, deleted_at, updated_by_device
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                updated_at = excluded.updated_at,
                archived = excluded.archived,
                trashed = excluded.trashed,
                pinned = excluded.pinned,
                folder_id = excluded.folder_id,
                sort_order = excluded.sort_order,
                content_ciphertext = excluded.content_ciphertext,
                content_nonce = excluded.content_nonce,
                content_version = excluded.content_version,
                encryption_key_version = excluded.encryption_key_version,
                revision = excluded.revision,
                deleted_at = excluded.deleted_at,
                updated_by_device = excluded.updated_by_device`,
        args: [
          change.id,
          userId,
          change.createdAt,
          change.updatedAt,
          change.archived ? 1 : 0,
          change.trashed ? 1 : 0,
          change.pinned ? 1 : 0,
          change.folderId || null,
          change.sortOrder || null,
          change.contentCiphertext,
          change.contentNonce,
          change.contentVersion,
          change.encryptionKeyVersion,
          newRevision,
          deletedAt,
          deviceId || null,
        ],
      });
    }

    // Record in sync_changes log
    const changeLogId = crypto.randomUUID();
    const payloadJson = JSON.stringify({
      id: change.id,
      revision: newRevision,
      changeType: isPermanentDelete ? 'delete' : 'upsert',
      createdAt: change.createdAt,
      updatedAt: change.updatedAt,
      archived: change.archived,
      trashed: change.trashed,
      pinned: change.pinned,
      folderId: change.folderId || null,
      sortOrder: change.sortOrder || null,
      contentCiphertext: change.contentCiphertext,
      contentNonce: change.contentNonce,
      contentVersion: change.contentVersion,
      encryptionKeyVersion: change.encryptionKeyVersion,
      deletedAt,
    });

    await db.execute({
      sql: `INSERT INTO sync_changes (id, user_id, note_id, revision, change_type, payload_json, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)`,
      args: [
        changeLogId,
        userId,
        change.id,
        newRevision,
        isPermanentDelete ? 'delete' : 'upsert',
        payloadJson,
        now,
      ],
    });

    appliedResults.push({
      id: change.id,
      revision: newRevision,
      status: 'applied',
      updatedAt: change.updatedAt,
    });
  }

  // Update device checkpoint if deviceId is provided
  if (deviceId) {
    await recordDeviceCheckpoint(db, userId, deviceId, undefined, clientVersion, currentMaxRev);
  }

  const response: PushResponse = {
    results: appliedResults,
    conflicts,
    cursor: currentMaxRev,
  };

  if (idempotencyKey) {
    await db.execute({
      sql: `INSERT INTO idempotency_keys (key, user_id, endpoint, response_code, response_body, created_at)
            VALUES (?, ?, ?, ?, ?, ?)`,
      args: [idempotencyKey, userId, '/api/v1/sync/push', 200, JSON.stringify(response), now],
    });
  }

  return response;
}

export async function pullSyncChanges(db: Client, userId: string, rawInput: unknown): Promise<PullResponse> {
  const parsed = pullSyncSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid sync pull body: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { cursor, limit, deviceId, clientVersion } = parsed.data;

  // Check cursor expiration: if history has been GC'd and cursor is older than earliest retained revision
  const minRevResult = await db.execute({
    sql: 'SELECT MIN(revision) as min_rev, MAX(revision) as max_rev FROM sync_changes WHERE user_id = ?',
    args: [userId],
  });
  const minRev = Number(minRevResult.rows[0]?.min_rev || 0);
  const maxRev = Number(minRevResult.rows[0]?.max_rev || 0);

  if (cursor > 0 && minRev > 0 && cursor < minRev - 1) {
    throw new ApiError(
      'SYNC_CURSOR_EXPIRED',
      `Sync cursor ${cursor} has expired (retained history begins at revision ${minRev}). A full resync is required.`,
      410,
      {
        cursorExpired: true,
        minRetainedRevision: minRev,
        currentRevision: maxRev,
      }
    );
  }

  const results = await db.execute({
    sql: `SELECT revision, payload_json
          FROM sync_changes
          WHERE user_id = ? AND revision > ?
          ORDER BY revision ASC
          LIMIT ?`,
    args: [userId, cursor, limit + 1],
  });

  const hasMore = results.rows.length > limit;
  const rowsToUse = hasMore ? results.rows.slice(0, limit) : results.rows;

  const changes: PullChangeItem[] = [];
  let nextCursor = cursor;

  for (const row of rowsToUse) {
    const item = JSON.parse(row.payload_json as string) as PullChangeItem;
    changes.push(item);
    if (Number(row.revision) > nextCursor) {
      nextCursor = Number(row.revision);
    }
  }

  if (deviceId) {
    await recordDeviceCheckpoint(db, userId, deviceId, undefined, clientVersion, nextCursor);
  }

  return {
    changes,
    cursor: nextCursor,
    hasMore,
  };
}

export async function getLatestCursor(db: Client, userId: string): Promise<number> {
  const result = await db.execute({
    sql: 'SELECT COALESCE(MAX(revision), 0) as max_rev FROM sync_changes WHERE user_id = ?',
    args: [userId],
  });
  return Number(result.rows[0]?.max_rev || 0);
}

/**
 * Updates the client's crypto-blind reference projections for attachments and documents.
 */
export async function updateAttachmentReferences(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<{ success: boolean; recordedReferences: number }> {
  const parsed = syncReferencesSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid reference projection: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { deviceId, references } = parsed.data;
  const now = new Date().toISOString();

  for (const ref of references) {
    const refId = crypto.randomUUID();
    await db.execute({
      sql: `INSERT INTO attachment_references (id, user_id, resource_type, resource_id, note_id, last_confirmed_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, resource_type, resource_id, note_id) DO UPDATE SET
              last_confirmed_at = excluded.last_confirmed_at`,
      args: [refId, userId, ref.resourceType, ref.resourceId, ref.noteId, now],
    });

    if (ref.resourceType === 'attachment') {
      await db.execute({
        sql: `UPDATE attachments SET status = 'referenced', orphaned_at = NULL WHERE id = ? AND user_id = ?`,
        args: [ref.resourceId, userId],
      });
    } else if (ref.resourceType === 'document') {
      await db.execute({
        sql: `UPDATE documents SET status = 'referenced', orphaned_at = NULL WHERE id = ? AND user_id = ?`,
        args: [ref.resourceId, userId],
      });
    }
  }

  if (deviceId) {
    await recordDeviceCheckpoint(db, userId, deviceId);
  }

  return {
    success: true,
    recordedReferences: references.length,
  };
}

/**
 * Explicit permanent destruction of a note and its exclusive resources.
 */
export async function destroyNoteAndExclusiveResources(
  db: Client,
  userId: string,
  noteId: string
): Promise<{ success: boolean; revision: number }> {
  const now = new Date().toISOString();

  // Get current max revision
  const maxRevResult = await db.execute({
    sql: 'SELECT COALESCE(MAX(revision), 0) as max_rev FROM sync_changes WHERE user_id = ?',
    args: [userId],
  });
  const newRevision = Number(maxRevResult.rows[0]?.max_rev || 0) + 1;

  // 1. Mark note tombstoned & clear content
  await db.execute({
    sql: `UPDATE notes SET
            content_ciphertext = '',
            content_nonce = '',
            trashed = 1,
            deleted_at = ?,
            revision = ?,
            updated_at = ?
          WHERE id = ? AND user_id = ?`,
    args: [now, newRevision, now, noteId, userId],
  });

  // 2. Delete all note versions
  await db.execute({
    sql: 'DELETE FROM note_versions WHERE note_id = ? AND user_id = ?',
    args: [noteId, userId],
  });

  // 3. Remove references for this note
  await db.execute({
    sql: 'DELETE FROM attachment_references WHERE note_id = ? AND user_id = ?',
    args: [noteId, userId],
  });

  // 4. Update orphaned status on attachments/documents with 0 references
  await db.execute({
    sql: `UPDATE attachments SET status = 'orphaned', orphaned_at = ?
          WHERE user_id = ? AND status = 'referenced' AND id NOT IN (
            SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'attachment'
          )`,
    args: [now, userId, userId],
  });

  await db.execute({
    sql: `UPDATE documents SET status = 'orphaned', orphaned_at = ?
          WHERE user_id = ? AND status = 'referenced' AND id NOT IN (
            SELECT resource_id FROM attachment_references WHERE user_id = ? AND resource_type = 'document'
          )`,
    args: [now, userId, userId],
  });

  // 5. Append delete tombstone to sync_changes
  const changeLogId = crypto.randomUUID();
  const payloadJson = JSON.stringify({
    id: noteId,
    revision: newRevision,
    changeType: 'delete',
    isDeleted: true,
    deletedAt: now,
    createdAt: now,
    updatedAt: now,
    archived: false,
    trashed: true,
    pinned: false,
    contentCiphertext: '',
    contentNonce: '',
    contentVersion: 1,
    encryptionKeyVersion: 1,
  });

  await db.execute({
    sql: `INSERT INTO sync_changes (id, user_id, note_id, revision, change_type, payload_json, timestamp)
          VALUES (?, ?, ?, ?, 'delete', ?, ?)`,
    args: [changeLogId, userId, noteId, newRevision, payloadJson, now],
  });

  return { success: true, revision: newRevision };
}

/**
 * Returns attached and orphaned storage resources for Settings storage inspection.
 */
export async function getStorageResources(
  db: Client,
  userId: string,
  orphanGracePeriodDays: number = 14
): Promise<StorageResourcesResponse> {
  const orphanCutoffIso = new Date(Date.now() - orphanGracePeriodDays * 24 * 60 * 60 * 1000).toISOString();

  // Attachments
  const attsRes = await db.execute({
    sql: `SELECT id, mime_type, byte_size, created_at, updated_at, status, orphaned_at, cloud_url, note_id
          FROM attachments WHERE user_id = ? AND is_deleted = 0`,
    args: [userId],
  });

  // Documents
  const docsRes = await db.execute({
    sql: `SELECT id, title, mime_type, byte_size, created_at, updated_at, status, orphaned_at, cloud_url, note_id
          FROM documents WHERE user_id = ? AND is_deleted = 0`,
    args: [userId],
  });

  const attached: StorageResourceItem[] = [];
  const orphaned: StorageResourceItem[] = [];
  let totalBytes = 0;

  for (const row of attsRes.rows) {
    const size = Number(row.byte_size || 0);
    totalBytes += size;
    const status = (row.status as string) || 'referenced';
    const orphanedAt = row.orphaned_at as string | null;
    const isEligible = status === 'orphaned' && (orphanedAt ? orphanedAt < orphanCutoffIso : true);

    const item: StorageResourceItem = {
      id: row.id as string,
      type: 'attachment',
      title: 'Image Attachment',
      mimeType: (row.mime_type as string) || 'image/png',
      byteSize: size,
      createdAt: row.created_at as string,
      updatedAt: row.updated_at as string,
      status: status as any,
      orphanedAt,
      isEligibleForDeletion: isEligible,
      parentNoteId: row.note_id as string | null,
      cloudUrl: row.cloud_url as string | null,
    };

    if (status === 'referenced') {
      attached.push(item);
    } else {
      orphaned.push(item);
    }
  }

  for (const row of docsRes.rows) {
    const size = Number(row.byte_size || 0);
    totalBytes += size;
    const status = (row.status as string) || 'referenced';
    const orphanedAt = row.orphaned_at as string | null;
    const isEligible = status === 'orphaned' && (orphanedAt ? orphanedAt < orphanCutoffIso : true);

    const item: StorageResourceItem = {
      id: row.id as string,
      type: 'document',
      title: (row.title as string) || 'Scanned Document',
      mimeType: (row.mime_type as string) || 'application/pdf',
      byteSize: size,
      createdAt: row.created_at as string,
      updatedAt: row.updated_at as string,
      status: status as any,
      orphanedAt,
      isEligibleForDeletion: isEligible,
      parentNoteId: row.note_id as string | null,
      cloudUrl: row.cloud_url as string | null,
    };

    if (status === 'referenced') {
      attached.push(item);
    } else {
      orphaned.push(item);
    }
  }

  return {
    attached,
    orphaned,
    totalAttachedCount: attached.length,
    totalOrphanedCount: orphaned.length,
    totalStorageBytes: totalBytes,
  };
}

/**
 * User-initiated permanent destruction of an orphaned resource.
 */
export async function deleteStorageResource(
  db: Client,
  userId: string,
  resourceType: 'attachment' | 'document',
  resourceId: string
): Promise<{ success: boolean }> {
  // Check active references
  const refRes = await db.execute({
    sql: 'SELECT id FROM attachment_references WHERE user_id = ? AND resource_type = ? AND resource_id = ? LIMIT 1',
    args: [userId, resourceType, resourceId],
  });

  if (refRes.rows.length > 0) {
    throw new ApiError(
      'CONFLICT',
      'Cannot delete resource: it is currently referenced by one or more active or trashed notes.',
      409
    );
  }

  let cloudPublicId: string | null = null;
  if (resourceType === 'attachment') {
    const attRes = await db.execute({
      sql: 'SELECT cloud_public_id FROM attachments WHERE id = ? AND user_id = ?',
      args: [resourceId, userId],
    });
    if (attRes.rows.length === 0) {
      throw new ApiError('NOT_FOUND', 'Attachment not found', 404);
    }
    cloudPublicId = attRes.rows[0].cloud_public_id as string | null;

    if (cloudPublicId && cloudPublicId.trim().length > 0) {
      await deleteCloudinaryResource(cloudPublicId.trim());
    }
    await db.execute({
      sql: 'DELETE FROM attachments WHERE id = ? AND user_id = ?',
      args: [resourceId, userId],
    });
  } else if (resourceType === 'document') {
    const docRes = await db.execute({
      sql: 'SELECT cloud_public_id FROM documents WHERE id = ? AND user_id = ?',
      args: [resourceId, userId],
    });
    if (docRes.rows.length === 0) {
      throw new ApiError('NOT_FOUND', 'Document not found', 404);
    }
    cloudPublicId = docRes.rows[0].cloud_public_id as string | null;

    if (cloudPublicId && cloudPublicId.trim().length > 0) {
      await deleteCloudinaryResource(cloudPublicId.trim());
    }
    await db.execute({
      sql: 'DELETE FROM document_ocr_pages WHERE document_id = ? AND user_id = ?',
      args: [resourceId, userId],
    });
    await db.execute({
      sql: 'DELETE FROM documents WHERE id = ? AND user_id = ?',
      args: [resourceId, userId],
    });
  }

  return { success: true };
}

export async function pushNoteVersions(db: Client, userId: string, rawInput: unknown): Promise<{ results: PushResultItem[]; cursor: number }> {
  const { pushVersionsSchema } = await import('../validation/schemas.js');
  const parsed = pushVersionsSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid version push body: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { versions, deviceId } = parsed.data;
  const appliedResults: PushResultItem[] = [];

  const maxRevResult = await db.execute({
    sql: 'SELECT COALESCE(MAX(revision), 0) as max_rev FROM note_versions WHERE user_id = ?',
    args: [userId],
  });
  let currentMaxRev = Number(maxRevResult.rows[0]?.max_rev || 0);

  for (const v of versions) {
    currentMaxRev += 1;
    const now = new Date().toISOString();

    await db.execute({
      sql: `INSERT INTO note_versions (id, user_id, note_id, version_number, content_ciphertext, content_nonce, char_count, word_count, delta_summary, revision, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              content_ciphertext = excluded.content_ciphertext,
              content_nonce = excluded.content_nonce,
              char_count = excluded.char_count,
              word_count = excluded.word_count,
              delta_summary = excluded.delta_summary,
              revision = excluded.revision`,
      args: [
        v.id,
        userId,
        v.noteId,
        v.versionNumber,
        v.contentCiphertext,
        v.contentNonce,
        v.charCount,
        v.wordCount,
        v.deltaSummary || null,
        currentMaxRev,
        v.createdAt,
      ],
    });

    appliedResults.push({
      id: v.id,
      revision: currentMaxRev,
      status: 'applied',
      updatedAt: now,
    });
  }

  if (deviceId) {
    await recordDeviceCheckpoint(db, userId, deviceId);
  }

  return {
    results: appliedResults,
    cursor: currentMaxRev,
  };
}

export async function pullNoteVersions(db: Client, userId: string, rawInput: unknown): Promise<{ changes: any[]; cursor: number; hasMore: boolean }> {
  const { pullVersionsSchema } = await import('../validation/schemas.js');
  const parsed = pullVersionsSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid version pull body: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { cursor, limit } = parsed.data;

  const results = await db.execute({
    sql: `SELECT id, note_id, version_number, content_ciphertext, content_nonce, char_count, word_count, delta_summary, revision, created_at
          FROM note_versions
          WHERE user_id = ? AND revision > ?
          ORDER BY revision ASC
          LIMIT ?`,
    args: [userId, cursor, limit + 1],
  });

  const hasMore = results.rows.length > limit;
  const rowsToUse = hasMore ? results.rows.slice(0, limit) : results.rows;

  const changes = rowsToUse.map(r => ({
    id: r.id as string,
    noteId: r.note_id as string,
    versionNumber: Number(r.version_number),
    contentCiphertext: r.content_ciphertext as string,
    contentNonce: r.content_nonce as string,
    charCount: Number(r.char_count || 0),
    wordCount: Number(r.word_count || 0),
    deltaSummary: r.delta_summary as string | null,
    revision: Number(r.revision),
    createdAt: r.created_at as string,
  }));

  let nextCursor = cursor;
  for (const r of rowsToUse) {
    if (Number(r.revision) > nextCursor) {
      nextCursor = Number(r.revision);
    }
  }

  return {
    changes,
    cursor: nextCursor,
    hasMore,
  };
}

export async function getNoteById(db: Client, userId: string, noteId: string): Promise<PullChangeItem | null> {
  const result = await db.execute({
    sql: `SELECT id, revision, created_at, updated_at, archived, trashed, pinned, folder_id, sort_order,
                 content_ciphertext, content_nonce, content_version, encryption_key_version, deleted_at
          FROM notes
          WHERE id = ? AND user_id = ?
          LIMIT 1`,
    args: [noteId, userId],
  });

  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  const isDeleted = row.deleted_at != null && Number(row.trashed) === 1 && ((row.content_ciphertext as string) || '').length === 0;

  return {
    id: row.id as string,
    revision: Number(row.revision),
    changeType: isDeleted ? 'delete' : 'upsert',
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
    archived: Number(row.archived) === 1,
    trashed: Number(row.trashed) === 1,
    pinned: Number(row.pinned) === 1,
    folderId: row.folder_id as string | null,
    sortOrder: row.sort_order != null ? Number(row.sort_order) : null,
    contentCiphertext: (row.content_ciphertext as string) || '',
    contentNonce: (row.content_nonce as string) || '',
    contentVersion: Number(row.content_version || 1),
    encryptionKeyVersion: Number(row.encryption_key_version || 1),
    deletedAt: row.deleted_at as string | null,
  };
}

export async function getHistoricalRevision(db: Client, userId: string, noteId: string, revision: number): Promise<PullChangeItem | null> {
  const changeResult = await db.execute({
    sql: `SELECT payload_json FROM sync_changes
          WHERE user_id = ? AND note_id = ? AND revision = ?
          LIMIT 1`,
    args: [userId, noteId, revision],
  });

  if (changeResult.rows.length > 0) {
    return JSON.parse(changeResult.rows[0].payload_json as string) as PullChangeItem;
  }

  const noteResult = await db.execute({
    sql: `SELECT id, revision, created_at, updated_at, archived, trashed, pinned, folder_id, sort_order,
                 content_ciphertext, content_nonce, content_version, encryption_key_version, deleted_at
          FROM notes
          WHERE id = ? AND user_id = ? AND revision = ?
          LIMIT 1`,
    args: [noteId, userId, revision],
  });

  if (noteResult.rows.length > 0) {
    const row = noteResult.rows[0];
    const isDeleted = row.deleted_at != null && Number(row.trashed) === 1 && ((row.content_ciphertext as string) || '').length === 0;
    return {
      id: row.id as string,
      revision: Number(row.revision),
      changeType: isDeleted ? 'delete' : 'upsert',
      createdAt: row.created_at as string,
      updatedAt: row.updated_at as string,
      archived: Number(row.archived) === 1,
      trashed: Number(row.trashed) === 1,
      pinned: Number(row.pinned) === 1,
      folderId: row.folder_id as string | null,
      sortOrder: row.sort_order != null ? Number(row.sort_order) : null,
      contentCiphertext: (row.content_ciphertext as string) || '',
      contentNonce: (row.content_nonce as string) || '',
      contentVersion: Number(row.content_version || 1),
      encryptionKeyVersion: Number(row.encryption_key_version || 1),
      deletedAt: row.deleted_at as string | null,
    };
  }

  return null;
}
