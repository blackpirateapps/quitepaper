import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

// Place-alias collection sync (spec §2.3). Mirrors the tag tests but asserts
// the crucial crypto-blind property: ids are OPAQUE deterministic hashes
// (not UUIDs), and the server stores/returns only ciphertext + revision.
describe('Backend Zero-Knowledge Place-Alias Synchronization Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  // 64-char hex HMAC-style opaque ids (NOT uuids).
  const id1 = 'a'.repeat(64);
  const id2 = 'b'.repeat(64);

  it('Pushes encrypted place aliases and pulls them with cursor pagination', async () => {
    const now = new Date().toISOString();

    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/push',
      headers: { authorization: 'Bearer mock:user-pa-1' },
      body: {
        placeAliases: [
          {
            id: id1,
            contentCiphertext: 'encrypted-alias-calcutta',
            contentNonce: 'nonce-123456789012',
            contentVersion: 1,
            encryptionKeyVersion: 1,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
          },
          {
            id: id2,
            contentCiphertext: 'encrypted-alias-kolkata',
            contentNonce: 'nonce-123456789013',
            contentVersion: 1,
            encryptionKeyVersion: 1,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
          },
        ],
      },
    });

    expect(pushRes.statusCode).toBe(200);
    expect(pushRes.body.results.length).toBe(2);
    expect(pushRes.body.results[0].id).toBe(id1);
    expect(pushRes.body.results[0].revision).toBe(1);
    expect(pushRes.body.results[1].revision).toBe(2);
    expect(pushRes.body.cursor).toBe(2);

    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/pull',
      headers: { authorization: 'Bearer mock:user-pa-1' },
      body: { cursor: 0, limit: 10 },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(2);
    expect(pullRes.body.changes[0].id).toBe(id1);
    expect(pullRes.body.changes[0].contentCiphertext).toBe('encrypted-alias-calcutta');
    expect(pullRes.body.cursor).toBe(2);
    expect(pullRes.body.hasMore).toBe(false);

    const pullCursor1 = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/place-aliases/pull?cursor=1&limit=10',
      headers: { authorization: 'Bearer mock:user-pa-1' },
    });
    expect(pullCursor1.statusCode).toBe(200);
    expect(pullCursor1.body.changes.length).toBe(1);
    expect(pullCursor1.body.changes[0].id).toBe(id2);
  });

  it('Isolates place aliases between different users', async () => {
    const now = new Date().toISOString();
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/push',
      headers: { authorization: 'Bearer mock:user-a' },
      body: {
        placeAliases: [{
          id: id1,
          contentCiphertext: 'user-a-alias',
          contentNonce: 'nonce-123456789014',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        }],
      },
    });

    const userBPull = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/pull',
      headers: { authorization: 'Bearer mock:user-b' },
      body: { cursor: 0, limit: 10 },
    });
    expect(userBPull.statusCode).toBe(200);
    expect(userBPull.body.changes.length).toBe(0);
  });

  it('Propagates place-alias deletion tombstones', async () => {
    const now = new Date().toISOString();
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/push',
      headers: { authorization: 'Bearer mock:user-del' },
      body: {
        placeAliases: [{
          id: id1,
          contentCiphertext: 'temp-alias',
          contentNonce: 'nonce-123456789015',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        }],
      },
    });

    const delRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/push',
      headers: { authorization: 'Bearer mock:user-del' },
      body: {
        placeAliases: [{
          id: id1,
          contentCiphertext: '',
          contentNonce: 'nonce-123456789015',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          createdAt: now,
          updatedAt: new Date().toISOString(),
          isDeleted: true,
          deletedAt: new Date().toISOString(),
        }],
      },
    });
    expect(delRes.statusCode).toBe(200);

    const pullDel = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/place-aliases/pull',
      headers: { authorization: 'Bearer mock:user-del' },
      body: { cursor: 1, limit: 10 },
    });
    expect(pullDel.statusCode).toBe(200);
    expect(pullDel.body.changes.length).toBe(1);
    expect(pullDel.body.changes[0].id).toBe(id1);
    expect(pullDel.body.changes[0].isDeleted).toBe(true);
    expect(pullDel.body.changes[0].deletedAt).not.toBeNull();
  });
});
