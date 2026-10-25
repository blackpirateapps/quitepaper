import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Zero-Knowledge OCR Synchronization and Conflict Detection Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  const docId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const attId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  it('Pushes encrypted document and attachment OCR pages and pulls them with cursor pagination without requiring Cloudinary media records', async () => {
    // OCR pages are zero-knowledge sidecars decoupled from attachments/documents control tables.
    // They push cleanly without needing pre-existing rows in attachments or documents.
    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/ocr/push',
      headers: { authorization: 'Bearer mock:user-ocr-1' },
      body: {
        pages: [
          {
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            contentCiphertext: 'UVBPQy1kb2MtcGFnZS0x',
            ocrEngine: 'quietpaper_ocr_v1',
            language: 'en',
            updatedAtMs: 1700000000000,
            baseRevision: 0,
          },
          {
            resourceType: 'attachment',
            resourceId: attId,
            pageNumber: 1,
            contentCiphertext: 'UVBPQy1hdHQtcGFnZS0x',
            ocrEngine: 'quietpaper_image_ocr',
            language: 'en',
            updatedAtMs: 1700000000001,
            baseRevision: 0,
          },
        ],
      },
    });

    expect(pushRes.statusCode).toBe(200);
    expect(pushRes.body.results.length).toBe(2);
    expect(pushRes.body.conflicts.length).toBe(0);
    expect(pushRes.body.results[0].id).toBe(`document:${docId}:1`);
    expect(pushRes.body.results[0].revision).toBe(1);
    expect(pushRes.body.results[1].id).toBe(`attachment:${attId}:1`);
    expect(pushRes.body.results[1].revision).toBe(2);
    expect(pushRes.body.cursor).toBe(2);

    // Pull from cursor 0
    const pullRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/ocr/pull?cursor=0&limit=10',
      headers: { authorization: 'Bearer mock:user-ocr-1' },
    });

    expect(pullRes.statusCode).toBe(200);
    expect(pullRes.body.changes.length).toBe(2);
    expect(pullRes.body.changes[0].resourceType).toBe('document');
    expect(pullRes.body.changes[0].resourceId).toBe(docId);
    expect(pullRes.body.changes[0].contentCiphertext).toBe('UVBPQy1kb2MtcGFnZS0x');
    expect(pullRes.body.changes[1].resourceType).toBe('attachment');
    expect(pullRes.body.changes[1].resourceId).toBe(attId);
    expect(pullRes.body.changes[1].contentCiphertext).toBe('UVBPQy1hdHQtcGFnZS0x');
    expect(pullRes.body.cursor).toBe(2);
    expect(pullRes.body.hasMore).toBe(false);

    // Pull with cursor 2 returns no new changes
    const pullEmpty = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/sync/ocr/pull?cursor=2&limit=10',
      headers: { authorization: 'Bearer mock:user-ocr-1' },
    });
    expect(pullEmpty.statusCode).toBe(200);
    expect(pullEmpty.body.changes.length).toBe(0);
  });

  it('Detects revision conflict when baseRevision is smaller than server revision without document pre-confirmation', async () => {
    // Initial push -> revision 1
    const initialRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/ocr/push',
      headers: { authorization: 'Bearer mock:user-ocr-conflict' },
      body: {
        pages: [
          {
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            contentCiphertext: 'initial-ocr-ciphertext',
            ocrEngine: 'quietpaper_ocr_v1',
            language: 'en',
            updatedAtMs: 1700000000000,
            baseRevision: 0,
          },
        ],
      },
    });
    expect(initialRes.body.results[0].revision).toBe(1);

    // Device A updates to revision 2
    const updateResA = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/ocr/push',
      headers: { authorization: 'Bearer mock:user-ocr-conflict' },
      body: {
        pages: [
          {
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            contentCiphertext: 'device-a-ocr-ciphertext',
            ocrEngine: 'quietpaper_ocr_v1',
            language: 'en',
            updatedAtMs: 1700000000100,
            baseRevision: 1,
          },
        ],
      },
    });
    expect(updateResA.body.results[0].revision).toBe(2);

    // Device B (still at baseRevision 1) attempts to push its own change -> CONFLICT!
    const conflictRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/ocr/push',
      headers: { authorization: 'Bearer mock:user-ocr-conflict' },
      body: {
        pages: [
          {
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            contentCiphertext: 'device-b-clashing-ocr',
            ocrEngine: 'quietpaper_ocr_v1',
            language: 'en',
            updatedAtMs: 1700000000200,
            baseRevision: 1,
          },
        ],
      },
    });

    expect(conflictRes.statusCode).toBe(200);
    expect(conflictRes.body.results.length).toBe(0);
    expect(conflictRes.body.conflicts.length).toBe(1);

    const c = conflictRes.body.conflicts[0];
    expect(c.id).toBe(`document:${docId}:1`);
    expect(c.resourceType).toBe('document');
    expect(c.resourceId).toBe(docId);
    expect(c.pageNumber).toBe(1);
    expect(c.baseRevision).toBe(1);
    expect(c.serverRevision).toBe(2);
    expect(c.code).toBe('SYNC_CONFLICT');
    expect(c.serverHead.contentCiphertext).toBe('device-a-ocr-ciphertext');
    expect(c.serverHead.revision).toBe(2);
  });
});
