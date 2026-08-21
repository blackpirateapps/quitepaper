import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Conflict Detection & Revisions Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Detects revision conflict and returns serverHead with encrypted payload', async () => {
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
          pinned: true,
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
    expect(editResB.body.conflicts[0].baseRevision).toBe(1);

    // Verify structured serverHead in conflict payload
    const serverHead = editResB.body.conflicts[0].serverHead;
    expect(serverHead).toBeDefined();
    expect(serverHead.revision).toBe(2);
    expect(serverHead.contentCiphertext).toBe('v2-from-device-A');
    expect(serverHead.contentNonce).toBe('nonce-v2-123456789012');
    expect(serverHead.pinned).toBe(true);
    expect(serverHead.isDeleted).toBe(false);
  });

  it('Retrieves historical revision from sync_changes and current note by ID', async () => {
    const noteId = '66666666-6666-6666-6666-666666666666';

    // Push revision 1
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-rev-test' },
      body: {
        changes: [{
          id: noteId,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-01T00:00:00.000Z',
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'ciphertext-rev-1',
          contentNonce: 'nonce-1-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 0,
        }],
      },
    });

    // Push revision 2
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-rev-test' },
      body: {
        changes: [{
          id: noteId,
          createdAt: '2026-01-01T00:00:00.000Z',
          updatedAt: '2026-01-02T00:00:00.000Z',
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'ciphertext-rev-2',
          contentNonce: 'nonce-2-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 1,
        }],
      },
    });

    // Query historical revision 1
    const rev1Res = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/sync/notes/${noteId}/revisions/1`,
      headers: { authorization: 'Bearer mock:user-rev-test' },
    });
    expect(rev1Res.statusCode).toBe(200);
    expect(rev1Res.body.id).toBe(noteId);
    expect(rev1Res.body.revision).toBe(1);
    expect(rev1Res.body.contentCiphertext).toBe('ciphertext-rev-1');

    // Query historical revision 2
    const rev2Res = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/sync/notes/${noteId}/revisions/2`,
      headers: { authorization: 'Bearer mock:user-rev-test' },
    });
    expect(rev2Res.statusCode).toBe(200);
    expect(rev2Res.body.revision).toBe(2);
    expect(rev2Res.body.contentCiphertext).toBe('ciphertext-rev-2');

    // Query current note by ID
    const noteRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/sync/notes/${noteId}`,
      headers: { authorization: 'Bearer mock:user-rev-test' },
    });
    expect(noteRes.statusCode).toBe(200);
    expect(noteRes.body.revision).toBe(2);
    expect(noteRes.body.contentCiphertext).toBe('ciphertext-rev-2');

    // User isolation: another user cannot access user A's note or revision
    const unauthorizedRevRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/sync/notes/${noteId}/revisions/1`,
      headers: { authorization: 'Bearer mock:user-intruder' },
    });
    expect(unauthorizedRevRes.statusCode).toBe(404);

    const unauthorizedNoteRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/sync/notes/${noteId}`,
      headers: { authorization: 'Bearer mock:user-intruder' },
    });
    expect(unauthorizedNoteRes.statusCode).toBe(404);
  });

  it('Handles deletion conflicts (delete on server vs local edit)', async () => {
    const noteId = '77777777-7777-7777-7777-777777777777';

    // Create note (rev 1)
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-del-conflict' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'initial-content',
          contentNonce: 'nonce-del-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 0,
        }],
      },
    });

    // Delete note on remote server (rev 2)
    const delRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-del-conflict' },
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
          isDeleted: true,
          deletedAt: new Date().toISOString(),
          baseRevision: 1,
        }],
      },
    });
    expect(delRes.body.results[0].revision).toBe(2);

    // Stale local edit based on baseRevision 1 arrives
    const staleEditRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-del-conflict' },
      body: {
        changes: [{
          id: noteId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'local-edit-content',
          contentNonce: 'nonce-local-123456789012',
          contentVersion: 1,
          encryptionKeyVersion: 1,
          baseRevision: 1,
        }],
      },
    });

    expect(staleEditRes.statusCode).toBe(200);
    expect(staleEditRes.body.conflicts.length).toBe(1);
    expect(staleEditRes.body.conflicts[0].code).toBe('SYNC_CONFLICT');
    expect(staleEditRes.body.conflicts[0].serverHead?.isDeleted).toBe(true);
    expect(staleEditRes.body.conflicts[0].serverHead?.revision).toBe(2);
  });
});
