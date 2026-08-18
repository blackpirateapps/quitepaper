import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Auth & Identity Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Rejects requests with missing Authorization header', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/account',
      headers: {},
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('Rejects requests with invalid Bearer token', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/account',
      headers: {
        authorization: 'Bearer invalid-token',
      },
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('Authenticates valid token and generates scoped user record', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/account',
      headers: {
        authorization: 'Bearer mock:user-firebase-123',
      },
    });
    expect(res.statusCode).toBe(200);
    expect(res.body.user.firebaseUid).toBe('user-firebase-123');
    expect(res.body.user.id).toBeDefined();
    expect(res.body.syncCursor).toBe(0);
  });

  it('Ignores forged client-supplied user ID in request body and scopes strictly to verified UID', async () => {
    const noteId = '11111111-1111-1111-1111-111111111111';
    
    // User A creates note
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-A' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'mock-ciphertext-user-A',
          contentNonce: 'mock-nonce-user-A-1234',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });

    // User B tries to pull or pass forged user ID
    const pullResUserB = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: { authorization: 'Bearer mock:user-B' },
      body: {
        userId: 'user-A', // Forged field
        cursor: 0,
      },
    });

    expect(pullResUserB.statusCode).toBe(200);
    // User B should NOT see User A's note
    expect(pullResUserB.body.changes.length).toBe(0);
  });
});
