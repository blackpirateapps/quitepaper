import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Zero-Knowledge Document Annotation Synchronization Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  const docId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  it('Pushes encrypted annotation pages and pulls them with cursor pagination', async () => {
    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: { authorization: 'Bearer mock:user-ann-1' },
      body: {
        annotations: [
          {
            documentId: docId,
            pageNumber: 1,
            contentCiphertext: 'QVBBTi1lbnZlbG9wZS1wYWdlLTE=',
            annotationCount: 3,
            updatedAtMs: 1700000000000,
            isDeleted: false,
          },
          {
            documentId: docId,
            pageNumber: 2,
            contentCiphertext: 'QVBBTi1lbnZlbG9wZS1wYWdlLTI=',
            annotationCount: 1,
            updatedAtMs: 1700000000001,
            isDeleted: false,
          },
        ],
      },
    });

    expect(pushRes.statusCode).toBe(200);
    expect(pushRes.body.results.length).toBe(2);
    // Composite result id = "<documentId>:<pageNumber>" with revisions assigned 1..n.
    expect(pushRes.body.results[0].id).toBe(`${docId}:1`);
    expect(pushRes.body.results[0].revision).toBe(1);
    expect(pushRes.body.results[1].id).toBe(`${docId}:2`);
    expect(pushRes.body.results[1].revision).toBe(2);
    expect(pushRes.body.cursor).toBe(2);

    // Pull from cursor 0 (GET, like the Flutter client)
    const pullRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/document-annotations/pull?cursor=0&limit=10',
      headers: { authorization: 'Bearer mock:user-ann-1' },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(2);
    expect(pullRes.body.changes[0].documentId).toBe(docId);
    expect(pullRes.body.changes[0].pageNumber).toBe(1);
    expect(pullRes.body.changes[0].contentCiphertext).toBe('QVBBTi1lbnZlbG9wZS1wYWdlLTE=');
    expect(pullRes.body.changes[0].annotationCount).toBe(3);
    expect(pullRes.body.changes[0].updatedAtMs).toBe(1700000000000);
    expect(pullRes.body.changes[1].pageNumber).toBe(2);
    expect(pullRes.body.cursor).toBe(2);
    expect(pullRes.body.hasMore).toBe(false);

    // Pull from cursor 1 -> should return only page 2
    const pullCursor1 = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/pull',
      headers: { authorization: 'Bearer mock:user-ann-1' },
      body: { cursor: 1, limit: 10 },
    });

    expect(pullCursor1.statusCode).toBe(200);
    expect(pullCursor1.body.changes.length).toBe(1);
    expect(pullCursor1.body.changes[0].pageNumber).toBe(2);
  });

  it('Isolates annotations between different users', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: { authorization: 'Bearer mock:user-ann-a' },
      body: {
        annotations: [{
          documentId: docId,
          pageNumber: 1,
          contentCiphertext: 'user-a-annotation-blob',
          annotationCount: 2,
          updatedAtMs: 1700000000000,
          isDeleted: false,
        }],
      },
    });

    const userBPull = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/pull',
      headers: { authorization: 'Bearer mock:user-ann-b' },
      body: { cursor: 0, limit: 10 },
    });

    expect(userBPull.statusCode).toBe(200);
    expect(userBPull.body.changes.length).toBe(0);
  });

  it('Increments revision on re-push and returns the latest blob (idempotent upsert by documentId+pageNumber)', async () => {
    const auth = { authorization: 'Bearer mock:user-ann-rev' };

    // Initial push of page 1 -> revision 1
    const first = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: auth,
      body: {
        annotations: [{
          documentId: docId,
          pageNumber: 1,
          contentCiphertext: 'blob-v1',
          annotationCount: 1,
          updatedAtMs: 1700000000000,
          isDeleted: false,
        }],
      },
    });
    expect(first.body.results[0].revision).toBe(1);

    // Re-push the SAME page (new content) -> upsert, revision bumps to 2, no duplicate row
    const second = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: auth,
      body: {
        annotations: [{
          documentId: docId,
          pageNumber: 1,
          contentCiphertext: 'blob-v2',
          annotationCount: 4,
          updatedAtMs: 1700000000500,
          baseRevision: 1,
          isDeleted: false,
        }],
      },
    });
    expect(second.body.results[0].id).toBe(`${docId}:1`);
    expect(second.body.results[0].revision).toBe(2);
    expect(second.body.cursor).toBe(2);

    // Full pull (cursor 0) returns a single row carrying only the latest blob/revision
    const pullAll = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/document-annotations/pull?cursor=0&limit=10',
      headers: auth,
    });
    expect(pullAll.body.changes.length).toBe(1);
    expect(pullAll.body.changes[0].revision).toBe(2);
    expect(pullAll.body.changes[0].contentCiphertext).toBe('blob-v2');
    expect(pullAll.body.changes[0].annotationCount).toBe(4);

    // Incremental pull from cursor 1 picks up the re-pushed page.
    const pullIncremental = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/document-annotations/pull?cursor=1&limit=10',
      headers: auth,
    });
    expect(pullIncremental.body.changes.length).toBe(1);
    expect(pullIncremental.body.changes[0].contentCiphertext).toBe('blob-v2');
  });

  it('Propagates whole-page deletion tombstones', async () => {
    const auth = { authorization: 'Bearer mock:user-ann-del' };

    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: auth,
      body: {
        annotations: [{
          documentId: docId,
          pageNumber: 1,
          contentCiphertext: 'temp-annotation-blob',
          annotationCount: 2,
          updatedAtMs: 1700000000000,
          isDeleted: false,
        }],
      },
    });

    const delRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/push',
      headers: auth,
      body: {
        annotations: [{
          documentId: docId,
          pageNumber: 1,
          contentCiphertext: '',
          annotationCount: 0,
          updatedAtMs: 1700000001000,
          baseRevision: 1,
          isDeleted: true,
        }],
      },
    });
    expect(delRes.statusCode).toBe(200);

    const pullDel = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/document-annotations/pull',
      headers: auth,
      body: { cursor: 1, limit: 10 },
    });

    expect(pullDel.statusCode).toBe(200);
    expect(pullDel.body.changes.length).toBe(1);
    expect(pullDel.body.changes[0].pageNumber).toBe(1);
    expect(pullDel.body.changes[0].isDeleted).toBe(true);
    expect(pullDel.body.changes[0].deletedAt).not.toBeNull();
  });
});
