import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Sync Engine & Revision Tracking Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Pushes changes and increments cursor', async () => {
    const noteId = '22222222-2222-2222-2222-222222222222';
    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-sync-1' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'ciphertext-payload-1',
          contentNonce: 'nonce-payload-12345678',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    expect(pushRes.statusCode).toBe(200);
    expect(pushRes.body.results.length).toBe(1);
    expect(pushRes.body.results[0].revision).toBe(1);
    expect(pushRes.body.cursor).toBe(1);

    // Pull from cursor 0
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: 'Bearer mock:user-sync-1' },
      body: { cursor: 0, limit: 50 },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(1);
    expect(pullRes.body.changes[0].contentCiphertext).toBe('ciphertext-payload-1');
    expect(pullRes.body.cursor).toBe(1);
  });

  it('Handles idempotency keys safely without creating duplicate revisions', async () => {
    const noteId = '33333333-3333-3333-3333-333333333333';
    const idemKey = 'idem-req-unique-999';

    const req = {
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-idem' },
      body: {
        idempotencyKey: idemKey,
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: true,
          contentCiphertext: 'cipher-idem-1',
          contentNonce: 'nonce-idem-12345678',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    };

    // First attempt
    const res1 = await handleApiRequest(req);
    expect(res1.statusCode).toBe(200);
    const rev1 = res1.body.results[0].revision;

    // Retry with identical idempotency key
    const res2 = await handleApiRequest(req);
    expect(res2.statusCode).toBe(200);
    expect(res2.body.results[0].revision).toBe(rev1);

    // Verify cursor only advanced once
    const cursorRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/cursor',
      headers: { authorization: 'Bearer mock:user-idem' },
    });
    expect(cursorRes.body.cursor).toBe(1);
  });

  it('Supports multi-device flow (Device A pushes, Device B pulls)', async () => {
    const noteId = '44444444-4444-4444-4444-444444444444';
    
    // Device A pushes note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:same-user' },
      body: {
        deviceId: 'device-phone',
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'encrypted-note-from-phone',
          contentNonce: 'nonce-from-phone-123456',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // Device B (Tablet) pulls
    const tabletPull = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: 'Bearer mock:same-user' },
      body: { cursor: 0 },
    });

    expect(tabletPull.statusCode).toBe(200);
    expect(tabletPull.body.changes.length).toBe(1);
    expect(tabletPull.body.changes[0].contentCiphertext).toBe('encrypted-note-from-phone');
  });

  it('Allows pushing deletion tombstones with empty contentCiphertext and contentNonce', async () => {
    const noteId = '66666666-6666-6666-6666-666666666666';

    const deleteRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-del' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: true,
          pinned: false,
          contentCiphertext: '',
          contentNonce: '',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          isDeleted: true,
          deletedAt: new Date().toISOString(),
        }],
      },
    });

    expect(deleteRes.statusCode).toBe(200);
    expect(deleteRes.body.results.length).toBe(1);
    expect(deleteRes.body.results[0].id).toBe(noteId);

    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: 'Bearer mock:user-del' },
      body: { cursor: 0 },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(1);
    expect(pullRes.body.changes[0].changeType).toBe('delete');
  });

  it('Rejects active notes with missing or empty contentCiphertext or contentNonce', async () => {
    const noteId = '77777777-7777-7777-7777-777777777777';

    const failRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-fail' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: '',
          contentNonce: '',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          isDeleted: false,
        }],
      },
    });

    expect(failRes.statusCode).toBe(400);
    expect(failRes.body.error.code).toBe('BAD_REQUEST');
  });
});
