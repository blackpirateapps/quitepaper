import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Scanned Document Control Plane & Sync Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    process.env.CLOUDINARY_CLOUD_NAME = 'test-cloud';
    process.env.CLOUDINARY_API_KEY = '123456789012345';
    process.env.CLOUDINARY_API_SECRET = 'abcdefghijklmnopqrstuvwxyz12345';
    process.env.CLOUDINARY_FOLDER = 'quitepaper_test';

    const db = getDbClient();
    await runMigrations(db);
  });

  it('Issues signed upload authorization for scanned document PDF', async () => {
    const documentId = '11111111-2222-3333-4444-555555555555';
    const authRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/documents/upload-auth',
      headers: { authorization: 'Bearer mock:user-doc-1' },
      body: {
        documentId,
        title: 'Tax Invoice 2026',
        mimeType: 'application/pdf',
        byteSize: 1048576,
        pageCount: 3,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
    });

    expect(authRes.statusCode).toBe(200);
    expect(authRes.body.uploadUrl).toBe('https://api.cloudinary.com/v1_1/test-cloud/raw/upload');
    expect(authRes.body.apiKey).toBe('123456789012345');
    expect(authRes.body.signature).toBeDefined();
    expect(authRes.body.timestamp).toBeGreaterThan(0);
    expect(authRes.body.publicId).toContain(documentId);
    expect(authRes.body.folder).toBe('quitepaper_test');
  });

  it('Confirms document upload, validates metadata, and tracks revision', async () => {
    const documentId = '22222222-3333-4444-5555-666666666666';
    const confirmRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/documents/confirm',
      headers: { authorization: 'Bearer mock:user-doc-1' },
      body: {
        documentId,
        title: 'Scanned Document',
        cloudPublicId: 'quitepaper_test/user_1_doc_2222',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v12345/quitepaper_test/user_1_doc_2222',
        mimeType: 'application/pdf',
        byteSize: 524288,
        pageCount: 4,
        sha256: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      },
    });

    expect(confirmRes.statusCode).toBe(200);
    expect(confirmRes.body.success).toBe(true);
    expect(confirmRes.body.document.id).toBe(documentId);
    expect(confirmRes.body.document.cloudUrl).toContain('test-cloud');
    expect(confirmRes.body.document.pageCount).toBe(4);
    expect(confirmRes.body.document.serverRevision).toBe(1);

    // Retrieve metadata
    const getRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/documents/${documentId}`,
      headers: { authorization: 'Bearer mock:user-doc-1' },
    });

    expect(getRes.statusCode).toBe(200);
    expect(getRes.body.id).toBe(documentId);
    expect(getRes.body.title).toBe('Scanned Document');
    expect(getRes.body.mimeType).toBe('application/pdf');
    expect(getRes.body.pageCount).toBe(4);
    expect(getRes.body.byteSize).toBe(524288);
  });

  it('Prevents cross-user document access and maintains user isolation', async () => {
    const documentId = '33333333-4444-5555-6666-777777777777';

    // User 1 creates document
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/documents/confirm',
      headers: { authorization: 'Bearer mock:user-doc-1' },
      body: {
        documentId,
        cloudPublicId: 'pub_user1_doc',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/pub_user1_doc',
      },
    });

    // User 2 attempts to fetch it
    const crossRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/documents/${documentId}`,
      headers: { authorization: 'Bearer mock:user-doc-2' },
    });

    expect(crossRes.statusCode).toBe(404);
  });

  it('Enforces crypto-blindness invariant: No document PDF bytes or plaintext stored in backend', async () => {
    const db = getDbClient();
    const tableInfo = await db.execute("PRAGMA table_info('documents');");
    const columnNames = tableInfo.rows.map(r => r.name as string);

    expect(columnNames).not.toContain('content');
    expect(columnNames).not.toContain('pdf_bytes');
    expect(columnNames).not.toContain('plaintext');
    expect(columnNames).toContain('sha256');
    expect(columnNames).toContain('cloud_url');
    expect(columnNames).toContain('cloud_public_id');
  });
});
