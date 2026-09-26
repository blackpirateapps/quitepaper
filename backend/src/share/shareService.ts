import { Client } from '@libsql/client';
import crypto from 'crypto';
import { ApiError } from '../errors/apiError.js';
import {
  createShareSchema,
  updateShareSchema,
  shareUploadAuthSchema,
} from '../validation/schemas.js';
import { createPublicShareUploadAuth } from '../attachments/cloudinaryService.js';
import { MAX_FILE_SIZE_BYTES } from '../storage/quotaService.js';
import {
  generateShareSlug,
  encryptShareContent,
  decryptShareContent,
} from './shareCrypto.js';

/** Shares stay live for 30 days, then the read-time gate + GC retire them. */
export const SHARE_TTL_DAYS = 30;

function shareBaseUrl(): string {
  return (process.env.PUBLIC_SHARE_BASE_URL || 'https://quietpaper.blackpiratex.com').replace(/\/+$/, '');
}

function buildShareUrl(slug: string): string {
  return `${shareBaseUrl()}/note/${slug}`;
}

export interface CreatedShare {
  shareId: string;
  url: string;
  visibility: string;
  title: string;
  createdAt: string;
  expiresAt: string;
}

/**
 * Creates a public share for a note. The client has already decrypted the note
 * and uploaded its attachments to the public Cloudinary folder; here we persist
 * the plaintext markdown (public/unlisted) or the password-encrypted blob
 * (password tier) plus the attachment references GC needs to clean up later.
 */
export async function createShare(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<CreatedShare> {
  const parsed = createShareSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid share payload: ${parsed.error.errors.map(e => e.message).join(', ')}`,
      400,
      parsed.error.errors
    );
  }

  const { noteId, title, contentMarkdown, visibility, password, attachments } = parsed.data;

  // Verify note ownership when the note exists server-side (it may be local-only).
  const noteRes = await db.execute({
    sql: 'SELECT user_id FROM notes WHERE id = ?',
    args: [noteId],
  });
  if (noteRes.rows.length > 0 && noteRes.rows[0].user_id !== userId) {
    throw new ApiError('FORBIDDEN', 'Cannot share a note that belongs to another user', 403);
  }

  const slug = generateShareSlug();
  const now = new Date();
  const nowIso = now.toISOString();
  const expiresAtIso = new Date(now.getTime() + SHARE_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();

  let contentMarkdownCol: string | null = contentMarkdown;
  let ciphertext: string | null = null;
  let salt: string | null = null;
  let iv: string | null = null;
  let tag: string | null = null;

  if (visibility === 'password') {
    // superRefine guarantees password is present, but guard for safety.
    if (!password) {
      throw new ApiError('BAD_REQUEST', 'A password is required for password-protected shares', 400);
    }
    const enc = encryptShareContent(contentMarkdown, password);
    ciphertext = enc.ciphertext;
    salt = enc.salt;
    iv = enc.iv;
    tag = enc.tag;
    contentMarkdownCol = null; // never store plaintext for the password tier
  }

  await db.execute({
    sql: `INSERT INTO note_shares (
            id, user_id, note_id, title, content_markdown,
            content_ciphertext, content_salt, content_iv, content_tag,
            visibility, view_count, status, created_at, updated_at, expires_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'active', ?, ?, ?)`,
    args: [
      slug,
      userId,
      noteId,
      title,
      contentMarkdownCol,
      ciphertext,
      salt,
      iv,
      tag,
      visibility,
      nowIso,
      nowIso,
      expiresAtIso,
    ],
  });

  for (const att of attachments) {
    await db.execute({
      sql: `INSERT INTO note_share_attachments (
              id, share_id, user_id, cloud_public_id, cloud_url, resource_type, byte_size, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        crypto.randomUUID(),
        slug,
        userId,
        att.cloudPublicId,
        att.cloudUrl,
        att.resourceType,
        att.byteSize,
        nowIso,
      ],
    });
  }

  return {
    shareId: slug,
    url: buildShareUrl(slug),
    visibility,
    title,
    createdAt: nowIso,
    expiresAt: expiresAtIso,
  };
}

/**
 * Returns signed Cloudinary upload authorization for a PUBLIC (plaintext) share
 * attachment. Enforces the per-file size limit but, unlike E2E uploads, does not
 * reserve quota — share copies are transient and expire within 30 days.
 */
export async function authorizeShareUpload(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<Record<string, any>> {
  const parsed = shareUploadAuthSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid share upload request: ${parsed.error.errors.map(e => e.message).join(', ')}`,
      400,
      parsed.error.errors
    );
  }

  const { uploadId, kind, byteSize } = parsed.data;
  if (byteSize > MAX_FILE_SIZE_BYTES) {
    throw new ApiError(
      'FILE_TOO_LARGE',
      `File exceeds the ${Math.floor(MAX_FILE_SIZE_BYTES / (1000 * 1000))} MB per-file limit`,
      413
    );
  }

  const sanitizedId = uploadId.replace(/[^a-zA-Z0-9_-]/g, '');
  const publicId = `${userId}_share_${sanitizedId}`;
  return createPublicShareUploadAuth(publicId, kind);
}

export interface ShareListItem {
  shareId: string;
  noteId: string;
  title: string;
  visibility: string;
  url: string;
  viewCount: number;
  status: string;
  createdAt: string;
  expiresAt: string;
}

/** Lists a user's active shares (most recent first) for the management UI. */
export async function listShares(db: Client, userId: string): Promise<ShareListItem[]> {
  const res = await db.execute({
    sql: `SELECT id, note_id, title, visibility, view_count, status, created_at, expires_at
          FROM note_shares
          WHERE user_id = ? AND status = 'active'
          ORDER BY created_at DESC`,
    args: [userId],
  });

  return res.rows.map(row => ({
    shareId: row.id as string,
    noteId: row.note_id as string,
    title: (row.title as string) || '',
    visibility: row.visibility as string,
    url: buildShareUrl(row.id as string),
    viewCount: Number(row.view_count || 0),
    status: row.status as string,
    createdAt: row.created_at as string,
    expiresAt: row.expires_at as string,
  }));
}

/**
 * Updates a share's visibility and/or password. Switching to the password tier
 * (or changing the password) requires the current plaintext markdown, which only
 * exists when the share is currently public/unlisted; switching a password share
 * back to public restores its decrypted markdown from the submitted password.
 */
export async function updateShare(
  db: Client,
  userId: string,
  shareId: string,
  rawInput: unknown
): Promise<{ success: boolean; shareId: string; visibility: string }> {
  const parsed = updateShareSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid share update: ${parsed.error.errors.map(e => e.message).join(', ')}`,
      400,
      parsed.error.errors
    );
  }

  const res = await db.execute({
    sql: `SELECT visibility, content_markdown, content_ciphertext, content_salt, content_iv, content_tag
          FROM note_shares WHERE id = ? AND user_id = ? AND status = 'active'`,
    args: [shareId, userId],
  });
  if (res.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Share not found', 404);
  }
  const row = res.rows[0];
  const currentVisibility = row.visibility as string;

  const nextVisibility = parsed.data.visibility ?? currentVisibility;
  const nowIso = new Date().toISOString();

  // Resolve the current plaintext so we can (re-)encrypt or restore as needed.
  const currentPlaintext = (row.content_markdown as string | null) ?? null;

  let contentMarkdownCol: string | null = currentPlaintext;
  let ciphertext: string | null = (row.content_ciphertext as string | null) ?? null;
  let salt: string | null = (row.content_salt as string | null) ?? null;
  let iv: string | null = (row.content_iv as string | null) ?? null;
  let tag: string | null = (row.content_tag as string | null) ?? null;

  const passwordProvided = parsed.data.password !== undefined && parsed.data.password !== null;

  if (nextVisibility === 'password') {
    if (passwordProvided) {
      // (Re)encrypt from the known plaintext. For an already-encrypted share with
      // no plaintext available, the password change requires the plaintext, which
      // the client must resend via re-create; reject to avoid corrupting content.
      if (currentPlaintext === null) {
        throw new ApiError(
          'BAD_REQUEST',
          'Cannot change the password of an already-encrypted share without resharing the note',
          400
        );
      }
      const enc = encryptShareContent(currentPlaintext, parsed.data.password as string);
      ciphertext = enc.ciphertext;
      salt = enc.salt;
      iv = enc.iv;
      tag = enc.tag;
      contentMarkdownCol = null;
    } else if (currentVisibility !== 'password') {
      // Switching to password tier without a password is invalid (superRefine covers
      // the common case, but guard the visibility-only PATCH path).
      throw new ApiError('BAD_REQUEST', 'A password is required when switching to password visibility', 400);
    }
  } else {
    // public / unlisted: ensure plaintext is available and clear any ciphertext.
    if (currentPlaintext === null) {
      throw new ApiError(
        'BAD_REQUEST',
        'Cannot make an encrypted share public without resharing the note',
        400
      );
    }
    contentMarkdownCol = currentPlaintext;
    ciphertext = null;
    salt = null;
    iv = null;
    tag = null;
  }

  await db.execute({
    sql: `UPDATE note_shares SET
            visibility = ?, content_markdown = ?, content_ciphertext = ?,
            content_salt = ?, content_iv = ?, content_tag = ?, updated_at = ?
          WHERE id = ? AND user_id = ?`,
    args: [nextVisibility, contentMarkdownCol, ciphertext, salt, iv, tag, nowIso, shareId, userId],
  });

  return { success: true, shareId, visibility: nextVisibility };
}

/**
 * Deletes a share: marks it deleted and enqueues destruction jobs so the existing
 * GC pipeline purges its public Cloudinary copies.
 */
export async function deleteShare(
  db: Client,
  userId: string,
  shareId: string
): Promise<{ success: boolean; destructionJobsCreated: number }> {
  const res = await db.execute({
    sql: `SELECT id FROM note_shares WHERE id = ? AND user_id = ? AND status = 'active'`,
    args: [shareId, userId],
  });
  if (res.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Share not found', 404);
  }

  const jobsCreated = await enqueueShareAttachmentDestruction(db, userId, shareId);

  const nowIso = new Date().toISOString();
  await db.execute({
    sql: `UPDATE note_shares SET status = 'deleted', updated_at = ? WHERE id = ? AND user_id = ?`,
    args: [nowIso, shareId, userId],
  });

  return { success: true, destructionJobsCreated: jobsCreated };
}

/**
 * Enqueues destruction jobs for every public Cloudinary copy attached to a share.
 * Shared by manual delete and the GC expiry stage. Returns the number of jobs created.
 */
export async function enqueueShareAttachmentDestruction(
  db: Client,
  userId: string,
  shareId: string
): Promise<number> {
  const attsRes = await db.execute({
    sql: `SELECT id, cloud_public_id, resource_type FROM note_share_attachments WHERE share_id = ? AND user_id = ?`,
    args: [shareId, userId],
  });

  const nowIso = new Date().toISOString();
  let created = 0;

  for (const att of attsRes.rows) {
    const resourceId = att.id as string;
    const cloudPublicId = att.cloud_public_id as string | null;
    const resourceType = (att.resource_type as string) || 'image';

    const existingJob = await db.execute({
      sql: `SELECT id FROM destruction_jobs WHERE user_id = ? AND resource_id = ? AND state IN ('pending', 'processing', 'retrying')`,
      args: [userId, resourceId],
    });
    if (existingJob.rows.length > 0) continue;

    await db.execute({
      sql: `INSERT INTO destruction_jobs (
              id, user_id, resource_type, resource_id, cloudinary_public_id, operation,
              state, attempt_count, available_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        crypto.randomUUID(),
        userId,
        `share_attachment_${resourceType}`,
        resourceId,
        cloudPublicId || null,
        'delete_share_attachment',
        'pending',
        0,
        nowIso,
        nowIso,
        nowIso,
      ],
    });
    created++;
  }

  return created;
}

export type PublicShareResult =
  | { state: 'ok'; title: string; contentMarkdown: string; createdAt: string; expiresAt: string; visibility: string }
  | { state: 'password_required' }
  | { state: 'wrong_password' }
  | { state: 'not_found' }
  | { state: 'expired' };

/**
 * Reads a public share for rendering. This is the AUTHORITATIVE expiry gate: an
 * active share past its expiry is reported as expired (and lazily marked so)
 * regardless of when GC last ran. Increments view_count on a successful render.
 */
export async function getPublicShare(
  db: Client,
  shareId: string,
  password?: string
): Promise<PublicShareResult> {
  const res = await db.execute({
    sql: `SELECT title, content_markdown, content_ciphertext, content_salt, content_iv, content_tag,
                 visibility, status, created_at, expires_at
          FROM note_shares WHERE id = ?`,
    args: [shareId],
  });

  if (res.rows.length === 0) {
    return { state: 'not_found' };
  }

  const row = res.rows[0];
  const status = row.status as string;
  if (status !== 'active') {
    return status === 'expired' ? { state: 'expired' } : { state: 'not_found' };
  }

  const expiresAt = row.expires_at as string;
  if (new Date(expiresAt).getTime() <= Date.now()) {
    // Lazily retire the share so subsequent reads and GC agree.
    try {
      await db.execute({
        sql: `UPDATE note_shares SET status = 'expired', updated_at = ? WHERE id = ? AND status = 'active'`,
        args: [new Date().toISOString(), shareId],
      });
    } catch {
      /* best-effort; read-time gate already returns expired */
    }
    return { state: 'expired' };
  }

  const visibility = row.visibility as string;
  const createdAt = row.created_at as string;
  const title = (row.title as string) || '';

  let markdown: string;

  if (visibility === 'password') {
    if (!password) {
      return { state: 'password_required' };
    }
    const decrypted = decryptShareContent(
      {
        ciphertext: (row.content_ciphertext as string) || '',
        salt: (row.content_salt as string) || '',
        iv: (row.content_iv as string) || '',
        tag: (row.content_tag as string) || '',
      },
      password
    );
    if (decrypted === null) {
      return { state: 'wrong_password' };
    }
    markdown = decrypted;
  } else {
    markdown = (row.content_markdown as string) || '';
  }

  // Best-effort view counter; never block rendering on it.
  try {
    await db.execute({
      sql: `UPDATE note_shares SET view_count = view_count + 1 WHERE id = ?`,
      args: [shareId],
    });
  } catch {
    /* ignore */
  }

  return { state: 'ok', title, contentMarkdown: markdown, createdAt, expiresAt, visibility };
}
