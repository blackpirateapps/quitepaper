import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Zero-Knowledge Tag Synchronization Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Pushes encrypted tags and pulls them with cursor pagination', async () => {
    const tag1Id = '11111111-1111-1111-1111-111111111111';
    const tag2Id = '22222222-2222-2222-2222-222222222222';
    const now = new Date().toISOString();

    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/push',
      headers: { authorization: 'Bearer mock:user-tag-1' },
      body: {
        tags: [
          {
            id: tag1Id,
            contentCiphertext: 'encrypted-tag-payload-work',
            contentNonce: 'nonce-123456789012',
            contentVersion: 1,
            encryptionKeyVersion: 1,
            isPinned: true,
            pinnedOrder: 0,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
          },
          {
            id: tag2Id,
            contentCiphertext: 'encrypted-tag-payload-ideas',
            contentNonce: 'nonce-123456789013',
            contentVersion: 1,
            encryptionKeyVersion: 1,
            isPinned: false,
            pinnedOrder: 0,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
          },
        ],
      },
    });

    expect(pushRes.statusCode).toBe(200);
    expect(pushRes.body.results.length).toBe(2);
    expect(pushRes.body.results[0].id).toBe(tag1Id);
    expect(pushRes.body.results[0].revision).toBe(1);
    expect(pushRes.body.results[1].id).toBe(tag2Id);
    expect(pushRes.body.results[1].revision).toBe(2);
    expect(pushRes.body.cursor).toBe(2);

    // Pull from cursor 0
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/pull',
      headers: { authorization: 'Bearer mock:user-tag-1' },
      body: { cursor: 0, limit: 10 },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(2);
    expect(pullRes.body.changes[0].id).toBe(tag1Id);
    expect(pullRes.body.changes[0].contentCiphertext).toBe('encrypted-tag-payload-work');
    expect(pullRes.body.changes[0].isPinned).toBe(true);
    expect(pullRes.body.changes[0].pinnedOrder).toBe(0);
    expect(pullRes.body.changes[1].id).toBe(tag2Id);
    expect(pullRes.body.changes[1].isPinned).toBe(false);
    expect(pullRes.body.cursor).toBe(2);
    expect(pullRes.body.hasMore).toBe(false);

    // Pull from cursor 1 -> should return only tag2
    const pullCursor1 = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/tags/pull?cursor=1&limit=10',
      headers: { authorization: 'Bearer mock:user-tag-1' },
    });

    expect(pullCursor1.statusCode).toBe(200);
    expect(pullCursor1.body.changes.length).toBe(1);
    expect(pullCursor1.body.changes[0].id).toBe(tag2Id);
  });

  it('Isolates tags between different users', async () => {
    const tagId = '33333333-3333-3333-3333-333333333333';
    const now = new Date().toISOString();

    // User A pushes tag
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/push',
      headers: { authorization: 'Bearer mock:user-a' },
      body: {
        tags: [{
          id: tagId,
          contentCiphertext: 'user-a-tag-ciphertext',
          contentNonce: 'nonce-123456789014',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          isPinned: false,
          pinnedOrder: 0,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        }],
      },
    });

    // User B pulls -> should receive 0 changes
    const userBPull = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/pull',
      headers: { authorization: 'Bearer mock:user-b' },
      body: { cursor: 0, limit: 10 },
    });

    expect(userBPull.statusCode).toBe(200);
    expect(userBPull.body.changes.length).toBe(0);
  });

  it('Propagates tag deletion tombstones', async () => {
    const tagId = '44444444-4444-4444-4444-444444444444';
    const now = new Date().toISOString();

    // Initial push
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/push',
      headers: { authorization: 'Bearer mock:user-del' },
      body: {
        tags: [{
          id: tagId,
          contentCiphertext: 'temp-tag-payload',
          contentNonce: 'nonce-123456789015',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          isPinned: false,
          pinnedOrder: 0,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        }],
      },
    });

    // Push deletion tombstone
    const delRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/push',
      headers: { authorization: 'Bearer mock:user-del' },
      body: {
        tags: [{
          id: tagId,
          contentCiphertext: '',
          contentNonce: 'nonce-123456789015',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          isPinned: false,
          pinnedOrder: 0,
          createdAt: now,
          updatedAt: new Date().toISOString(),
          isDeleted: true,
          deletedAt: new Date().toISOString(),
        }],
      },
    });

    expect(delRes.statusCode).toBe(200);

    // Pull from cursor 1 to receive deletion
    const pullDel = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/tags/pull',
      headers: { authorization: 'Bearer mock:user-del' },
      body: { cursor: 1, limit: 10 },
    });

    expect(pullDel.statusCode).toBe(200);
    expect(pullDel.body.changes.length).toBe(1);
    expect(pullDel.body.changes[0].id).toBe(tagId);
    expect(pullDel.body.changes[0].isDeleted).toBe(true);
    expect(pullDel.body.changes[0].deletedAt).not.toBeNull();
  });
});
