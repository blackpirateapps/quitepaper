import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import {
  uploadDocumentAuthRequestSchema,
  confirmDocumentSchema,
} from '../validation/schemas.js';
import {
  getCloudinaryConfig,
  createSignedUploadAuth,
  SignedUploadParams,
} from '../attachments/cloudinaryService.js';

export async function authorizeDocumentUpload(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<SignedUploadParams> {
  const parseRes = uploadDocumentAuthRequestSchema.safeParse(rawInput);
  if (!parseRes.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid document upload auth request: ${parseRes.error.errors.map(e => e.message).join(', ')}`,
      400,
      parseRes.error.errors
    );
  }

  const { documentId, noteId } = parseRes.data;

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
  const publicId = `${userId}_doc_${documentId}`;

  return createSignedUploadAuth(publicId, config);
}

export async function confirmDocumentUpload(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<{ success: boolean; document: Record<string, any> }> {
  const parseRes = confirmDocumentSchema.safeParse(rawInput);
  if (!parseRes.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid document confirmation payload: ${parseRes.error.errors.map(e => e.message).join(', ')}`,
      400,
      parseRes.error.errors
    );
  }

  const {
    documentId,
    noteId,
    cloudPublicId,
    cloudUrl,
    title = 'Scanned Document',
    mimeType = 'application/pdf',
    byteSize = 0,
    pageCount = 1,
    sha256 = '',
  } = parseRes.data;

  const nowIso = new Date().toISOString();

  // Check if document record exists
  const existingRes = await db.execute({
    sql: 'SELECT id, user_id, server_revision FROM documents WHERE id = ?',
    args: [documentId],
  });

  let serverRevision = 1;

  if (existingRes.rows.length > 0) {
    const row = existingRes.rows[0];
    if (row.user_id !== userId) {
      throw new ApiError('FORBIDDEN', 'Document belongs to another user', 403);
    }
    serverRevision = ((row.server_revision as number) || 0) + 1;

    await db.execute({
      sql: `UPDATE documents SET
              note_id = COALESCE(?, note_id),
              title = COALESCE(?, title),
              cloud_public_id = ?,
              cloud_url = ?,
              mime_type = ?,
              byte_size = ?,
              page_count = ?,
              sha256 = ?,
              server_revision = ?,
              updated_at = ?
            WHERE id = ? AND user_id = ?`,
      args: [
        noteId || null,
        title,
        cloudPublicId,
        cloudUrl,
        mimeType,
        byteSize,
        pageCount,
        sha256,
        serverRevision,
        nowIso,
        documentId,
        userId,
      ],
    });
  } else {
    await db.execute({
      sql: `INSERT INTO documents (
              id, user_id, note_id, title, created_at, updated_at, mime_type,
              byte_size, page_count, sha256, server_revision,
              cloud_public_id, cloud_url
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        documentId,
        userId,
        noteId || null,
        title,
        nowIso,
        nowIso,
        mimeType,
        byteSize,
        pageCount,
        sha256,
        serverRevision,
        cloudPublicId,
        cloudUrl,
      ],
    });
  }

  return {
    success: true,
    document: {
      id: documentId,
      userId,
      noteId: noteId || null,
      title,
      cloudPublicId,
      cloudUrl,
      mimeType,
      byteSize,
      pageCount,
      sha256,
      serverRevision,
      updatedAt: nowIso,
    },
  };
}

export async function getDocumentMetadata(
  db: Client,
  userId: string,
  documentId: string
): Promise<Record<string, any>> {
  const res = await db.execute({
    sql: 'SELECT * FROM documents WHERE id = ? AND user_id = ?',
    args: [documentId, userId],
  });

  if (res.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Document not found', 404);
  }

  const row = res.rows[0];
  return {
    id: row.id,
    userId: row.user_id,
    noteId: row.note_id,
    title: row.title || 'Scanned Document',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    mimeType: row.mime_type,
    byteSize: row.byte_size,
    pageCount: row.page_count,
    sha256: row.sha256,
    serverRevision: row.server_revision,
    isDeleted: Boolean(row.is_deleted),
    deletedAt: row.deleted_at,
    cloudPublicId: row.cloud_public_id,
    cloudUrl: row.cloud_url,
  };
}
