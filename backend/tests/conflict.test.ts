import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Conflict Detection Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Detects revision conflict when baseRevision is older than server revision', async () => {
    const noteId = '55555555-5555-5555-5555-555555555555';

    // Initial create -> revision 1
    const createRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-conflict' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'v1-ciphertext',
          contentNonce: 'nonce-v1-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 0,
        }],
      },
    });
    expect(createRes.body.results[0].revision).toBe(1);

    // Device A edits note -> revision 2
    const editResA = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-conflict' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'v2-from-device-A',
          contentNonce: 'nonce-v2-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 1,
        }],
      },
    });
    expect(editResA.body.results[0].revision).toBe(2);

    // Device B tries to edit note based on obsolete baseRevision: 1
    const editResB = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-conflict' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'v2-from-device-B-stale',
          contentNonce: 'nonce-v2b-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 1, // Stale base revision!
        }],
      },
    });

    expect(editResB.statusCode).toBe(200);
    expect(editResB.body.results.length).toBe(0);
    expect(editResB.body.conflicts.length).toBe(1);
    expect(editResB.body.conflicts[0].code).toBe('SYNC_CONFLICT');
    expect(editResB.body.conflicts[0].serverRevision).toBe(2);
  });
});
