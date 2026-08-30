import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import {
  uploadAuthRequestSchema,
  confirmAttachmentSchema,
  UploadAuthRequestInput,
  ConfirmAttachmentInput,
} from '../validation/schemas.js';
import {
  getCloudinaryConfig,
  createSignedUploadAuth,
  SignedUploadParams,
} from './cloudinaryService.js';

export async function authorizeAttachmentUpload(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<SignedUploadParams> {
  const parseRes = uploadAuthRequestSchema.safeParse(rawInput);
  if (!parseRes.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid upload auth request: ${parseRes.error.errors.map(e => e.message).join(', ')}`,
      400,
      parseRes.error.errors
    );
  }

  const { attachmentId, noteId, variant } = parseRes.data;

  // If noteId is specified, verify note ownership
  if (noteId) {
    const noteRes = await db.execute({
      sql: 'SELECT id, user_id FROM notes WHERE id = ?',
      args: [noteId],
    });

    if (noteRes.rows.length > 0) {
      const row = noteRes.rows[0];
      if (row.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Access to specified note is forbidden', 403);
      }
    }
  }

  const config = getCloudinaryConfig();
  const publicId = variant === 'original'
    ? `${userId}_${attachmentId}`
    : `${userId}_${attachmentId}_${variant}`;

  return createSignedUploadAuth(publicId, config);
}

export async function confirmAttachmentUpload(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<{ success: boolean; attachment: Record<string, any> }> {
  const parseRes = confirmAttachmentSchema.safeParse(rawInput);
  if (!parseRes.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid confirmation payload: ${parseRes.error.errors.map(e => e.message).join(', ')}`,
      400,
      parseRes.error.errors
    );
  }

  const {
    attachmentId,
    noteId,
    cloudPublicId,
    cloudUrl,
    mimeType = 'image/png',
    byteSize = 0,
    sha256 = '',
    width,
    height,
    fileName,
    kind,
  } = parseRes.data;

  const nowIso = new Date().toISOString();

  // Check if attachment record exists
  const existingRes = await db.execute({
    sql: 'SELECT id, user_id, server_revision FROM attachments WHERE id = ?',
    args: [attachmentId],
  });

  let serverRevision = 1;

  if (existingRes.rows.length > 0) {
    const row = existingRes.rows[0];
    if (row.user_id !== userId) {
      throw new ApiError('FORBIDDEN', 'Attachment belongs to another user', 403);
    }
    serverRevision = ((row.server_revision as number) || 0) + 1;

    await db.execute({
      sql: `UPDATE attachments SET
              note_id = COALESCE(?, note_id),
              cloud_public_id = ?,
              cloud_url = ?,
              mime_type = ?,
              byte_size = ?,
              sha256 = ?,
              width = COALESCE(?, width),
              height = COALESCE(?, height),
              file_name = COALESCE(?, file_name),
              kind = COALESCE(?, kind),
              server_revision = ?,
              updated_at = ?
            WHERE id = ? AND user_id = ?`,
      args: [
        noteId || null,
        cloudPublicId,
        cloudUrl,
        mimeType,
        byteSize,
        sha256,
        width || null,
        height || null,
        fileName || null,
        kind || null,
        serverRevision,
        nowIso,
        attachmentId,
        userId,
      ],
    });
  } else {
    await db.execute({
      sql: `INSERT INTO attachments (
              id, user_id, note_id, created_at, updated_at, mime_type,
              byte_size, width, height, sha256, server_revision,
              cloud_public_id, cloud_url, file_name, kind
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        attachmentId,
        userId,
        noteId || null,
        nowIso,
        nowIso,
        mimeType,
        byteSize,
        width || null,
        height || null,
        sha256,
        serverRevision,
        cloudPublicId,
        cloudUrl,
        fileName || 'attachment',
        kind || 'image',
      ],
    });
  }

  return {
    success: true,
    attachment: {
      id: attachmentId,
      userId,
      noteId: noteId || null,
      cloudPublicId,
      cloudUrl,
      mimeType,
      byteSize,
      sha256,
      fileName: fileName || 'attachment',
      kind: kind || 'image',
      serverRevision,
      updatedAt: nowIso,
    },
  };
}

export async function getAttachmentMetadata(
  db: Client,
  userId: string,
  attachmentId: string
): Promise<Record<string, any>> {
  const res = await db.execute({
    sql: 'SELECT * FROM attachments WHERE id = ? AND user_id = ?',
    args: [attachmentId, userId],
  });

  if (res.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Attachment not found', 404);
  }

  const row = res.rows[0];
  return {
    id: row.id,
    userId: row.user_id,
    noteId: row.note_id,
    fileName: row.file_name,
    kind: row.kind,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    mimeType: row.mime_type,
    byteSize: row.byte_size,
    width: row.width,
    height: row.height,
    sha256: row.sha256,
    serverRevision: row.server_revision,
    isDeleted: Boolean(row.is_deleted),
    deletedAt: row.deleted_at,
    cloudPublicId: row.cloud_public_id,
    cloudUrl: row.cloud_url,
  };
}
