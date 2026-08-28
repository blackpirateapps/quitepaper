import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import { getSafeSyncBoundary } from '../src/gc/garbageCollector.js';

describe('Cloud Storage Lifecycle & Synchronized Trash Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Synchronizes note moving to Trash across devices while preserving content', async () => {
    const noteId = '11111111-1111-1111-1111-111111111111';
    const userId = 'mock:user-trash-1';

    // 1. Device A creates active note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        deviceId: 'device-a',
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'encrypted-note-body',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // 2. Device A moves note to Trash
    const trashRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        deviceId: 'device-a',
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: true,
          pinned: false,
          contentCiphertext: 'encrypted-note-body',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          deletedAt: new Date().toISOString(),
        }],
      },
    });
    expect(trashRes.statusCode).toBe(200);

    // 3. Device B pulls changes from cursor 0
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: `Bearer ${userId}` },
      body: { cursor: 1, deviceId: 'device-b' },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(1);
    const pulledItem = pullRes.body.changes[0];
    expect(pulledItem.id).toBe(noteId);
    expect(pulledItem.trashed).toBe(true);
    expect(pulledItem.changeType).toBe('upsert');
    expect(pulledItem.contentCiphertext).toBe('encrypted-note-body'); // Content preserved in Trash!
  });

  it('Synchronizes note Restore from Trash across devices', async () => {
    const noteId = '22222222-2222-2222-2222-222222222222';
    const userId = 'mock:user-restore-1';

    // 1. Create and trash note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: true,
          pinned: false,
          contentCiphertext: 'encrypted-body-2',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // 2. Restore note from Trash
    const restoreRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'encrypted-body-2',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          deletedAt: null,
        }],
      },
    });
    expect(restoreRes.statusCode).toBe(200);

    // 3. Pull on another device
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: `Bearer ${userId}` },
      body: { cursor: 1 },
    });
    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes[0].trashed).toBe(false);
    expect(pullRes.body.changes[0].deletedAt).toBeNull();
  });

  it('Permanent deletion destroys note versions and emits tombstone', async () => {
    const noteId = '33333333-3333-3333-3333-333333333333';
    const versionId = '33333333-3333-3333-3333-333333333334';
    const userId = 'mock:user-perm-del';

    // 1. Create note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'encrypted-secret',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // 2. Push version for note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/versions/push',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        versions: [{
          id: versionId,
          noteId,
          versionNumber: 1,
          contentCiphertext: 'version-ciphertext',
          contentNonce: 'nonce-version-123456',
          charCount: 20,
          wordCount: 4,
          createdAt: new Date().toISOString(),
        }],
      },
    });

    // 3. Explicit permanent deletion
    const delRes = await handleApiRequest({
      method: 'POST',
      url: `/api/v1/notes/${noteId}/permanent-delete`,
      headers: { authorization: `Bearer ${userId}` },
    });
    expect(delRes.statusCode).toBe(200);
    expect(delRes.body.success).toBe(true);

    // 4. Verify note versions were deleted
    const db = getDbClient();
    const versionCheck = await db.execute({
      sql: 'SELECT id FROM note_versions WHERE note_id = ?',
      args: [noteId],
    });
    expect(versionCheck.rows.length).toBe(0);

    // 5. Verify sync pull receives delete tombstone
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: `Bearer ${userId}` },
      body: { cursor: 1 },
    });
    expect(pullRes.statusCode).toBe(200);
    const deleteTombstone = pullRes.body.changes.find((c: any) => c.id === noteId);
    expect(deleteTombstone).toBeDefined();
    expect(deleteTombstone.changeType).toBe('delete');
  });

  it('Calculates safe sync boundary from active devices (< 30 days) and ignores expired (> 90 days)', async () => {
    const db = getDbClient();
    const userId = 'user-calc-boundary';

    // Insert user
    await db.execute({
      sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
      args: [userId, 'fb-user-calc', new Date().toISOString(), new Date().toISOString()],
    });

    const now = Date.now();
    const twoDaysAgo = new Date(now - 2 * 24 * 60 * 60 * 1000).toISOString();
    const tenDaysAgo = new Date(now - 10 * 24 * 60 * 60 * 1000).toISOString();
    const hundredDaysAgo = new Date(now - 100 * 24 * 60 * 60 * 1000).toISOString();

    // Device A (active, ack rev 100)
    await db.execute({
      sql: `INSERT INTO sync_devices (id, user_id, last_acknowledged_revision, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)`,
      args: ['dev-a', userId, 100, twoDaysAgo, twoDaysAgo, twoDaysAgo],
    });

    // Device B (active, ack rev 80)
    await db.execute({
      sql: `INSERT INTO sync_devices (id, user_id, last_acknowledged_revision, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)`,
      args: ['dev-b', userId, 80, tenDaysAgo, tenDaysAgo, tenDaysAgo],
    });

    // Device C (expired, ack rev 10)
    await db.execute({
      sql: `INSERT INTO sync_devices (id, user_id, last_acknowledged_revision, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)`,
      args: ['dev-c', userId, 10, hundredDaysAgo, hundredDaysAgo, hundredDaysAgo],
    });

    const boundary = await getSafeSyncBoundary(db, userId, 30);
    // Should be min of active devices (min(100, 80) = 80), ignoring expired device C with 10
    expect(boundary).toBe(80);
  });

  it('Throws SYNC_CURSOR_EXPIRED 410 when client cursor is older than earliest retained revision', async () => {
    const userId = 'mock:user-cursor-exp';
    const noteId = '44444444-4444-4444-4444-444444444444';

    // Push 3 changes (revisions 1, 2, 3)
    for (let i = 0; i < 3; i++) {
      await handleApiRequest({
        method: 'POST',
        url: '/api/v1/sync/push',
        headers: { authorization: `Bearer ${userId}` },
        body: {
          changes: [{
            id: noteId,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            archived: false,
            trashed: false,
            pinned: false,
            contentCiphertext: `content-rev-${i + 1}`,
            contentNonce: 'nonce-123456789012',
            contentVersion: 1,
            encryptionKeyVersion: 1,
          }],
        },
      });
    }

    const db = getDbClient();
    // Simulate GC removing revision 1 and 2, so earliest retained revision is 3
    await db.execute({
      sql: 'DELETE FROM sync_changes WHERE revision < 3',
    });

    // Client requests cursor 0 (which is older than min revision 3)
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: `Bearer ${userId}` },
      body: { cursor: 1 },
    });

    expect(pullRes.statusCode).toBe(410);
    expect(pullRes.body.error.code).toBe('SYNC_CURSOR_EXPIRED');
    expect(pullRes.body.error.details.cursorExpired).toBe(true);
    expect(pullRes.body.error.details.minRetainedRevision).toBe(3);
  });

  it('Supports client reference projection updates and orphan transitions', async () => {
    const userId = 'mock:user-ref-proj';
    const noteId = '55555555-5555-5555-5555-555555555555';
    const attachmentId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const documentId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

    // 1. Confirm attachment & document
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/attachments/confirm',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        attachmentId,
        cloudPublicId: 'cloud_att_1',
        cloudUrl: 'https://res.cloudinary.com/demo/raw/upload/cloud_att_1',
        byteSize: 1024,
      },
    });

    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/documents/confirm',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        documentId,
        cloudPublicId: 'cloud_doc_1',
        cloudUrl: 'https://res.cloudinary.com/demo/raw/upload/cloud_doc_1',
        byteSize: 2048,
      },
    });

    // 2. Send reference projection referencing attachment and document from note
    const refRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/references',
      headers: { authorization: `Bearer ${userId}` },
      body: {
        deviceId: 'phone-1',
        references: [
          { resourceType: 'attachment', resourceId: attachmentId, noteId },
          { resourceType: 'document', resourceId: documentId, noteId },
        ],
      },
    });
    expect(refRes.statusCode).toBe(200);
    expect(refRes.body.recordedReferences).toBe(2);

    // 3. Inspect storage resources -> both should be Attached
    const storageRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/storage/resources',
      headers: { authorization: `Bearer ${userId}` },
    });
    expect(storageRes.statusCode).toBe(200);
    expect(storageRes.body.totalAttachedCount).toBe(2);
    expect(storageRes.body.totalOrphanedCount).toBe(0);

    // 4. Permanently delete the note -> should transition attachment and document to Orphaned
    await handleApiRequest({
      method: 'POST',
      url: `/api/v1/notes/${noteId}/permanent-delete`,
      headers: { authorization: `Bearer ${userId}` },
    });

    const storageResAfter = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/storage/resources',
      headers: { authorization: `Bearer ${userId}` },
    });
    expect(storageResAfter.statusCode).toBe(200);
    expect(storageResAfter.body.totalAttachedCount).toBe(0);
    expect(storageResAfter.body.totalOrphanedCount).toBe(2);

    // 5. User manually deletes orphaned attachment
    const delRes = await handleApiRequest({
      method: 'DELETE',
      url: `/api/v1/storage/resources/attachment/${attachmentId}`,
      headers: { authorization: `Bearer ${userId}` },
    });
    expect(delRes.statusCode).toBe(200);
    expect(delRes.body.success).toBe(true);

    const storageResFinal = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/storage/resources',
      headers: { authorization: `Bearer ${userId}` },
    });
    expect(storageResFinal.body.totalOrphanedCount).toBe(1); // Only document remains
  });
});
