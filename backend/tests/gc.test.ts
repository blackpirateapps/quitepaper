import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import { runGarbageCollection } from '../src/gc/garbageCollector.js';
import { profileUserStorage } from '../src/gc/storageProfiler.js';
import { processDestructionJobs } from '../src/gc/destructionJobProcessor.js';

describe('Storage Profiler & Garbage Collection Engine Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Profiles user storage and computes accurate category breakdowns', async () => {
    const userId = 'mock:user-profile-test';
    const noteId = '11111111-2222-3333-4444-555555555555';

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
          contentCiphertext: 'A'.repeat(500),
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    const profileRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/storage/profile',
      headers: { authorization: `Bearer ${userId}` },
    });

    expect(profileRes.statusCode).toBe(200);
    const profile = profileRes.body;
    expect(profile.tables.notes.rowCount).toBe(1);
    expect(profile.tables.notes.approximatePayloadBytes).toBeGreaterThanOrEqual(500);
    expect(profile.tables.syncChanges.rowCount).toBe(1);
    expect(profile.totalEstimatedBytes).toBeGreaterThan(0);
  });

  it('Performs dry-run GC without deleting records', async () => {
    const userId = 'mock:user-dryrun-test';
    const noteId = '22222222-3333-4444-5555-666666666666';

    // Create note
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
          contentCiphertext: 'dryrun-content',
          contentNonce: 'nonce-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // Run dry-run GC
    const gcRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/storage/gc',
      headers: { authorization: `Bearer ${userId}` },
      body: { dryRun: true },
    });

    expect(gcRes.statusCode).toBe(200);
    expect(gcRes.body.dryRun).toBe(true);

    // Verify records were NOT deleted
    const db = getDbClient();
    const notesCount = await db.execute({
      sql: 'SELECT COUNT(*) as count FROM notes',
    });
    expect(Number(notesCount.rows[0].count)).toBe(1);
  });

  it('Executes full incremental GC pass and reclaims stale records', async () => {
    const userId = 'mock:user-real-gc';
    const db = getDbClient();

    // 1. Create user in users table
    const userRes = await db.execute({
      sql: 'SELECT id FROM users WHERE firebase_uid = ?',
      args: ['user-real-gc'],
    });
    let internalUserId = userRes.rows[0]?.id as string;
    if (!internalUserId) {
      internalUserId = 'user-real-gc-id';
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [internalUserId, 'user-real-gc', new Date().toISOString(), new Date().toISOString()],
      });
    }

    // 2. Set up device checkpoint at revision 50
    await db.execute({
      sql: `INSERT INTO sync_devices (id, user_id, last_acknowledged_revision, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)`,
      args: ['dev-1', internalUserId, 50, new Date().toISOString(), new Date().toISOString(), new Date().toISOString()],
    });

    // 3. Insert historical sync_changes with revisions 1 to 10 (< 50)
    for (let r = 1; r <= 10; r++) {
      await db.execute({
        sql: `INSERT INTO sync_changes (id, user_id, note_id, revision, change_type, payload_json, timestamp)
              VALUES (?, ?, ?, ?, 'upsert', '{}', ?)`,
        args: [`change-${r}`, internalUserId, `note-${r}`, r, new Date().toISOString()],
      });
    }

    // 4. Insert expired idempotency key (> 10 days old)
    const oldDate = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
    const olderOrphanDate = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000).toISOString();
    await db.execute({
      sql: `INSERT INTO idempotency_keys (key, user_id, endpoint, response_code, response_body, created_at)
            VALUES (?, ?, '/test', 200, '{"test":true}', ?)`,
      args: ['old-idem-key', internalUserId, oldDate],
    });

    // 5. Insert orphaned attachment past grace period (> 20 days old)
    const attId = '77777777-7777-7777-7777-777777777777';
    await db.execute({
      sql: `INSERT INTO attachments (id, user_id, created_at, updated_at, mime_type, byte_size, status, orphaned_at)
            VALUES (?, ?, ?, ?, 'image/png', 5000, 'orphaned', ?)`,
      args: [attId, internalUserId, olderOrphanDate, olderOrphanDate, olderOrphanDate],
    });

    // 6. Run GC
    const gcSummary = await runGarbageCollection(db, internalUserId, {
      dryRun: false,
      batchSize: 100,
      orphanGracePeriodDays: 14,
    });

    expect(gcSummary.syncChangesDeleted).toBe(10);
    expect(gcSummary.idempotencyKeysDeleted).toBe(1);
    expect(gcSummary.destructionJobsCreated).toBeGreaterThanOrEqual(1);
    expect(gcSummary.destructionJobsCompleted).toBeGreaterThanOrEqual(1);

    // Verify orphaned attachment was permanently destroyed
    const attCheck = await db.execute({
      sql: 'SELECT id FROM attachments WHERE id = ?',
      args: [attId],
    });
    expect(attCheck.rows.length).toBe(0);
  });

  it('Is crash-safe and idempotent when run repeatedly', async () => {
    const userId = 'mock:user-idempotent-gc';
    const db = getDbClient();

    // First GC run
    const res1 = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/storage/gc',
      headers: { authorization: `Bearer ${userId}` },
      body: { dryRun: false },
    });
    expect(res1.statusCode).toBe(200);

    // Immediate second GC run should complete cleanly with zero errors
    const res2 = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/storage/gc',
      headers: { authorization: `Bearer ${userId}` },
      body: { dryRun: false },
    });
    expect(res2.statusCode).toBe(200);
    expect(res2.body.destructionJobsFailed).toBe(0);
  });

  it('Enforces cross-user isolation for storage operations', async () => {
    const userA = 'mock:user-iso-a';
    const userB = 'mock:user-iso-b';
    const attachmentA = '88888888-8888-8888-8888-888888888888';

    // User A confirms attachment
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/attachments/confirm',
      headers: { authorization: `Bearer ${userA}` },
      body: {
        attachmentId: attachmentA,
        cloudPublicId: 'cloud_user_a',
        cloudUrl: 'https://res.cloudinary.com/demo/raw/upload/cloud_user_a',
        byteSize: 1000,
      },
    });

    // User B attempts to delete User A's attachment -> 404 or 403 Forbidden
    const attackRes = await handleApiRequest({
      method: 'DELETE',
      url: `/api/v1/storage/resources/attachment/${attachmentA}`,
      headers: { authorization: `Bearer ${userB}` },
    });

    expect(attackRes.statusCode).toBe(404);

    // Verify User A's attachment still exists
    const checkRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/attachments/${attachmentA}`,
      headers: { authorization: `Bearer ${userA}` },
    });
    expect(checkRes.statusCode).toBe(200);
  });
});
