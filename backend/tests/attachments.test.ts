import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import {
  generateCloudinarySignature,
  createSignedUploadAuth,
} from '../src/attachments/cloudinaryService.js';

describe('Backend Attachment Control Plane & Cloudinary Auth Tests', () => {
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

  it('Generates valid deterministic Cloudinary SHA-1 signature according to spec', () => {
    const params = {
      folder: 'quitepaper_test',
      public_id: 'user_123_attachment_456',
      timestamp: 1700000000,
    };
    const apiSecret = 'my-secret-key-123';

    const sig = generateCloudinarySignature(params, apiSecret);
    expect(typeof sig).toBe('string');
    expect(sig.length).toBe(40); // 40-character hex string for SHA-1

    // Re-running with same params produces identical signature
    const sig2 = generateCloudinarySignature(params, apiSecret);
    expect(sig2).toBe(sig);

    // Changing any parameter changes signature
    const sigDifferent = generateCloudinarySignature(
      { ...params, timestamp: 1700000001 },
      apiSecret
    );
    expect(sigDifferent).not.toBe(sig);
  });

  it('Issues signed upload authorization for authenticated user', async () => {
    const attachmentId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const authRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/attachments/upload-auth',
      headers: { authorization: 'Bearer mock:user-attach-1' },
      body: {
        attachmentId,
        mimeType: 'image/png',
        byteSize: 10240,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        variant: 'original',
      },
    });

    expect(authRes.statusCode).toBe(200);
    expect(authRes.body.uploadUrl).toBe('https://api.cloudinary.com/v1_1/test-cloud/raw/upload');
    expect(authRes.body.apiKey).toBe('123456789012345');
    expect(authRes.body.signature).toBeDefined();
    expect(authRes.body.timestamp).toBeGreaterThan(0);
    expect(authRes.body.publicId).toContain(attachmentId);
    expect(authRes.body.folder).toBe('quitepaper_test');
  });

  it('Confirms attachment upload and persists metadata', async () => {
    const attachmentId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    const confirmRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/attachments/confirm',
      headers: { authorization: 'Bearer mock:user-attach-1' },
      body: {
        attachmentId,
        cloudPublicId: 'quitepaper_test/user_1_bbbbbbbb',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v12345/quitepaper_test/user_1_bbbbbbbb',
        mimeType: 'image/jpeg',
        byteSize: 20480,
        sha256: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      },
    });

    expect(confirmRes.statusCode).toBe(200);
    expect(confirmRes.body.success).toBe(true);
    expect(confirmRes.body.attachment.id).toBe(attachmentId);
    expect(confirmRes.body.attachment.cloudUrl).toContain('test-cloud');

    // Retrieve metadata
    const getRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/attachments/${attachmentId}`,
      headers: { authorization: 'Bearer mock:user-attach-1' },
    });

    expect(getRes.statusCode).toBe(200);
    expect(getRes.body.id).toBe(attachmentId);
    expect(getRes.body.byteSize).toBe(20480);
  });

  it('Prevents cross-user access to attachments', async () => {
    const attachmentId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

    // User 1 creates attachment
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/attachments/confirm',
      headers: { authorization: 'Bearer mock:user-attach-1' },
      body: {
        attachmentId,
        cloudPublicId: 'pub_user1',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/pub_user1',
      },
    });

    // User 2 attempts to fetch it
    const crossRes = await handleApiRequest({
      method: 'GET',
      url: `/api/v1/attachments/${attachmentId}`,
      headers: { authorization: 'Bearer mock:user-attach-2' },
    });

    expect(crossRes.statusCode).toBe(404);
  });
});
