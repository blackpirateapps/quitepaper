import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import { PushSyncInput, pushSyncSchema, PullSyncInput, pullSyncSchema } from '../validation/schemas.js';
import crypto from 'crypto';

export interface PushResultItem {
  id: string;
  revision: number;
  status: 'applied' | 'conflict';
  updatedAt: string;
}

export interface ConflictItem {
  id: string;
  serverRevision: number;
  baseRevision?: number | null;
  code: string;
  message: string;
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

export async function pushSyncChanges(db: Client, userId: string, rawInput: unknown): Promise<PushResponse> {
  const parsed = pushSyncSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid sync push body: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const { idempotencyKey, deviceId, changes } = parsed.data;

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
      sql: 'SELECT revision, deleted_at, updated_at FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
      args: [change.id, userId],
    });

    const existingRow = existingResult.rows[0];
    const serverRevision = existingRow ? Number(existingRow.revision) : 0;

    // Conflict detection: if baseRevision is specified and smaller than existing serverRevision
    if (change.baseRevision != null && serverRevision > 0 && change.baseRevision < serverRevision) {
      conflicts.push({
        id: change.id,
        serverRevision,
        baseRevision: change.baseRevision,
        code: 'SYNC_CONFLICT',
        message: `Conflict detected. Server note is at revision ${serverRevision}, client base revision was ${change.baseRevision}.`,
      });
      continue;
    }

    currentMaxRev += 1;
    const newRevision = currentMaxRev;

    const isDeleted = change.isDeleted || !!change.deletedAt;
    const deletedAt = isDeleted ? (change.deletedAt || now) : null;

    // Upsert note in durable notes table
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

    // Record in sync_changes log
    const changeLogId = crypto.randomUUID();
    const payloadJson = JSON.stringify({
      id: change.id,
      revision: newRevision,
      changeType: isDeleted ? 'delete' : 'upsert',
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
        isDeleted ? 'delete' : 'upsert',
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

  const { cursor, limit } = parsed.data;

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
